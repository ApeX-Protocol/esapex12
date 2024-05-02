// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BasicToken} from "./BasicToken.sol";

// Timelockable is a contract that provides a functions to timelock the token (esApex12),
// and redeem the token (ApeX) after the lock period
abstract contract Timelockable is BasicToken {
    using SafeERC20 for IERC20;

    // the lock period is 365 days
    uint256 public constant LOCK_PERIOD = 365 days;

    // struct to store the timelock information
    struct timelockTokenInfo {
        address owner;
        uint256 amount;
        uint256 timelockStart;
        bool valid;
    }

    // mapping of timelockTokenInfo to store the timelock infomation
    // mapping(uint256 => timelockTokenInfo) public timelockToken;
    timelockTokenInfo[] public timelockToken;

    // increase the timelockId when the user timelock the token
    uint256 public timelockId;

    // TimelockCreated event trigged when user timelock the token
    event TimelockCreated(
        uint256 indexed timelockId,
        address indexed user,
        uint256 amount,
        uint256 timelockStart
    );

    // TimelockRedeemed event trigged when user redeemed the token after timelock period
    event TimelockRedeemed(uint256 indexed timelockId, address indexed user);

    // TimelockCancelled event trigged when user cancelled the timelock
    event TimelockCancelled(uint256 indexed timelockId, address indexed user);

    // function to create timelock
    function createTimelock(uint256 amount) external whenNotPaused {
        require(amount > 0, "Cannot timelock zero tokens");
        require(
            IERC20(address(this)).balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );

        burn(msg.sender, amount);
        timelockToken.push(
            timelockTokenInfo({
                owner: msg.sender,
                amount: amount,
                timelockStart: block.timestamp,
                valid: true
            })
        );

        emit TimelockCreated(timelockId, msg.sender, amount, block.timestamp);

        timelockId++;
    }

    // function to redeem the timelock token after the lock period
    function redeemTimelock(uint256 id) external whenNotPaused {
        require(id < timelockId, "Invalid id");
        timelockTokenInfo storage lockInfo = timelockToken[id];

        require(msg.sender == lockInfo.owner, "Only owner can redeem");
        require(
            block.timestamp >= lockInfo.timelockStart + LOCK_PERIOD,
            "Still in lock period"
        );
        require(lockInfo.valid, "Not valid");

        apeXToken.safeTransfer(msg.sender, lockInfo.amount);
        apexTreasury -= lockInfo.amount;
        lockInfo.valid = false;

        emit TimelockRedeemed(id, msg.sender);
    }

    // function to cancel timelock
    function cancelTimelock(uint256 id) external whenNotPaused {
        require(id < timelockId, "Invalid id");
        timelockTokenInfo storage lockInfo = timelockToken[id];

        require(msg.sender == lockInfo.owner, "Only owner can cancel");
        require(
            block.timestamp < lockInfo.timelockStart + LOCK_PERIOD,
            "Not in lock period"
        );
        require(lockInfo.valid, "Not valid");

        mint(msg.sender, lockInfo.amount);
        lockInfo.valid = false;

        emit TimelockCancelled(id, msg.sender);
    }
}
