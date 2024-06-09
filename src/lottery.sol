// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.23;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Test, console} from "forge-std/Test.sol";

interface Token {
    function decimals() external returns (uint);
}
contract StructList {
    struct UserInfo {

        uint256[] tickets;
        uint256 finalTokens;
        uint256 finalEmissions;

        bool[] noRefund;
        bool isClaimed;
        bool[] hasWon;
    }

    struct SetResultArgs {
        address addr;
        uint256 amount;
        bool[] refundFlag;
    }
}
contract LinearVesting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;
    uint256 public immutable vestBeginning;
    uint256 public immutable vestDuration;

    mapping(address => uint256) public claimableTotal;
    mapping(address => uint256) public claimed;
    mapping(address => bool) public registered;

    event ClaimVesting(address addr, uint256 amount);

    constructor(IERC20 rewardToken_, uint256 vestBeginning_, uint256 vestDuration_) {
        rewardToken = rewardToken_;
        vestBeginning = vestBeginning_;
        vestDuration = vestDuration_;
    }

    function _grantVestedReward(address addr, uint256 amount) internal {
        require(!registered[addr], "already registered");
        claimableTotal[addr] = amount;
        registered[addr] = true;
    }

    function claim3(address addr) public nonReentrant returns (uint256) {
        require(registered[addr]);
        uint256 vested = 0;
        if (block.timestamp < vestBeginning) {
            vested = 0;
        } else if (block.timestamp >= vestBeginning + vestDuration) {
            vested = claimableTotal[addr];
        } else {
            vested = Math.mulDiv(claimableTotal[addr], block.timestamp - vestBeginning, vestDuration);
        }

        uint256 delta = vested - claimed[addr];
        claimed[addr] = vested;

        rewardToken.safeTransfer(addr, delta);
        emit ClaimVesting(addr, delta);
        return delta;
    }
}

contract OverflowICO is Ownable(msg.sender), ReentrancyGuard, LinearVesting, StructList {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    IERC20[] public buyerTokens;
    IERC20 public immutable salesToken;
    uint256 private immutable salesTokenDecimals;
    uint256 public immutable tokensToSell;
    uint256 public immutable totalEmission;
    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 public immutable receiveTime;
    address public immutable burnAddress;
    uint256 public immutable vestingProportion;

    uint256[] public tokensPerTicket;

    bool public started;
    bool public finished;

    uint256[] public totalCommitments;
    uint256[] public consumedTokens;
    uint256 public tokensToUserGrant;

    mapping(address => UserInfo) public userInfos;

    event Commit(address indexed buyer, uint256 amount);
    event Claim(address indexed buyer, uint256 eth, uint256 token, uint256 emission);
    event Claim2(address indexed buyer, uint256 token, uint256 emission);


    constructor(
        // 売る対象
        IERC20 _salesToken,
        // commitに使うトークン
        IERC20[] memory _buyerTokens,
        // 売る枚数
        uint256 _tokensToSell,
        // IDO開始時刻
        uint256 _startTime,
        // IDO終了時刻
        uint256 _endTime,
        // claim2開始時刻
        uint256 _receiveTime,
        // vest時間関連0でよくない？
        uint256 _vestingBegin,
        uint256 _vestingDuration,
        // vest割合 0でいいよ
        uint256 _vestingProportion,
        // 1チケットあたりトークンいくら？ 1e18とかそういう感じね
        uint256[] memory _tokensPerTicket,
        // vest用トークン枚数かな 0でいいよ
        uint256 _totalEmission,
        // バーンアドレス　売れ残りをここに送るっぽい
        address _burnAddress
    ) LinearVesting(_salesToken, _vestingBegin, _vestingDuration) {
        require(_startTime >= block.timestamp, "Start time must be in the future.");
        require(_endTime > _startTime, "End time must be greater than start time.");
        for (uint i = 0; i < _tokensPerTicket.length; ++i){
            require(_tokensPerTicket[i] > 0, "tokensPerTicket should be greater than 0");
        }
        require(_tokensPerTicket.length == _buyerTokens.length, "length mismatched");
        
        totalCommitments = new uint[](_buyerTokens.length);
        consumedTokens = new uint[](_buyerTokens.length);

        buyerTokens = _buyerTokens;
        salesToken = _salesToken;
        
        salesTokenDecimals = Token(address(salesToken)).decimals();
        tokensToSell = _tokensToSell;
        startTime = _startTime;
        endTime = _endTime;
        receiveTime = _receiveTime;
        tokensPerTicket = _tokensPerTicket;
        totalEmission = _totalEmission;
        burnAddress = _burnAddress;
        vestingProportion = _vestingProportion;
    }

    function returnUserInfo(address _addr) external view returns (UserInfo memory) {
        return userInfos[_addr];
    }

    function getStatus() external view returns (IERC20[] memory, uint, uint, uint[] memory, uint, uint[] memory) {
        return (buyerTokens, startTime, endTime, tokensPerTicket, tokensToSell, totalCommitments);
    }
    
    function start() external onlyOwner {
        require(!started, "Already started.");
        started = true;
        salesToken.safeTransferFrom(msg.sender, address(this), tokensToSell + totalEmission);
    }

    // 入金 _amount = ticketAmount
    function commit(uint _amount, address _token) external payable nonReentrant {
        //whitelist機能があるらしい 一旦無効で...
        /*
        require(
            keccak256(abi.encode(msg.sender)).toEthSignedMessageHash().recover(sig)
                == 0x9998719cd6CE8F82e8842c2c9b0C71AA1A5301BD,
            "not whitelisted"
        );*/
        // startTime ~ endTimeしか入金を許さん
        require(
            started && block.timestamp >= startTime && block.timestamp < endTime,
            "Can only deposit Ether during the sale period."
        );

        // 額の制限
        require(_amount > 0, "Commitment amount is outside the allowed range.");

        //このトークンって使えるやつ？
        (bool _success, uint _tokenIndex) = _checkAvailableToken(_token);
        require(_success, "this token is not available");

        IERC20(buyerTokens[_tokenIndex]).transferFrom(msg.sender, address(this), _amount * tokensPerTicket[_tokenIndex]);

        // 初期化 boolはデフォルトでfalseだから設定しなくていいらしい

        // userInfos[msg.sender].isClaimed = false;
        // userInfos[msg.sender].noRefund = false;

        // length == 0つまり初commitの場合は0入れて初期化
        if (userInfos[msg.sender].tickets.length == 0) {
            for (uint i = 0; i < buyerTokens.length; ++i){
                userInfos[msg.sender].tickets.push(0);
                userInfos[msg.sender].noRefund.push(false);
                userInfos[msg.sender].hasWon.push(false);
            }
        }

        userInfos[msg.sender].tickets[_tokenIndex] += _amount;
        totalCommitments[_tokenIndex] += _amount * tokensPerTicket[_tokenIndex];

        console.log(userInfos[msg.sender].tickets[0], userInfos[msg.sender].tickets[1]);

        emit Commit(msg.sender, _amount);
    }

    function _checkAvailableToken(address _token) internal view returns (bool, uint) {
        for (uint i = 0; i < buyerTokens.length; ++i) {
            if (address(buyerTokens[i]) == _token) {
                return (true, i);
            }
        }
        // 流石に10000トークンも使わないです
        return (false, 0);
    }
    function refund(uint _index) external nonReentrant {
        require(block.timestamp >= receiveTime, "not claimable yet");
        require(_index < buyerTokens.length, "invalid index");
        // 未返金の場合のみrefund
        require(userInfos[msg.sender].noRefund[_index] == false, "No refunds available");
        userInfos[msg.sender].noRefund[_index] = true;
        if (userInfos[msg.sender].tickets[_index] > 0) buyerTokens[_index].safeTransfer(msg.sender, userInfos[msg.sender].tickets[_index] * tokensPerTicket[_index]);

    }

    // ほんもののclaim これでトークンが貰えるっぽい
    function claim2() external nonReentrant {
        require(block.timestamp >= receiveTime, "not claimable yet");
        require(userInfos[msg.sender].isClaimed == false, "no claims available");
        //tokensToReceive
        uint256 a1 = userInfos[msg.sender].finalTokens;
        // 先着を考慮してない方
        uint256 a2 = userInfos[msg.sender].finalEmissions;
        require(a1 != 0 || a2 != 0, "no claims available");
        
        userInfos[msg.sender].isClaimed = true;
        userInfos[msg.sender].finalEmissions = 0;
        // vestingProportion = 3e17ぽい
        uint256 vesting = a1 * vestingProportion / 1e18;
        //30%をあとからclaimするようにしてるぽい　だからvestingProportionを0にすれば全額即時請求！
        _grantVestedReward(msg.sender, vesting);
        //なんでsalesTokenとemissionTokenが分かれてんの？
        salesToken.safeTransfer(msg.sender, a1 - vesting + a2);
        emit Claim2(msg.sender, a1, a2);
    }

    function finish() external onlyOwner {
        require(block.timestamp > endTime, "Can only finish after the sale has ended.");
        require(!finished, "Already finished.");
        finished = true;

        // 運営が売上吸おうとしても全額吸っちゃうから、なんとかしな
        // refund分だけ残してそれ以外を回収できる関数を作るべき
        for (uint i = 0; i < buyerTokens.length; ++i){
            if (consumedTokens[i] > 0) IERC20(buyerTokens[i]).transfer(owner(), consumedTokens[i]);
        }
        if (tokensToSell - tokensToUserGrant > 0){
            salesToken.safeTransfer(burnAddress, tokensToSell - tokensToUserGrant);
        }

    }

    function withdrawToken(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOwner {
        require( _to != address(0), "Cant be zero address");
        if (address(_token) == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            _token.safeTransfer(_to, _amount);
        }

    }

    function setResult(SetResultArgs[] memory _data) external onlyOwner {
        for(uint i = 0; i < _data.length; ++i){
            userInfos[_data[i].addr].finalTokens = _data[i].amount;
            userInfos[_data[i].addr].noRefund = _data[i].refundFlag;
            userInfos[_data[i].addr].hasWon = _data[i].refundFlag;
            
            for (uint j = 0; j < buyerTokens.length; ++j){
                if (userInfos[_data[i].addr].tickets[j] > 0) consumedTokens[j] += userInfos[_data[i].addr].tickets[j] * tokensPerTicket[j];
            }
            tokensToUserGrant += _data[i].amount;
        }
        require(tokensToUserGrant <= tokensToSell, "over tokenAmount");
    }

    function setConsumedTokens(uint _index, uint _amount) external onlyOwner {
        consumedTokens[_index] = _amount;
    }

    function setTokensToUserGrant(uint _amount) external onlyOwner {
        tokensToUserGrant = _amount;
    }
}