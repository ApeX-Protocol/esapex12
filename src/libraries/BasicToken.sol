// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {LPToken} from "./LPToken.sol";

// BasicToken is a contract that provides a basic token structure and constants
abstract contract BasicToken is
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    // the USDT token for Token Sale
    IERC20 public usdtToken;

    // the APEX token for Timelock
    IERC20 public apeXToken;

    // the LP token
    LPToken public lpToken;

    // the treasury apex balance
    uint256 public apexTreasury;
    // the amount of total APEX did not issue esApex12 in the treasury
    uint256 public nonIssueApexTreasury;

    // the treasury USDT balance
    uint256 public usdtTreasury;
    // the accumulated treasury USDT balance
    uint256 public accUsdtTreasury;

    error AmountMustBeMoreThanZero();

    // Initializes the contract
    function __BasicToken_init(
        address _owner,
        address _usdtToken,
        address _apeXToken,
        string memory name,
        string memory symbol
    ) internal initializer {
        require(_usdtToken != address(0), "USDT token is the zero address");
        require(_apeXToken != address(0), "ApeX token is the zero address");

        usdtToken = IERC20(_usdtToken);
        apeXToken = IERC20(_apeXToken);

        __Ownable_init(_owner);
        __Pausable_init();
        __ERC20_init(name, symbol);

        // create the LP token
        lpToken = new LPToken("APEX LP Token", "APEX-LP", _owner);
    }

    /*//////////////////////////////////////////////////////////////
                      Token Mint && Burn
    //////////////////////////////////////////////////////////////*/

    // mint the token
    function mint(address to, uint256 amount) internal returns (bool) {
        if (amount <= 0) {
            revert AmountMustBeMoreThanZero();
        }
        _mint(to, amount);
        return true;
    }

    // burn the token
    function burn(address account, uint256 amount) internal {
        if (amount <= 0) {
            revert AmountMustBeMoreThanZero();
        }
        _burn(account, amount);
    }
}
