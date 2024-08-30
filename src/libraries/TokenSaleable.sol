// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PriceValidatable} from "./PriceValidatable.sol";
import {PriceUpdatable} from "./PriceUpdatable.sol";
import {BasicToken} from "./BasicToken.sol";

// TokenSaleable is a contract that provides a functions to buy token with USDT
abstract contract TokenSaleable is
    BasicToken,
    PriceValidatable,
    PriceUpdatable
{
    using SafeERC20 for IERC20;

    // revert when not enough sales limit
    error NotEnoughSalesLimit();

    // the daily token sales increase amount
    uint256 public DAILY_TOKEN_SALES_INCREASE;

    // the total available sales limit
    uint256 public currentSalesLimit;

    // the last day the sales limit was updated
    int256 public currentSalesLimitUpdateTime;

    // USDT is 6 decimals
    uint256 public constant USDT_PRECISION = 1e6;

    // Token is 18 decimals
    uint256 public constant TOKEN_PRECISION = 1e18;

    // 1 day in seconds = 24 * 60 * 60 = 86400
    uint256 public constant SECONDS_PER_DAY = 86400; 

    // event for when a user buys token
    event Buy(
        address indexed buyer,
        uint256 indexed amountUSDT,
        uint256 indexed amountToken
    );

    // Initializes the contract
    function __TokenSaleable_init(
        uint256 _initialSalesToken,
        uint256 _validateTimeInterval
    ) internal initializer {
        currentSalesLimit = _initialSalesToken;
        currentSalesLimitUpdateTime = int256(block.timestamp / SECONDS_PER_DAY);
        __PriceValidatable_init(_validateTimeInterval);
    }

    // set the daily token sales increase amount
    function setDailyTokenSalesIncrease(uint256 _newAmount) public onlyOwner {
        _salesLimitQuantityUpdate();
        DAILY_TOKEN_SALES_INCREASE = _newAmount;
    }

    // get the current sales limit quantity
    function getCurrentSalesLimit() external view returns (uint256) {
        int256 currentDay = int256(block.timestamp / SECONDS_PER_DAY);

        if (currentDay > currentSalesLimitUpdateTime) {
            int256 daysPassed = currentDay - currentSalesLimitUpdateTime;
            uint256 increasedSalesToken = uint256(daysPassed) *
                DAILY_TOKEN_SALES_INCREASE;
            return
                Math.min(
                    currentSalesLimit + increasedSalesToken,
                    nonIssueApexTreasury
                );
        } else {
            return Math.min(currentSalesLimit, nonIssueApexTreasury);
        }
    }

    // update the current sales limit quantity
    function _salesLimitQuantityUpdate() internal {
        int256 currentDay = int256(block.timestamp / SECONDS_PER_DAY);
        if (currentDay > currentSalesLimitUpdateTime) {
            int256 daysPassed = currentDay - currentSalesLimitUpdateTime;
            uint256 increasedSalesToken = uint256(daysPassed) *
                DAILY_TOKEN_SALES_INCREASE;
            currentSalesLimit += increasedSalesToken;
            currentSalesLimitUpdateTime = currentDay;
        }
    }

    // user buy token with USDT
    function buy(
        uint256 usdtAmount
    )
        external
        whenNotPaused
        priceValidated(currentPriceUpdateTime)
        returns (uint256)
    {
        require(
            usdtToken.balanceOf(msg.sender) >= usdtAmount,
            "Insufficient balance"
        );
        require(
            usdtToken.allowance(msg.sender, address(this)) >= usdtAmount,
            "Insufficient allowance"
        );
        require(currentPrice > 0, "Price is invalid");
        if (usdtAmount <= 0) revert AmountMustBeMoreThanZero();

        _salesLimitQuantityUpdate();

        uint256 buyTokenNumber = (usdtAmount *
            (TOKEN_PRECISION / USDT_PRECISION) *
            TOKEN_PRECISION) / currentPrice;
        if (Math.min(currentSalesLimit, nonIssueApexTreasury) < buyTokenNumber)
            revert NotEnoughSalesLimit();

        usdtToken.safeTransferFrom(msg.sender, address(this), usdtAmount);
        usdtTreasury += usdtAmount;
        accUsdtTreasury += usdtAmount;
        currentSalesLimit -= buyTokenNumber;
        nonIssueApexTreasury -= buyTokenNumber;
        mint(msg.sender, buyTokenNumber);

        emit Buy(msg.sender, usdtAmount, buyTokenNumber);

        return buyTokenNumber;
    }
}
