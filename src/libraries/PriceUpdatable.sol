// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// PriceUpdatable is a contract that provides a functions to update the prices
abstract contract PriceUpdatable is OwnableUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // the address of the signer
    address public signer;

    // current price of esAPEX12, and the time when the price was updated
    uint256 public currentPrice;
    uint256 public currentPriceUpdateTime;
    uint256 public currentPriceIndex;

    // event to notify the price update
    event PriceUpdated(uint256 indexed newPrice, address indexed updater);

    // set the signer address
    function setSigner(address _newSigner) public onlyOwner {
        require(_newSigner != address(0), "Zero address");
        signer = _newSigner;
    }

    // modifier to check the signature
    modifier checkSignature(uint256 priceIndex, uint256 newPrice, bytes memory signature) {
        bytes memory message = abi.encodePacked(msg.sender, priceIndex, newPrice, block.chainid);

        require(keccak256(message).toEthSignedMessageHash().recover(signature) == signer, "Illegal signature");
        _;
    }

    // verify signature and update the price of esAPEX12
    function updatePrice(uint256 priceIndex, uint256 newPrice, bytes memory signature)
        external
        checkSignature(priceIndex, newPrice, signature)
    {
        require(priceIndex > currentPriceIndex, "The price index should be newer than the current price index");

        currentPrice = newPrice;
        currentPriceIndex = priceIndex;
        currentPriceUpdateTime = block.timestamp;

        emit PriceUpdated(newPrice, msg.sender);
    }
}
