// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import { OverflowICO } from "../src/lottery.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Deploy is Script {
    OverflowICO public ido;
    ERC20 public buyerToken;
    ERC20 public salesToken1;
    
    uint public startTime = 1719608400;
    uint public endTime = 1719651600;
    uint public tokensToSell = 1e18;
    address public dead = 0x000000000000000000000000000000000000dEaD;
    
    address public USDC = 0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035;
    address deployer = 0x944C6C8882012CcD4FFd2911a7F1fDC520c9a561;
    address public BONSAI = 0xcE3F71Af1A80390cAb3f429B30567cBE0E853f4d;
    

    IERC20[] public buyerTokens;
    uint[] public tokensPerTickets = [10 * 1e18];

    function run() public {
        vm.startBroadcast();
        buyerTokens.push(IERC20(BONSAI));


        // Ensure USDC contract exists and has code
        require(address(USDC).code.length > 0, "USDC contract does not exist");


        ido = new OverflowICO(
            IERC20(address(USDC)),
            buyerTokens,
            tokensToSell,
            startTime,
            endTime,
            endTime + 100,
            0,
            0,
            0,
            tokensPerTickets,
            0,
            dead
        );

        vm.stopBroadcast();
    }

}