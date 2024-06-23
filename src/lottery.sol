// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";

interface Token {
    function decimals() external returns (uint);
}
contract StructList {
    struct UserInfo {
        uint256[] tickets;
        bool[] noRefund;
        bool isClaimed;
        uint256[] wonTickets;
    }

    struct SetResultArgs {
        address addr;
        uint256[] wonTicketsAmount;
    }
}
contract Vesting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;
    uint256 public immutable vestBeginning;
    uint256 public immutable vestDuration;

    mapping(address => uint256) public claimableTotal;
    mapping(address => uint256) public claimed;
    mapping(address => bool) public registered;

    event ClaimVesting(address addr, uint256 amount);

    constructor(
        IERC20 rewardToken_,
        uint256 vestBeginning_,
        uint256 vestDuration_
    ) {
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
            vested = Math.mulDiv(
                claimableTotal[addr],
                block.timestamp - vestBeginning,
                vestDuration
            );
        }

        uint256 delta = vested - claimed[addr];
        claimed[addr] = vested;

        rewardToken.safeTransfer(addr, delta);
        emit ClaimVesting(addr, delta);
        return delta;
    }
}

contract LotteryIDO is
    Ownable(msg.sender),
    ReentrancyGuard,
    Vesting,
    StructList
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    IERC20[] public buyerTokens;
    IERC20 public immutable salesToken;
    uint256 public immutable tokensToSell;
    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 public immutable receiveTime;
    address public immutable burnAddress;
    uint256 public vestingProportion;

    uint256[] public tokensPerTicket;

    bool public started;
    bool public finished;

    uint256[] public totalCommitments;
    uint256[] public consumedTokens;
    uint256 public tokensToUserGrant;

    mapping(address => UserInfo) public userInfos;
    uint256[] public prizeAmountPerTicket;

    event Commit(address indexed buyer, address token, uint256 amount);
    event Claim(
        address indexed buyer,
        uint256 eth,
        uint256 token,
        uint256 emission
    );
    event Claim2(address indexed buyer, uint256 token);

    constructor(
        IERC20 _salesToken,
        IERC20[] memory _buyerTokens,
        uint256 _tokensToSell,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _receiveTime,
        uint256 _vestingBegin,
        uint256 _vestingDuration,
        uint256 _vestingProportion,
        uint256[] memory _tokensPerTicket,
        address _burnAddress
    ) Vesting(_salesToken, _vestingBegin, _vestingDuration) {
        require(
            _startTime >= block.timestamp,
            "Start time must be in the future."
        );
        require(
            _endTime > _startTime,
            "End time must be greater than start time."
        );
        for (uint i = 0; i < _tokensPerTicket.length; ++i) {
            require(
                _tokensPerTicket[i] > 0,
                "tokensPerTicket should be greater than 0"
            );
        }
        require(
            _tokensPerTicket.length == _buyerTokens.length,
            "length mismatched"
        );
        require(
            vestingProportion <= 1e18,
            "Vesting proportion must not exceed 100%"
        );

        totalCommitments = new uint[](_buyerTokens.length);
        consumedTokens = new uint[](_buyerTokens.length);
        prizeAmountPerTicket = new uint[](_buyerTokens.length);

        buyerTokens = _buyerTokens;
        salesToken = _salesToken;

        tokensToSell = _tokensToSell;
        startTime = _startTime;
        endTime = _endTime;
        receiveTime = _receiveTime;
        tokensPerTicket = _tokensPerTicket;
        burnAddress = _burnAddress;
        vestingProportion = _vestingProportion;
    }

    function returnUserInfo(
        address _addr
    ) external view returns (UserInfo memory) {
        return userInfos[_addr];
    }

    function getStatus()
        external
        view
        returns (
            IERC20[] memory,
            uint,
            uint,
            uint,
            uint[] memory,
            uint,
            uint[] memory
        )
    {
        return (
            buyerTokens,
            startTime,
            endTime,
            receiveTime,
            tokensPerTicket,
            tokensToSell,
            totalCommitments
        );
    }

    function start() external onlyOwner {
        require(!started, "Already started.");
        started = true;
        salesToken.safeTransferFrom(msg.sender, address(this), tokensToSell);
    }

    function updateVestingProportion(
        uint256 _newVestingProportion
    ) external onlyOwner {
        require(
            _newVestingProportion <= 1e18,
            "Vesting proportion must not exceed 100%"
        );
        require(block.timestamp < vestBeginning, "already started vesting");
        vestingProportion = _newVestingProportion;
    }

    function commit(
        uint _amount,
        address _token
    ) external payable nonReentrant {
        require(
            started &&
                block.timestamp >= startTime &&
                block.timestamp < endTime,
            "Can only deposit Ether during the sale period."
        );

        require(_amount > 0, "Commitment amount is outside the allowed range.");

        (bool _success, uint _tokenIndex) = _checkAvailableToken(_token);
        require(_success, "this token is not available");

        IERC20(buyerTokens[_tokenIndex]).transferFrom(
            msg.sender,
            address(this),
            _amount * tokensPerTicket[_tokenIndex]
        );

        if (userInfos[msg.sender].tickets.length == 0) {
            uint tokensLength = buyerTokens.length;
            for (uint i = 0; i < tokensLength; ++i) {
                userInfos[msg.sender].tickets.push(0);
                userInfos[msg.sender].noRefund.push(false);
                userInfos[msg.sender].wonTickets.push(0);
            }
        }

        userInfos[msg.sender].tickets[_tokenIndex] += _amount;
        totalCommitments[_tokenIndex] += _amount * tokensPerTicket[_tokenIndex];

        emit Commit(msg.sender, _token, _amount);
    }

    function _checkAvailableToken(
        address _token
    ) internal view returns (bool, uint) {
        uint tokensLength = buyerTokens.length;
        for (uint i = 0; i < tokensLength; ++i) {
            if (address(buyerTokens[i]) == _token) {
                return (true, i);
            }
        }

        return (false, 0);
    }
    function refund(uint _index) external nonReentrant {
        require(block.timestamp >= receiveTime, "not claimable yet");
        require(_index < buyerTokens.length, "invalid index");
        require(
            userInfos[msg.sender].noRefund[_index] == false &&
                userInfos[msg.sender].tickets[_index] >
                userInfos[msg.sender].wonTickets[_index],
            "No refunds available"
        );
        userInfos[msg.sender].noRefund[_index] = true;

        buyerTokens[_index].safeTransfer(
            msg.sender,
            (userInfos[msg.sender].tickets[_index] -
                userInfos[msg.sender].wonTickets[_index]) *
                tokensPerTicket[_index]
        );
    }

    function checkClaimAmount(address _user) external view returns (uint) {
        uint256 a1 = 0;
        if (userInfos[msg.sender].isClaimed == true) return 0;
        for (uint i = 0; i < buyerTokens.length; ++i) {
            a1 += prizeAmountPerTicket[i] * userInfos[_user].wonTickets[i];
        }
        return a1;
    }

    function claim2() external nonReentrant {
        require(block.timestamp >= receiveTime, "not claimable yet");
        require(
            userInfos[msg.sender].isClaimed == false,
            "no claims available"
        );

        uint256 a1 = 0;
        for (uint i = 0; i < buyerTokens.length; ++i) {
            a1 += prizeAmountPerTicket[i] * userInfos[msg.sender].wonTickets[i];
        }

        require(a1 != 0, "no claims available");

        userInfos[msg.sender].isClaimed = true;

        uint256 vesting = (a1 * vestingProportion) / 1e18;

        _grantVestedReward(msg.sender, vesting);

        salesToken.safeTransfer(msg.sender, a1 - vesting);
        emit Claim2(msg.sender, a1);
    }

    function finish() external onlyOwner {
        require(
            block.timestamp > endTime,
            "Can only finish after the sale has ended."
        );
        require(!finished, "Already finished.");
        finished = true;
        uint tokensLength = buyerTokens.length;
        for (uint i = 0; i < tokensLength; ++i) {
            if (consumedTokens[i] > 0)
                IERC20(buyerTokens[i]).safeTransfer(owner(), consumedTokens[i]);
        }
        if (tokensToSell - tokensToUserGrant > 0) {
            salesToken.safeTransfer(
                burnAddress,
                tokensToSell - tokensToUserGrant
            );
        }
    }

    function withdrawToken(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOwner {
        require(_to != address(0), "Cant be zero address");
        if (address(_token) == address(0)) {
            (bool success, ) = payable(_to).call{value: _amount}("");
            require(success, "Ether transfer failed");
        } else {
            _token.safeTransfer(_to, _amount);
        }
    }

    function setPrizeAmountPerTicket(
        uint _index,
        uint _amount
    ) external onlyOwner {
        prizeAmountPerTicket[_index] = _amount;
    }

    function setResult(SetResultArgs[] memory _data) external onlyOwner {
        uint tokensLength = buyerTokens.length;

        for (uint i = 0; i < tokensLength; ++i) {
            require(
                prizeAmountPerTicket[i] > 0,
                "please set PrizeAmountPerTicket"
            );
        }

        uint dataLength = _data.length;

        for (uint i = 0; i < dataLength; ++i) {
            userInfos[_data[i].addr].wonTickets = _data[i].wonTicketsAmount;

            for (uint j = 0; j < tokensLength; ++j) {
                require(
                    userInfos[_data[i].addr].tickets[j] >=
                        userInfos[_data[i].addr].wonTickets[j],
                    "over ticket amount"
                );
                consumedTokens[j] +=
                    userInfos[_data[i].addr].wonTickets[j] *
                    tokensPerTicket[j];

                tokensToUserGrant +=
                    userInfos[_data[i].addr].wonTickets[j] *
                    prizeAmountPerTicket[j];
            }
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
