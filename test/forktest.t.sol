// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {OverflowICO, StructList} from "../src/lottery.sol";
import {WETH9} from "../src/WETH.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract ForkTest is Test, StructList {
    using SafeERC20 for IERC20;

    uint256 fork;
    uint256 blocknumber = 3833381;
    address owner = 0xA20d63131210dAEA56BF99A660d9599ec78dF54D;

    OverflowICO public ido = OverflowICO(0x395D4ad692cF61c9324F528aF191b2B8d2eA0d58);
    IERC20 public USDC = IERC20(0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035);

    function setUp() public {
        fork = vm.createFork("https://rpc.startale.com/astar-zkevm");
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

}