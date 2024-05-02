// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// PriceValidatable is a contract that provides a modifier to check if the price is valid
abstract contract PriceValidatable is OwnableUpgradeable {
    // the maximal validate time interval for the price
    uint256 public validateTimeInterval;

    // reverts if the price is invalid
    error InvalidPrice();

    // Initializes the contract
    function __PriceValidatable_init(uint256 _validateTimeInterval) internal onlyInitializing {
        validateTimeInterval = _validateTimeInterval;
    }

    // check if the price is valid
    modifier priceValidated(uint256 updatedAt) {
        if (block.timestamp - updatedAt > validateTimeInterval) {
            revert InvalidPrice();
        }
        _;
    }

    // owner can change the validate time interval
    function setValidateTimeInterval(uint256 _newTime) public onlyOwner {
        validateTimeInterval = _newTime;
    }
}
