// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BasicToken} from "./BasicToken.sol";

// InitalStakeable contract is the contract that inital staker to stake the APEX token
abstract contract InitalStakeable is BasicToken {
    using SafeERC20 for IERC20;

    // the inital staker APEX amount mapping
    mapping(address => uint256) public initalStakerApexAmount;

    // the amount of total USDT claim by the staker
    mapping(address => uint256) public totalClaimAmount;

    // the amount of total APEX staked by the inital staker
    uint256 public totalStaked;

    // state variable to allow / disallow the inital staker to stake
    bool public isInitalStakingAllowed = true;

    // event to notify the inital staker update
    event InitalStakerUpdated(address user, bool isAllowed);

    // event to notify the inital staker staked the APEX
    event InitalStakerApexStaked(address indexed user, uint256 amount);

    // event to notify the inital staker claim the USDT from the treasury
    event ClaimFromTreasury(address indexed user, uint256 indexed amount);

    event ForceExit(address indexed owner, uint256 indexed amount);

    // when the account is not InitalStaker, it not allowed to call the function
    error NotAllowed();

    // modifier to check the stage which allow inital staker to stake
    modifier allowInitalStaking() {
        if (isInitalStakingAllowed != true) {
            revert NotAllowed();
        }
        _;
    }

    // function to set the inital staking allowed, only owner can call this function
    function setisInitalStakingAllowed(bool _isAllowed) external onlyOwner {
        isInitalStakingAllowed = _isAllowed;
    }

    // function to stake the APEX token
    function stakeAPEX(
        address staker,
        uint256 amount
    ) external onlyOwner allowInitalStaking whenNotPaused {
        require(amount > 0, "Cannot stake zero tokens");
        require(
            apeXToken.balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );
        require(
            apeXToken.allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance"
        );

        apeXToken.safeTransferFrom(msg.sender, address(this), amount);
        totalStaked += amount;
        apexTreasury += amount;
        nonIssueApexTreasury += amount;
        initalStakerApexAmount[staker] += amount;

        lpToken.mint(staker, amount);

        emit InitalStakerApexStaked(staker, amount);
    }

    // function to claim the USDT token
    function claimFromTreasury(uint256 amount) external whenNotPaused {
        require(amount > 0, "Cannot withdraw zero tokens");
        uint256 withdrawableAmount = calcClaimableAmount(msg.sender);
        require(
            amount <= withdrawableAmount,
            "Withdrawal amount exceeds limit"
        );
        require(
            usdtToken.balanceOf(address(this)) >= amount,
            "Insufficient contract balance"
        );

        totalClaimAmount[msg.sender] += amount;
        usdtToken.safeTransfer(msg.sender, amount);
        usdtTreasury -= amount;

        emit ClaimFromTreasury(msg.sender, amount);
    }

    // function to calculate claimable amount for staker
    function calcClaimableAmount(address user) public view returns (uint256) {
        uint256 userStake = initalStakerApexAmount[user];
        uint256 treasuryBalance = accUsdtTreasury;

        uint256 totalWithdrawalLimit = (treasuryBalance * userStake) /
            totalStaked;
        uint256 withdrawableAmount = totalWithdrawalLimit -
            totalClaimAmount[user];

        return withdrawableAmount;
    }

    // function to emergency escape
    function forceExit(address to) public onlyOwner {
        require(
            apeXToken.balanceOf(address(this)) >= nonIssueApexTreasury,
            "Insufficient contract balance"
        );

        apeXToken.safeTransfer(to, nonIssueApexTreasury);

        emit ForceExit(to, nonIssueApexTreasury);

        apexTreasury -= nonIssueApexTreasury;
        nonIssueApexTreasury = 0;
        isInitalStakingAllowed = false;
    }
}
