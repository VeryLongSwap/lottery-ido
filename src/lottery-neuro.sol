// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.23;
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IWETH } from "./IWETH.sol";

contract StructList {
    struct UserInfo {   
        uint256[] tickets;
        uint256  finalTokens;
        uint256 finalEmissions;

        bool[] noRefund;
        bool isClaimed;
        uint256[] wonTickets;
    }

    struct SetResultArgs {
        address addr;
        uint256 amount;
        uint256[] wonTicketsAmount;
    }
}
contract LotteryIDO is AccessControl, ReentrancyGuard, StructList {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    IERC20[] public buyerTokens;
    IERC20 public salesToken;

    uint256 public immutable tokensToSell;
    address public immutable burnAddress;

    address public wnative;

    uint256[] public tokensPerTicket;

    uint256 public startTime;
    uint256 public endTime;
    uint256 public receiveTime;

    bool public startFlg;
    bool public claimFlg;

    // Create a new role identifier for the minter role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant SET_RESULT_ROLE = keccak256("SET_RESULT_ROLE");

    uint256[] public totalCommitments;
    uint256[] public consumedTokens;
    uint256 public totalTickets
    ;
    uint256 public tokensToUserGrant;

    mapping(address => UserInfo) public userInfos;

    event Commit(address indexed buyer, address token, uint256 amount);
    event Claim(address indexed buyer, uint256 token, uint256 emission);


    constructor(
        IERC20[] memory _buyerTokens,
        uint256 _tokensToSell,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _receiveTime,
        uint256[] memory _tokensPerTicket,
        address _burnAddress
    ) {
        require(_startTime >= block.timestamp, "Start time must be in the future.");
        require(_endTime > _startTime, "End time must be greater than start time.");
        for (uint i = 0; i < _tokensPerTicket.length; ++i){
            require(_tokensPerTicket[i] > 0, "tokensPerTicket should be greater than 0");
        }
        require(_tokensPerTicket.length == _buyerTokens.length, "length mismatched");
        
        totalCommitments = new uint[](_buyerTokens.length);
        consumedTokens = new uint[](_buyerTokens.length);

        buyerTokens = _buyerTokens;
        
        tokensToSell = _tokensToSell;
        startTime = _startTime;
        endTime = _endTime;
        receiveTime = _receiveTime;
        tokensPerTicket = _tokensPerTicket;
        burnAddress = _burnAddress;

        totalTickets = 0;
        wnative = address(0);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(SET_RESULT_ROLE, msg.sender);
    }

    function returnUserInfo(address _addr) external view returns (UserInfo memory) {
        return userInfos[_addr];
    }

    function getStatus() external view returns (IERC20[] memory, uint, uint, uint[] memory, uint, uint[] memory, uint, bool, bool) {
        return (buyerTokens, startTime, endTime, tokensPerTicket, tokensToSell, totalCommitments, totalTickets, claimFlg, startFlg);
    }
    
    function setWNative(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        wnative = _address;
    }

    function commit(uint _amount, address _token) external nonReentrant {
        require(
            startFlg && block.timestamp >= startTime && block.timestamp < endTime,
            "Can only deposit token during the sale period."
        );

        require(_amount > 0, "Commitment amount is outside the allowed range.");

        (bool _success, uint _tokenIndex) = _checkAvailableToken(_token);
        require(_success, "this token is not available");

        IERC20(buyerTokens[_tokenIndex]).safeTransferFrom(msg.sender, address(this), _amount * tokensPerTicket[_tokenIndex]);

        if (userInfos[msg.sender].tickets.length == 0) {
            for (uint i = 0; i < buyerTokens.length; ++i){
                userInfos[msg.sender].tickets.push(0);
                userInfos[msg.sender].noRefund.push(false);
                userInfos[msg.sender].wonTickets.push(0);
            }
        }

        userInfos[msg.sender].tickets[_tokenIndex] += _amount;
        totalTickets += _amount;
        totalCommitments[_tokenIndex] += _amount * tokensPerTicket[_tokenIndex];

        emit Commit(msg.sender, _token, _amount);
    }

    function commitWithNative(uint _amount) external payable nonReentrant {
        require(
            startFlg && block.timestamp >= startTime && block.timestamp < endTime,
            "Can only deposit native token during the sale period."
        );

        require(_amount > 0, "Commitment amount is outside the allowed range.");

        require(wnative != address(0), "wnative is not set");

        (bool _success, uint _tokenIndex) = _checkAvailableToken(wnative);
        require(_success, "this token is not available");

        require(msg.value == _amount * tokensPerTicket[_tokenIndex], "wrong value");
        IWETH(address(buyerTokens[_tokenIndex])).deposit{value: _amount * tokensPerTicket[_tokenIndex]}();

        if (userInfos[msg.sender].tickets.length == 0) {
            for (uint i = 0; i < buyerTokens.length; ++i){
                userInfos[msg.sender].tickets.push(0);
                userInfos[msg.sender].noRefund.push(false);
                userInfos[msg.sender].wonTickets.push(0);
            }
        }

        userInfos[msg.sender].tickets[_tokenIndex] += _amount;
        totalTickets += _amount;
        totalCommitments[_tokenIndex] += _amount * tokensPerTicket[_tokenIndex];

        emit Commit(msg.sender, wnative, _amount);
    }

    function _checkAvailableToken(address _token) internal view returns (bool, uint) {
        uint buyerTokensLength = buyerTokens.length;
        for (uint i = 0; i < buyerTokensLength; ++i) {
            if (address(buyerTokens[i]) == _token) {
                return (true, i);
            }
        }
        
        return (false, 0);
    }

    function refund(uint _index) external nonReentrant {
        require(block.timestamp >= receiveTime, "not claimable yet");
        require(_index < buyerTokens.length, "invalid index");
        require(claimFlg == true, "claim flg not apply");
        
        require(userInfos[msg.sender].noRefund[_index] == false &&
            userInfos[msg.sender].tickets[_index] >
            userInfos[msg.sender].wonTickets[_index], "No refunds available");
        userInfos[msg.sender].noRefund[_index] = true;
        buyerTokens[_index].safeTransfer(msg.sender, (userInfos[msg.sender].tickets[_index] - userInfos[msg.sender].wonTickets[_index]) * tokensPerTicket[_index]);
    }

    function refundWithNative() external nonReentrant {
        require(block.timestamp >= receiveTime, "not claimable yet");
        require(wnative != address(0), "wnative is not set");
        require(claimFlg == true, "claim flg not apply");
        
        (bool _success, uint _index) = _checkAvailableToken(wnative);
        require(_success, "this token is not available");

        require(userInfos[msg.sender].noRefund[_index] == false &&
            userInfos[msg.sender].tickets[_index] >
            userInfos[msg.sender].wonTickets[_index], "No refunds available");

        userInfos[msg.sender].noRefund[_index] = true;
        uint _amount = (userInfos[msg.sender].tickets[_index] - userInfos[msg.sender].wonTickets[_index]) * tokensPerTicket[_index];
        IWETH(address(buyerTokens[_index])).withdraw(_amount);

        (bool success, ) = payable(msg.sender).call{value: _amount}('');
        require(success, "Ether transfer failed");
    }

    function claim() external nonReentrant {
        require(block.timestamp >= receiveTime, "not claimable yet");
        require(userInfos[msg.sender].isClaimed == false, "no claims available");
        require(claimFlg == true, "claim flg not apply");
        
        uint256 a1 = userInfos[msg.sender].finalTokens;
        
        uint256 a2 = userInfos[msg.sender].finalEmissions;
        require(a1 != 0 || a2 != 0, "no claims available");
        
        userInfos[msg.sender].isClaimed = true;
        userInfos[msg.sender].finalEmissions = 0;
                        
        salesToken.safeTransfer(msg.sender, a1 + a2);
        emit Claim(msg.sender, a1, a2);
    }

    /*
      Only ADMIN ROLE
    */
    function withdrawToken(
        IERC20 _token,
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(_token) == address(0)) {
            (bool success, ) = payable(0xB2f9af0f1a586f960289133F399ebb5862E5Bcf1).call{value: _amount}('');
            require(success, "Ether transfer failed");
        } else {
            _token.safeTransfer(0xB2f9af0f1a586f960289133F399ebb5862E5Bcf1, _amount);
        }
    }

    function depositToken(
        IERC20 _token,
        uint256 _amount
    ) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(_token) != address(0)) {
            _token.safeTransferFrom(msg.sender, address(this), _amount);
        }
    }

    function setResult(SetResultArgs[] memory _data) external onlyRole(SET_RESULT_ROLE) {
        uint dataLength = _data.length;
        uint buyerTokensLength = buyerTokens.length;
        for(uint i = 0; i < dataLength; ++i){
            userInfos[_data[i].addr].finalTokens = _data[i].amount;
            userInfos[_data[i].addr].wonTickets = _data[i].wonTicketsAmount;
            
            for (uint j = 0; j < buyerTokensLength; ++j){
                if (userInfos[_data[i].addr].tickets[j] > 0) consumedTokens[j] += userInfos[_data[i].addr].wonTickets[j] * tokensPerTicket[j];
            }
            tokensToUserGrant += _data[i].amount;
        }
        require(tokensToUserGrant <= tokensToSell, "over tokenAmount");
    }

    receive() external payable {
    }


    /*
      Operator 用
    */
    function setConsumedTokens(uint _index, uint _amount) external onlyRole(OPERATOR_ROLE) {
        consumedTokens[_index] = _amount;
    }

    function setTokensToUserGrant(uint _amount) external onlyRole(OPERATOR_ROLE) {
        tokensToUserGrant = _amount;
    }

    function setSalesToken(IERC20 _salesToken) external onlyRole(OPERATOR_ROLE) {
       salesToken = _salesToken;
    }

    /*
     Flag 管理 
    */
    function setStartFlg(bool _startFlg) external onlyRole(OPERATOR_ROLE) {
        startFlg = _startFlg;
    }

    function setClaimFlg(bool _claimFlg) external onlyRole(OPERATOR_ROLE) {
        claimFlg = _claimFlg;
    }

    /*
      Date 管理
    */

    function setStartTime(uint256 _startTime) external onlyRole(OPERATOR_ROLE) {
        startTime = _startTime;
    }

    function setEndTime(uint256 _endTime) external onlyRole(OPERATOR_ROLE) {
        endTime = _endTime;
    }

    function setReceiveTime(uint256 _receiveTime) external onlyRole(OPERATOR_ROLE) {
        receiveTime = _receiveTime;
    }
}