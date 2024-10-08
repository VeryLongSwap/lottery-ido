// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {OverflowICO, StructList} from "../src/lottery.sol";
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

contract IDOStart is Script {
    address public USDC = 0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035;
    address public BONSAI = 0x90E3F8e749dBD40286AB29AecD1E8487Db4a8785;
    OverflowICO public ido =
        OverflowICO(0x395D4ad692cF61c9324F528aF191b2B8d2eA0d58);

    function run() public {
        vm.startBroadcast();
        console.log("IDO Started");
        IERC20(USDC).approve(address(ido), type(uint256).max);
        IERC20(address(BONSAI)).approve(address(ido), type(uint256).max);
        ido.start();

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

    OverflowICO public ido =
        OverflowICO(0x395D4ad692cF61c9324F528aF191b2B8d2eA0d58);

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

contract Deploy is Script {
    OverflowICO public ido;
    ERC20 public buyerToken;

    uint public startTime = 1719799198;
    uint public endTime = 1720580400;
    uint public claimTime = 1720774800;
    uint public tokensToSell = 8031000000000 * 1e18;
    address public dead = 0x000000000000000000000000000000000000dEaD;

    address public USDC = 0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035;
    address deployer = 0x944C6C8882012CcD4FFd2911a7F1fDC520c9a561;
    address public BONSAI = 0x90E3F8e749dBD40286AB29AecD1E8487Db4a8785;

    IERC20[] public buyerTokens;
    uint[] public tokensPerTickets = [10 * 1e6];

    function run() public {
        vm.startBroadcast();
        buyerTokens.push(IERC20(USDC));

        // Ensure USDC contract exists and has code
        require(address(USDC).code.length > 0, "USDC contract does not exist");

        ido = new OverflowICO(
            IERC20(address(BONSAI)),
            buyerTokens,
            tokensToSell,
            startTime,
            endTime,
            claimTime,
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
