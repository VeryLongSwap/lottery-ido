// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {OverflowICO, StructList} from "../src/lottery.sol";
import {WETH9} from "../src/WETH.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract CounterTest is Test, StructList {
    using SafeERC20 for IERC20;

    OverflowICO public ido;
    WETH9 public salesToken;
    address public user = 0x0f7bF2e6BEbf3d352405B0f855d4B6fC6Fe50b3F;
    address public user2 = 0xDD47792c1A9f8F12a44c299f1be85FFD72A4B746;
    
    address deployer = 0xDD47792c1A9f8F12a44c299f1be85FFD72A4B746;

    uint public startTime = 100000000000;
    uint public endTime = startTime + 1000;
    uint public tokensToSell = 1e18;
    uint public tokensToRaise = 1e18;
    address public dead = 0x000000000000000000000000000000000000dEaD;

    address public moti = 0x564d3De018dECF88f10e4F61CC988e7424faC912;
    address public USDC = 0xD2119e73b34f3D8E07B4aC289DbD766e632F31E3;
    address public isom = 0x2a4E2eb4c1522Bb7Db43Ab34597078FE5Db45bEA;
    IERC20[] public buyerTokens;
    uint[] public tokensPerTickets = [1e18, 1e18];
    function setUp() public {

        buyerTokens.push(WETH9(moti));
        buyerTokens.push(WETH9(isom));
        salesToken = WETH9(address(USDC)); 

        vm.startPrank(deployer);
        buyerTokens[0].transfer(address(this), 1e22);
        buyerTokens[1].transfer(address(this), 1e22);
        salesToken.transfer(address(this), 1e22);
        vm.stopPrank();

        ido = new OverflowICO(
            // salesToken
            salesToken,
            // buyerToken
            buyerTokens,
            // tokensToSell 売る枚数
            tokensToSell,
            // startTime
            startTime,
            // endTime
            endTime,
            // receiveTime
            endTime + 100,
            // vestingBegin
            0,
            // vestingDuration
            0,
            // vestingProportion
            0,
            // tokensperticket
            tokensPerTickets,
            // totalEmission 先行者利益の額
            0,
            // burnAddress
            dead
        );

        buyerTokens[0].approve(address(ido), type(uint256).max);
        buyerTokens[1].approve(address(ido), type(uint256).max);
        salesToken.approve(address(ido), type(uint256).max);
        
        vm.warp(startTime - 1);
        ido.start();
    }

    function testSoloIDO() public {
        buyerTokens[0].transfer(user, 2e18);
        
        vm.startPrank(user);
        buyerTokens[0].approve(address(ido), type(uint256).max);
        uint beforeBuyerToken0 = buyerTokens[0].balanceOf(user);
        // 開始前にcommitする
        vm.expectRevert("Can only deposit Ether during the sale period.");
        ido.commit(3, address(buyerTokens[0]));
        vm.warp(startTime + 1);
        ido.commit(2, address(buyerTokens[0]));

        StructList.UserInfo memory userInfo;

        userInfo = ido.returnUserInfo(user);
        // ちゃんとticket2枚コミットできてる？
        assertEq(userInfo.tickets[0], 2);
        // トークン減ってる？
        assertEq(beforeBuyerToken0 - 2 * ido.tokensPerTicket(0), buyerTokens[0].balanceOf(user));
        // トータルコミット正常に増えてる？
        assertEq(ido.totalCommitments(0), 2 * ido.tokensPerTicket(0));
        vm.stopPrank();
        SetResultArgs[] memory setResultArgs = new SetResultArgs[](1);
        bool[] memory _refundFlag = new bool[](2);
        _refundFlag[0] = true;
        _refundFlag[1] = true;
        setResultArgs[0] = SetResultArgs(user, 1e18, _refundFlag);

        ido.commit(3, address(buyerTokens[0]));
        ido.setResult(setResultArgs);
        userInfo = ido.returnUserInfo(user);
        // ちゃんとユーザーの排出量セットできてる？
        assertEq(userInfo.finalTokens, 1e18);
        // フライングrefund
        vm.expectRevert("not claimable yet");
        ido.refund(0);

        vm.warp(ido.receiveTime() + 1000);
        
        // IDO当選してるのにrefund
        vm.prank(user);
        vm.expectRevert("No refunds available");
        ido.refund(0);

        beforeBuyerToken0 = buyerTokens[0].balanceOf(address(this));
        ido.refund(0);
        // ちゃんと正しい額refundされてる？
        assertEq(beforeBuyerToken0 + 3 * ido.tokensPerTicket(0), buyerTokens[0].balanceOf(address(this)));
        vm.expectRevert("No refunds available");
        ido.refund(0);

        vm.startPrank(user);
        uint beforeSalesToken = salesToken.balanceOf(user);
        ido.claim2();
        // ちゃんとclaimできてる？
        assertEq(beforeSalesToken + 1e18, salesToken.balanceOf(user));
        // 2連claimは無理
        vm.expectRevert("no claims available");
        ido.claim2();
        vm.stopPrank();

        beforeBuyerToken0 = buyerTokens[0].balanceOf(address(this));
        ido.finish();
        uint afterBuyerToken0 = buyerTokens[0].balanceOf(address(this));
        // ちゃんと販売に使ったトークン回収できてる？
        assertEq(beforeBuyerToken0 + 2 * ido.tokensPerTicket(0), afterBuyerToken0);
        // finish打てるのは1回だけ
        vm.expectRevert("Already finished.");
        ido.finish();
        
    }

    function testFinishBeforeClaim() public {
        buyerTokens[0].transfer(user, 2e18);

        vm.startPrank(user);
        buyerTokens[0].approve(address(ido), type(uint256).max);
        vm.warp(startTime + 1);
        ido.commit(2, moti);
        vm.stopPrank();

        SetResultArgs[] memory setResultArgs = new SetResultArgs[](1);
        bool[] memory _refundFlag = new bool[](2);
        _refundFlag[0] = false;
        _refundFlag[1] = false;
        setResultArgs[0] = SetResultArgs(user, 1e18, _refundFlag);

        ido.commit(3, moti);
        ido.setResult(setResultArgs);

        vm.warp(ido.receiveTime() + 1000);
        
        // ユーザーのclaim前にfinishしても必要量のトークンだけを取れるかのテスト
        uint beforeBuyerToken = buyerTokens[0].balanceOf(address(this));
        ido.finish();
        uint afterBuyerToken = buyerTokens[0].balanceOf(address(this));

        assertEq(beforeBuyerToken + 2 * ido.tokensPerTicket(0), afterBuyerToken);


        uint beforeSalesToken = salesToken.balanceOf(user);
        
        vm.prank(user);
        ido.claim2();
        // ちゃんとclaimできてる？
        assertEq(beforeSalesToken + 1e18, salesToken.balanceOf(user));
        
        beforeBuyerToken = buyerTokens[0].balanceOf(address(this));
        ido.refund(0);
        // ちゃんと正しい額refundされてる？
        assertEq(beforeBuyerToken + 3 * ido.tokensPerTicket(0), buyerTokens[0].balanceOf(address(this)));
    }
    
    function test2tokens() public {
        buyerTokens[0].transfer(user, 3e18);
        buyerTokens[1].transfer(user, 2e18);
        
        vm.startPrank(user);
        buyerTokens[0].approve(address(ido), type(uint256).max);
        buyerTokens[1].approve(address(ido), type(uint256).max);
        vm.warp(startTime + 1);

        ido.commit(3, moti);
        ido.commit(2, isom);

        vm.stopPrank();

        uint beforeValue = buyerTokens[0].balanceOf(address(this));
        ido.commit(4, moti);
        assertEq(beforeValue - 4 * tokensPerTickets[0], buyerTokens[0].balanceOf(address(this)));
        //小分けにコミットしても問題ないよね
        beforeValue = buyerTokens[0].balanceOf(address(this));
        ido.commit(4, moti);
        ido.commit(3, moti);
        ido.commit(3, isom);
        ido.commit(1, isom);
        assertEq(beforeValue - 7 * tokensPerTickets[0], buyerTokens[0].balanceOf(address(this)));
        StructList.UserInfo memory userInfo = ido.returnUserInfo(address(this));
        assertEq(userInfo.tickets[0], 11);
        assertEq(userInfo.tickets[1], 4);

        SetResultArgs[] memory setResultArgs = new SetResultArgs[](1);
        bool[] memory _refundFlag = new bool[](2);
        _refundFlag[0] = false;
        _refundFlag[1] = true;
        setResultArgs[0] = SetResultArgs(user, 1e18, _refundFlag);

        ido.setResult(setResultArgs);
        
        vm.startPrank(user);

        vm.expectRevert("not claimable yet");
        ido.refund(0);

        vm.warp(ido.receiveTime() + 1000);
        beforeValue = buyerTokens[0].balanceOf(user);
        ido.refund(0);
        assertEq(beforeValue + 3 * tokensPerTickets[0], buyerTokens[0].balanceOf(user));
        vm.expectRevert("No refunds available");
        ido.refund(1);
        // 2回目
        vm.expectRevert("No refunds available");
        ido.refund(0);

        beforeValue = salesToken.balanceOf(user);
        ido.claim2();
        assertEq(beforeValue + 1e18, salesToken.balanceOf(user));
        vm.expectRevert("no claims available");
        ido.claim2();

        vm.stopPrank();
        
        vm.expectRevert("no claims available");
        ido.claim2();

        beforeValue = buyerTokens[0].balanceOf(address(this));
        ido.refund(0);
        assertEq(beforeValue + 11 * tokensPerTickets[0], buyerTokens[0].balanceOf(address(this)));

        beforeValue = buyerTokens[1].balanceOf(address(this));
        ido.refund(1);
        assertEq(beforeValue + 4 * tokensPerTickets[1], buyerTokens[1].balanceOf(address(this)));

    }
}


