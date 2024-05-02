// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LPToken is ERC20, Ownable {
    address tokenFactory;

    // mapping to store the whitelisted address
    // only whitelisted address can transfer the token
    mapping(address => bool) public isWhitelisted;

    event Whitelisted(address account, bool whitelisted);

    modifier onlyTokenFactory() {
        require(_msgSender() == tokenFactory, "Caller is not token factory");
        _;
    }
    // constructor to initialize the contract

    constructor(string memory name, string memory symbol, address initialOwner)
        ERC20(name, symbol)
        Ownable(initialOwner)
    {
        tokenFactory = _msgSender();
        isWhitelisted[address(0)] = true;
    }

    // function to add/remove the address to the whitelist
    function setWhitelist(address _address, bool _whitelisted) public onlyOwner {
        isWhitelisted[_address] = _whitelisted;
        emit Whitelisted(_address, _whitelisted);
    }

    function mint(address to, uint256 amount) public onlyTokenFactory {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        require(isWhitelisted[from], "Transfer not allowed");
        super._update(from, to, value);
    }
}
