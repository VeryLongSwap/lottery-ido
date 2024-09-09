// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract ERC is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 30_000_001 ether; // 18 decimals
    bool internal _paused;

    /***************************************************************************
     * EVENTS
     */

    /// Emitted when contract is paused (true) or unpaused (false).
    event ContractPaused(bool indexed state);

    /***************************************************************************
     * CUSTOM ERRORS
     */

    /// Transfers are paused during LP setup.
    error TokenTransfersArePaused();
    /// Value must be greater than zero.
    error NoZeroValueTransfers();

    /***************************************************************************
     * FUNCTIONS
     */

    /**
     * @notice Mint the entire supply on deployment, to the deployer.
     */
    constructor(address _admin) ERC20("weth9", "wewe") Ownable(_admin) {
        _mint(_admin, MAX_SUPPLY);
        _paused = false;
    }

    /**
     * @notice Burn your own tokens.
     */
    function burn(uint256 value) external {
        _burn(msg.sender, value);
    }
    function mint(address addr, uint value) external {
        _mint(addr, value);
    }

    /**
     * @notice Contract owner can pause and unpause token transfers.
     * @param paused True to pause. False to unpause.
     */
    function setPause(bool paused) external onlyOwner {
        _paused = paused;
        emit ContractPaused(paused);
    }


    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        if (_paused) {
            if (from != owner() && to != owner()) {
                revert TokenTransfersArePaused();
            }
        }
        super._update(from, to, value);
    }
}   