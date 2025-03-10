// SPDX-License-Identifier: MIT

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity 0.8.26;

contract TimeStake is Ownable {
  using SafeERC20 for IERC20;

  event Staked(address user, uint256 amount, uint256 timestamp);
  event Unstaked(address user, uint256 amount, uint256 timestamp);
  event Withdrawed(address user, uint256 amount, uint256 timestamp);
  event RewardDeposited(uint256 amount, uint256 timestamp);

  IERC20 public immutable stakeToken;
  IERC20 public immutable rewardToken;

  uint256 totalStakedAmount;
  uint256 accumulatedRewardPerToken;
  uint256 rewardPerSecond;
  uint256 lastUpdatedTime;

  mapping(address user => uint256 stakedAmount) stakedAmountOfUsers;
  mapping(address user => uint256 rewardDebtPerToken) rewardDebtPerTokenOfUsers;
  mapping(address user => uint256 rewardAmount) rewardAmountOfUsers;

  constructor(address stakeToken_, address rewardToken_, uint256 rewardRate_) Ownable(msg.sender) {
    stakeToken = IERC20(stakeToken_);
    rewardToken = IERC20(rewardToken_);
    rewardPerSecond = rewardRate_;
    lastUpdatedTime = block.timestamp;
  }

  function stake(uint256 amount) external {
    address user = msg.sender;

    _updateAccumulatedReward();
    _calculateReward(user);

    totalStakedAmount += amount;
    unchecked {
      stakedAmountOfUsers[user] += amount;
    }

    stakeToken.safeTransferFrom(user, address(this), amount);

    emit Staked(user, amount, block.timestamp);
  }

  function unstake(uint256 amount) external {
    address user = msg.sender;
    require(amount <= stakedAmountOfUsers[user], "");

    _updateAccumulatedReward();
    _calculateReward(user);

    unchecked {
      totalStakedAmount -= amount;
      stakedAmountOfUsers[user] -= amount;
    }

    stakeToken.safeTransfer(user, amount);

    emit Unstaked(user, amount, block.timestamp);
  }

  function withdrawReward() external {
    address user = msg.sender;

    _updateAccumulatedReward();
    _calculateReward(user);

    uint256 reward = rewardAmountOfUsers[user];
    rewardAmountOfUsers[user] = 0;

    rewardToken.safeTransfer(user, reward);

    emit Withdrawed(user, reward, block.timestamp);
  }

  function depositReward(uint256 amount) external onlyOwner {
    _updateAccumulatedReward();

    rewardToken.safeTransferFrom(msg.sender, address(this), amount);

    emit RewardDeposited(amount, block.timestamp);
  }

  function _updateAccumulatedReward() external {
    if (totalStakedAmount == 0) return; 
    uint256 timeElapsed = block.timestamp - lastUpdatedTime;
    uint256 totalReward = timeElapsed * rewardPerSecond;
    accumulatedRewardPerToken += (totalReward * 1e18) / totalStakedAmount;
    lastUpdatedTime = block.timestamp; 
  }

  function _calculateReward(address user) internal {
    uint256 reward = stakedAmountOfUsers[user] * (accumulatedRewardPerToken - rewardDebtPerTokenOfUsers[user]) / 1e18;
    rewardAmountOfUsers[user] += reward;
    rewardDebtPerTokenOfUsers[user] = accumulatedRewardPerToken;
  }
}