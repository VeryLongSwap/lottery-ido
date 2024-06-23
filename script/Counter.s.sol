// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LotteryIDO} from "../src/lottery.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract CounterScript is Script {
    LotteryIDO public ido;
    LotteryIDO public ido2;
    ERC20 public buyerToken;
    ERC20 public salesToken1;

    address public user = 0x0f7bF2e6BEbf3d352405B0f855d4B6fC6Fe50b3F;
    address public user2 = 0xDD47792c1A9f8F12a44c299f1be85FFD72A4B746;
    uint public startTime = 1719142200;
    uint public endTime = startTime + 3600;
    uint public tokensToSell = 5e22;
    address public dead = 0x000000000000000000000000000000000000dEaD;

    address public moti = 0x564d3De018dECF88f10e4F61CC988e7424faC912;
    address public USDC = 0xD2119e73b34f3D8E07B4aC289DbD766e632F31E3;
    address public isom = 0x2a4E2eb4c1522Bb7Db43Ab34597078FE5Db45bEA;
    address deployer = 0xDD47792c1A9f8F12a44c299f1be85FFD72A4B746;

    IERC20[] public buyerTokens;
    uint[] public tokensPerTickets = [1e21, 5e20];

    function run() public {
        vm.startBroadcast(deployer);

        buyerTokens.push(IERC20(moti));
        buyerTokens.push(IERC20(isom));

        ido = new LotteryIDO(
            IERC20(address(USDC)),
            buyerTokens,
            tokensToSell,
            startTime,
            endTime,
            endTime + 1800,
            0,
            0,
            0,
            tokensPerTickets,
            dead
        );
        buyerTokens[0].approve(address(ido), type(uint256).max);
        buyerTokens[1].approve(address(ido), type(uint256).max);
        IERC20(address(USDC)).approve(address(ido), type(uint256).max);

        ido.start();

        vm.stopBroadcast();
    }
}
