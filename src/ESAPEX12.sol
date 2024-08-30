// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import {InitalStakeable} from "./libraries/InitalStakeable.sol";
import {TokenSaleable} from "./libraries/TokenSaleable.sol";
import {Timelockable} from "./libraries/Timelockable.sol";

contract ESAPEX12 is InitalStakeable, TokenSaleable, Timelockable {
    constructor() {
        _disableInitializers();
    }

    // Initializes the contract
    function initialize(
        address _owner,
        address _usdtToken,
        address _apeXToken,
        string memory name,
        string memory symbol,
        uint256 _initialSalesToken,
        uint256 _validateTimeInterval
    ) external initializer {
        __BasicToken_init(_owner, _usdtToken, _apeXToken, name, symbol);
        __TokenSaleable_init(_initialSalesToken, _validateTimeInterval); 
    }

    /*//////////////////////////////////////////////////////////////
                       GLOBAL PAUSE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    uint256[50] private __gap;
}
