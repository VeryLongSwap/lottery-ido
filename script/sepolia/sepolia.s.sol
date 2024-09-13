// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LotteryIDO, StructList} from "src/lottery-neuro.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract USDCSendTest is Script {
    address public USDC = 0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035;

    function run() public {
        vm.startBroadcast();
        console.log("USDC Send Test");
        IERC20(USDC).transfer(0xA20d63131210dAEA56BF99A660d9599ec78dF54D, 100000);

        vm.stopBroadcast();
    }
    
}
/*
contract IDOStart is Script {
    address public USDC = 0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035;
    address public BONSAI = 0x90E3F8e749dBD40286AB29AecD1E8487Db4a8785;
    LotteryIDO public ido =
        LotteryIDO(0x395D4ad692cF61c9324F528aF191b2B8d2eA0d58);

    function run() public {
        vm.startBroadcast();
        console.log("IDO Started");
        IERC20(USDC).approve(address(ido), type(uint256).max);
        IERC20(address(BONSAI)).approve(address(ido), type(uint256).max);
        ido.setStartFlg(true);

        vm.stopBroadcast();
    }
}

contract IDOSetResult is Script {
    struct JSONData {
        address addr;
        uint256 amountUSDC;
        uint256 finalTokens;
        uint256 returnUSDC;
        uint256 wonTickets;
        uint256 wonUSDC;
    }

    // CSVデータを直接配列として定義
    JSONData[] csv;

    LotteryIDO public ido =
        LotteryIDO(0x395D4ad692cF61c9324F528aF191b2B8d2eA0d58);

    function run() public {
        vm.startBroadcast();
        console.log("IDO SetResult");

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/commit3.json");
        string memory json = vm.readFile(path);
        bytes memory parsedJson = vm.parseJson(json);
        csv = abi.decode(parsedJson, (JSONData[]));

        // CSVデータからSetResultArgs配列を作成
        StructList.SetResultArgs[] memory args = new StructList.SetResultArgs[](
            csv.length
        );
        for (uint i = 0; i < csv.length; i++) {
            uint256[] memory wonTicketsAmount = new uint256[](1);
            wonTicketsAmount[0] = csv[i].wonTickets;
            args[i] = StructList.SetResultArgs({
                addr: csv[i].addr,
                amount: csv[i].finalTokens * (10 ** 18),
                wonTicketsAmount: wonTicketsAmount
            });
        }

        // setResult関数を呼び出す
        ido.setResult(args);

        vm.stopBroadcast();
    }
}
*/
contract Deploy is Script {
    LotteryIDO public ido;
    ERC20 public buyerToken;
    ERC20 public salesToken1;

    address public user = 0x0f7bF2e6BEbf3d352405B0f855d4B6fC6Fe50b3F;
    address public user2 = 0xDD47792c1A9f8F12a44c299f1be85FFD72A4B746;
    uint public startTime = 1726154961;
    uint public endTime = startTime + 9000;
    uint public receiveTime = 9725671319;
    uint public tokensToSell = 5e23;
    address public dead = 0x000000000000000000000000000000000000dEaD;
    
    address public USDT = 0xb8744EA261416ff9b78fC8D5990754f80b9c9B03;
    address public USDC = 0xc318cDe4aCBE774eF3716B0478cf7E3409c47A39;
    address public WETH = 0x2D9235a1dB6552E2504F9F6783C9655270Ee49EB;
    address deployer = user;

    IERC20[] public buyerTokens;
    uint[] public tokensPerTickets = [1e8, 1e8, 1e15];

    function run() public {
        vm.startBroadcast(deployer);


        buyerTokens.push(IERC20(USDC));
        buyerTokens.push(IERC20(USDT));
        buyerTokens.push(IERC20(WETH));
        //buyerTokens.push(IERC20(isom));
        ido = new LotteryIDO(
            buyerTokens,
            tokensToSell,
            startTime,
            endTime,
            receiveTime,
            tokensPerTickets,
            dead
        );
        //buyerTokens[0].approve(address(ido), type(uint256).max);
        //buyerTokens[1].approve(address(ido), type(uint256).max);
        ido.setWNative(WETH);
        ido.setStartFlg(true);

        vm.stopBroadcast();
    }
}

