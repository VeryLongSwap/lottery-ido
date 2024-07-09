// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {OverflowICO, StructList} from "../src/lottery.sol";
import {WETH9} from "../src/WETH.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract ForkTest is Test, StructList {
    using SafeERC20 for IERC20;

    struct JSONData {
        address addr;
        uint256 amountUSDC;
        uint256 finalTokens;
        uint256 returnUSDC;
        uint256 wonTickets;
        uint256 wonUSDC;
    }

    // CSVデータを直接配列として定義
    JSONData[] public csv;

    uint256 fork;
    uint256 blocknumber = 3837590;
    address owner = 0xA20d63131210dAEA56BF99A660d9599ec78dF54D;

    OverflowICO public ido =
        OverflowICO(0x395D4ad692cF61c9324F528aF191b2B8d2eA0d58);
    IERC20 public USDC = IERC20(0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035);

    function setUp() public {
        fork = vm.createFork("https://rpc.startale.com/astar-zkevm");

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/commit2.json");
        string memory json = vm.readFile(path);
        bytes memory parsedJson = vm.parseJson(json);
        csv = abi.decode(parsedJson, (JSONData[]));
    }

    function testAddress() public {
        vm.selectFork(fork);
        vm.rollFork(blocknumber);
        vm.startPrank(owner);

        assertEq(block.number, blocknumber);
        assertEq(address(ido), 0x395D4ad692cF61c9324F528aF191b2B8d2eA0d58);
        assertEq(ido.owner(), owner);
        assertEq(USDC.balanceOf(address(ido)), 141600000000);
    }

    function testWithdraw() public {
        vm.selectFork(fork);
        vm.rollFork(blocknumber);
        vm.startPrank(owner);

        assertEq(USDC.balanceOf(ido.owner()), 3504024898);
        ido.withdrawToken(USDC, 135230000000, ido.owner());
        assertEq(USDC.balanceOf(ido.owner()), 138734024898);
    }

    function testWriteSetResult() public {
        vm.selectFork(fork);
        vm.rollFork(blocknumber);
        vm.startPrank(owner);

        // CSVデータからSetResultArgs配列を作成
        StructList.SetResultArgs[] memory args = new StructList.SetResultArgs[](
            csv.length
        );
        for (uint i = 0; i < csv.length; i++) {
            console.log("setresult", csv[i].addr, csv[i].wonTickets);
            uint256[] memory wonTicketsAmount = new uint256[](1);
            wonTicketsAmount[0] = csv[i].wonTickets;
            args[i] = SetResultArgs({
                addr: csv[i].addr,
                amount: csv[i].finalTokens,
                wonTicketsAmount: wonTicketsAmount
            });
        }

        // setResult関数を呼び出す
        ido.setResult(args);

        // 結果を検証
        for (uint i = 0; i < csv.length; i++) {
            StructList.UserInfo memory userinfo = ido.returnUserInfo(
                csv[i].addr
            );
            assertEq(
                userinfo.finalTokens,
                csv[i].finalTokens,
                "Final tokens mismatch"
            );
            assertEq(
                userinfo.wonTickets[0],
                csv[i].wonTickets,
                "Won tickets mismatch"
            );
        }

        // tokensToUserGrantの検証
        uint256 expectedTokensToUserGrant = 0;
        for (uint i = 0; i < csv.length; i++) {
            expectedTokensToUserGrant += csv[i].finalTokens;
        }
        assertEq(
            ido.tokensToUserGrant(),
            expectedTokensToUserGrant,
            "tokensToUserGrant mismatch"
        );

        // tokensToSellを超えていないことを確認
        assertTrue(
            ido.tokensToUserGrant() <= ido.tokensToSell(),
            "tokensToUserGrant exceeds tokensToSell"
        );

        vm.warp(block.timestamp + 30 days);
        // claim2関数とrefund関数のテストを追加

        for (uint i = 0; i < csv.length; i++) {
            address user = csv[i].addr;
            uint256 initialUSDCBalance = USDC.balanceOf(user);

            // ユーザーとしてclaim2関数を呼び出す
            vm.startPrank(user);
            ido.claim2();

            // クレームされたトークン量を検証
            uint256 claimedTokens = IERC20(ido.rewardToken()).balanceOf(user);
            assertEq(
                claimedTokens,
                csv[i].finalTokens,
                "Claimed tokens mismatch for user"
            );
            console.log("refund userinfo.addr", csv[i].addr, csv[i].returnUSDC);

            StructList.UserInfo memory refundinfo = ido.returnUserInfo(
                csv[i].addr
            );
            console.log(
                "norefund",
                refundinfo.noRefund[0],
                "tickets",
                refundinfo.tickets[0]
            );

            console.log(
                "isclaimed",
                refundinfo.isClaimed,
                "wontickets",
                refundinfo.wonTickets[0]
            );

            // ユーザーとしてrefund関数を呼び出す

            if (csv[i].returnUSDC > 0) {
                ido.refund(0);

                // 返金されたUSDC量を検証
                uint256 refundedUSDC = USDC.balanceOf(user) -
                    initialUSDCBalance;
                assertEq(
                    refundedUSDC,
                    csv[i].returnUSDC * (10 ** 6),
                    "Refunded USDC mismatch for user"
                );
                console.log("refunded", refundedUSDC, "USDC");
            }

            vm.stopPrank();
            console.log("------claimed and refund-----");
        }
    }
}
