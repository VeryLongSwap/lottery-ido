// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {OverflowICO, StructList} from "../src/lottery.sol";
import {WETH9} from "../src/WETH.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract ForkTest is Test, StructList {
    using SafeERC20 for IERC20;

    struct CSVData {
        address addr;
        uint256 wonTickets;
        uint256 finalTokens;
        uint256 returnUSDC;
    }

    // CSVデータを直接配列として定義
    CSVData[] public csv;

    uint256 fork;
    uint256 blocknumber = 3833381;
    address owner = 0xA20d63131210dAEA56BF99A660d9599ec78dF54D;

    OverflowICO public ido =
        OverflowICO(0x395D4ad692cF61c9324F528aF191b2B8d2eA0d58);
    IERC20 public USDC = IERC20(0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035);

    function setUp() public {
        fork = vm.createFork("https://rpc.startale.com/astar-zkevm");

        // CSVデータを直接構造体の配列として設定
        csv.push(
            CSVData(
                0xCEA525eE12e751379e3B0e8fE4a737E8A8d15622,
                2,
                8031000000,
                10
            )
        );
        csv.push(
            CSVData(
                0x0f7bF2e6BEbf3d352405B0f855d4B6fC6Fe50b3F,
                1,
                4015500000,
                20
            )
        );
        csv.push(
            CSVData(
                0x944C6C8882012CcD4FFd2911a7F1fDC520c9a561,
                1,
                4015500000,
                0
            )
        );
        csv.push(
            CSVData(
                0xbB7eb80b94F6a7ACd7FF7966606e34fB2725C229,
                437,
                1754773500000,
                15630
            )
        );
        csv.push(
            CSVData(
                0x34FeE623474A202143aDD25602f531Be0Fbe5458,
                20,
                80310000000,
                600
            )
        );
    }

    function testAddress() public {
        vm.selectFork(fork);
        vm.rollFork(blocknumber);
        vm.startPrank(owner);

        assertEq(block.number, blocknumber);
        assertEq(address(ido), 0x395D4ad692cF61c9324F528aF191b2B8d2eA0d58);
        assertEq(ido.owner(), owner);
        assertEq(USDC.balanceOf(address(ido)), 135230000000);
    }

    function testWithdraw() public {
        vm.selectFork(fork);
        vm.rollFork(blocknumber);
        vm.startPrank(owner);

        assertEq(USDC.balanceOf(ido.owner()), 3504024898);
        ido.withdrawToken(USDC, 135230000000, ido.owner());
        assertEq(USDC.balanceOf(ido.owner()), 138734024898);
    }

    // 必要に応じて、個別のデータ行をテストする関数を追加
    function testSpecificRow() public view {
        uint rowIndex = 2; // 3番目の行（0-indexed）
        CSVData memory row = csv[rowIndex];

        assertEq(
            row.addr,
            0x944C6C8882012CcD4FFd2911a7F1fDC520c9a561,
            "Address mismatch"
        );
        assertEq(row.wonTickets, 1, "Won tickets mismatch");
        assertEq(row.finalTokens, 4015500000, "Final tokens mismatch");

        console.log("Specific row test passed");
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

        console.log("SetResult function called successfully with CSV data");

        vm.warp(block.timestamp + 30 days);
        console.log("blocktimestamp", block.timestamp + 30 days);
        // claim2関数とrefund関数のテストを追加

        for (uint i = 0; i < csv.length; i++) {
            address user = csv[i].addr;
            uint256 initialUSDCBalance = USDC.balanceOf(user);

            // ユーザーとしてclaim2関数を呼び出す
            vm.startPrank(user);
            ido.claim2();
            vm.stopPrank();

            // クレームされたトークン量を検証
            uint256 claimedTokens = IERC20(ido.rewardToken()).balanceOf(user);
            assertEq(
                claimedTokens,
                csv[i].finalTokens,
                "Claimed tokens mismatch for user"
            );

            // ユーザーとしてrefund関数を呼び出す
            if (csv[i].returnUSDC > 0) {
                vm.startPrank(user);
                ido.refund(0);
                vm.stopPrank();

                // 返金されたUSDC量を検証
                uint256 refundedUSDC = USDC.balanceOf(user) -
                    initialUSDCBalance;
                assertEq(
                    refundedUSDC,
                    csv[i].returnUSDC * (10 ** 6),
                    "Refunded USDC mismatch for user"
                );
            }

            // console.log("User", user, "claimed", claimedTokens, "tokens and refunded", refundedUSDC, "USDC");
        }
    }
}
