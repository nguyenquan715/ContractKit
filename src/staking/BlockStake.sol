// SPDX-License-Identifier: MIT

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity 0.8.26;

contract BlockStake is Ownable {
    using SafeERC20 for IERC20;

    event Staked(
        address sender,
        uint256 amount,
        uint256 rewards,
        uint256 blockNumber
    );
    event Withdrawed(
        address sender,
        uint256 amount,
        uint256 rewards,
        uint256 blockNumber
    );

    IERC20 public immutable stakeToken;
    IERC20 public immutable rewardToken;

    uint256 public accumulatedRewardPerToken;
    uint256 public lastUpdatedBlock;
    uint256 public rewardPerBlock;
    uint256 public totalStakedAmount;

    mapping(address user => uint256 stakedAmount) public stakedAmountOfUsers;
    mapping(address user => uint256 debtAmount) public debtAmountOfUsers;

    constructor(
        address stakeToken_,
        address rewardToken_,
        uint256 rewardPerBlock_
    ) Ownable(msg.sender) {
        stakeToken = IERC20(stakeToken_);
        rewardToken = IERC20(rewardToken_);
        rewardPerBlock = rewardPerBlock_;
        lastUpdatedBlock = block.number;
    }

    function stake(uint256 amount_) external {
        address user = msg.sender;

        _updateAccumulatedReward();
        uint256 reward = _transferReward(user);

        totalStakedAmount += amount_;
        unchecked {
            stakedAmountOfUsers[user] += amount_;
        }
        debtAmountOfUsers[user] =
            (stakedAmountOfUsers[user] * accumulatedRewardPerToken) /
            1e18;

        stakeToken.safeTransferFrom(user, address(this), amount_);

        emit Staked(user, amount_, reward, block.number);
    }

    function withdraw(uint256 amount_) external {
        address user = msg.sender;
        require(amount_ <= stakedAmountOfUsers[user], "Invalid amount");

        _updateAccumulatedReward();
        uint256 reward = _transferReward(user);

        unchecked {
            totalStakedAmount -= amount_;
            stakedAmountOfUsers[user] -= amount_;
        }
        debtAmountOfUsers[user] =
            (stakedAmountOfUsers[user] * accumulatedRewardPerToken) /
            1e18;

        if (amount_ > 0) {
            stakeToken.safeTransfer(user, amount_);
        }

        emit Withdrawed(user, amount_, reward, block.number);
    }

    function _transferReward(address user_) internal returns (uint256 reward) {
        uint256 stakedAmount = stakedAmountOfUsers[user_];
        if (stakedAmount == 0) return 0;

        reward =
            (stakedAmount * accumulatedRewardPerToken) /
            1e18 -
            debtAmountOfUsers[user_];

        if (reward > 0) {
            debtAmountOfUsers[user_] = 0;
            rewardToken.safeTransfer(user_, reward);
        }
    }

    function _updateAccumulatedReward() internal {
        if (totalStakedAmount == 0) return;

        uint256 blockRange = block.number - lastUpdatedBlock;
        uint256 totalAccumulatedRewards = blockRange * rewardPerBlock;

        accumulatedRewardPerToken +=
            (totalAccumulatedRewards * 1e18) /
            totalStakedAmount;
        lastUpdatedBlock = block.number;
    }
}
