// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {LotteryIDO, StructList} from "../src/lottery.sol";
import {WETH9} from "../src/WETH.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract CounterTest is Test, StructList {
    using SafeERC20 for IERC20;

    LotteryIDO public ido;
    WETH9 public salesToken;
    address public user = 0x0cCCFCeccCc3cC32cc0cbCf5cFcc6cCcFC5cBcfC;
    address public user2 = 0x0CCcfCeccCC3CC32CC0cFFffcFcc6ccCFc5cbCFC;

    address deployer = 0x0CCcfCeccCC3CC32CC0cFFffcFcc6ccCFc5cbCFC;

    uint public startTime = 100000000000;
    uint public endTime = startTime + 1000;
    uint public tokensToSell = 5e18;
    address public dead = 0x000000000000000000000000000000000000dEaD;

    address public moti = address(new WETH9(address(this)));
    address public USDC = address(new WETH9(address(this)));
    address public isom = address(new WETH9(address(this)));
    IERC20[] public buyerTokens;
    uint[] public tokensPerTickets = [1e18, 1e18];

    function setUp() public {
        WETH9(moti).mint(deployer, 1e30);
        WETH9(USDC).mint(deployer, 1e30);
        WETH9(isom).mint(deployer, 1e30);

        buyerTokens.push(WETH9(moti));
        buyerTokens.push(WETH9(isom));
        salesToken = WETH9(address(USDC));

        vm.startPrank(deployer);
        buyerTokens[0].transfer(address(this), 1e22);
        buyerTokens[1].transfer(address(this), 1e22);
        salesToken.transfer(address(this), 1e22);
        vm.stopPrank();

        ido = new LotteryIDO(
            salesToken,
            buyerTokens,
            tokensToSell,
            startTime,
            endTime,
            endTime + 100,
            0,
            0,
            0,
            tokensPerTickets,
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

        vm.expectRevert("Can only deposit Ether during the sale period.");
        ido.commit(3, address(buyerTokens[0]));
        vm.warp(startTime + 1);
        ido.commit(2, address(buyerTokens[0]));

        StructList.UserInfo memory userInfo;

        userInfo = ido.returnUserInfo(user);

        assertEq(userInfo.tickets[0], 2);

        assertEq(
            beforeBuyerToken0 - 2 * ido.tokensPerTicket(0),
            buyerTokens[0].balanceOf(user)
        );

        assertEq(ido.totalCommitments(0), 2 * ido.tokensPerTicket(0));
        vm.stopPrank();
        SetResultArgs[] memory setResultArgs = new SetResultArgs[](1);
        uint[] memory wonTickets = new uint[](2);
        ido.setPrizeAmountPerTicket(0, 5e17);
        ido.setPrizeAmountPerTicket(1, 1e18);
        wonTickets[0] = 2;
        wonTickets[1] = 0;
        setResultArgs[0] = SetResultArgs(user, wonTickets);

        ido.commit(3, address(buyerTokens[0]));
        ido.setResult(setResultArgs);

        assertEq(ido.checkClaimAmount(user), 1e18);

        vm.expectRevert("not claimable yet");
        ido.refund(0);

        vm.warp(ido.receiveTime() + 1000);

        vm.prank(user);
        vm.expectRevert("No refunds available");
        ido.refund(0);

        beforeBuyerToken0 = buyerTokens[0].balanceOf(address(this));
        ido.refund(0);

        assertEq(
            beforeBuyerToken0 + 3 * ido.tokensPerTicket(0),
            buyerTokens[0].balanceOf(address(this))
        );
        vm.expectRevert("No refunds available");
        ido.refund(0);

        vm.startPrank(user);
        uint beforeSalesToken = salesToken.balanceOf(user);
        ido.claim2();

        assertEq(beforeSalesToken + 1e18, salesToken.balanceOf(user));

        vm.expectRevert("no claims available");
        ido.claim2();
        vm.stopPrank();

        beforeBuyerToken0 = buyerTokens[0].balanceOf(address(this));
        ido.finish();
        uint afterBuyerToken0 = buyerTokens[0].balanceOf(address(this));

        assertEq(
            beforeBuyerToken0 + 2 * ido.tokensPerTicket(0),
            afterBuyerToken0
        );

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
        ido.setPrizeAmountPerTicket(0, 5e17);
        ido.setPrizeAmountPerTicket(1, 1e18);
        uint[] memory wonTickets = new uint[](2);
        wonTickets[0] = 1;
        wonTickets[1] = 0;
        setResultArgs[0] = SetResultArgs(user, wonTickets);

        ido.commit(3, moti);
        ido.setResult(setResultArgs);

        vm.warp(ido.receiveTime() + 1000);

        uint beforeBuyerToken = buyerTokens[0].balanceOf(address(this));
        ido.finish();
        uint afterBuyerToken = buyerTokens[0].balanceOf(address(this));
        assertEq(
            beforeBuyerToken + (1 * ido.tokensPerTicket(0)),
            afterBuyerToken
        );
        console.log("ok");

        uint beforeSalesToken = salesToken.balanceOf(user);

        vm.prank(user);
        ido.claim2();

        assertEq(beforeSalesToken + 5e17, salesToken.balanceOf(user));
        console.log("ok2");
        beforeBuyerToken = buyerTokens[0].balanceOf(address(this));
        ido.refund(0);

        assertEq(
            beforeBuyerToken + (3 * ido.tokensPerTicket(0)),
            buyerTokens[0].balanceOf(address(this))
        );
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
        assertEq(
            beforeValue - 4 * tokensPerTickets[0],
            buyerTokens[0].balanceOf(address(this))
        );

        beforeValue = buyerTokens[0].balanceOf(address(this));
        ido.commit(4, moti);
        ido.commit(3, moti);
        ido.commit(3, isom);
        ido.commit(1, isom);
        assertEq(
            beforeValue - 7 * tokensPerTickets[0],
            buyerTokens[0].balanceOf(address(this))
        );
        StructList.UserInfo memory userInfo = ido.returnUserInfo(address(this));
        assertEq(userInfo.tickets[0], 11);
        assertEq(userInfo.tickets[1], 4);

        SetResultArgs[] memory setResultArgs = new SetResultArgs[](1);
        ido.setPrizeAmountPerTicket(0, 5e17);
        ido.setPrizeAmountPerTicket(1, 1e18);
        uint[] memory wonTickets = new uint[](2);
        wonTickets[0] = 2;
        wonTickets[1] = 2;
        setResultArgs[0] = SetResultArgs(user, wonTickets);

        ido.setResult(setResultArgs);

        vm.startPrank(user);

        vm.expectRevert("not claimable yet");
        ido.refund(0);

        vm.warp(ido.receiveTime() + 1000);
        beforeValue = buyerTokens[0].balanceOf(user);
        ido.refund(0);
        assertEq(
            beforeValue + 1 * tokensPerTickets[0],
            buyerTokens[0].balanceOf(user)
        );
        vm.expectRevert("No refunds available");
        ido.refund(1);

        vm.expectRevert("No refunds available");
        ido.refund(0);

        beforeValue = salesToken.balanceOf(user);
        ido.claim2();
        assertEq(beforeValue + 3e18, salesToken.balanceOf(user));
        vm.expectRevert("no claims available");
        ido.claim2();

        vm.stopPrank();

        vm.expectRevert("no claims available");
        ido.claim2();

        beforeValue = buyerTokens[0].balanceOf(address(this));
        ido.refund(0);
        assertEq(
            beforeValue + 11 * tokensPerTickets[0],
            buyerTokens[0].balanceOf(address(this))
        );

        beforeValue = buyerTokens[1].balanceOf(address(this));
        ido.refund(1);
        assertEq(
            beforeValue + 4 * tokensPerTickets[1],
            buyerTokens[1].balanceOf(address(this))
        );
    }
}
