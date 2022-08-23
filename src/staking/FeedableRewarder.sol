pragma solidity 0.8.14;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IRewarder } from "./interfaces/IRewarder.sol";
import { IStaking } from "./interfaces/IStaking.sol";

contract FeedableRewarder is IRewarder, Ownable {
  using SafeCast for uint256;
  using SafeCast for uint128;
  using SafeCast for int256;
  using SafeERC20 for IERC20;

  string public name;
  address public rewardToken;
  address public staking;

  // user address => reward debt
  mapping(address => int256) public userRewardDebts;

  // Reward calculation parameters
  uint64 public lastRewardTime;
  uint128 public accRewardPerShare;
  uint256 public rewardRate;
  uint256 public rewardRateExpiredAt;
  uint256 private constant ACC_REWARD_PRECISION = 1e12;

  // Events
  event LogOnDeposit(address indexed user, uint256 shareAmount);
  event LogOnWithdraw(address indexed user, uint256 shareAmount);
  event LogHarvest(address indexed user, uint256 pendingRewardAmount);
  event LogUpdateRewardCalculationParams(
    uint64 lastRewardTime,
    uint256 accRewardPerShare
  );

  // Error
  error FeedableRewarderError_FeedAmountDecayed();
  error FeedableRewarderError_NotStakingContract();

  modifier onlyStakingContract() {
    if (msg.sender != staking)
      revert FeedableRewarderError_NotStakingContract();
    _;
  }

  constructor(
    string memory name_,
    address rewardToken_,
    address staking_
  ) {
    // Sanity check
    IERC20(rewardToken_).totalSupply();
    IStaking(staking_).isRewarder(address(this));

    name = name_;
    rewardToken = rewardToken_;
    staking = staking_;
    lastRewardTime = block.timestamp.toUint64();
  }

  function onDeposit(address user, uint256 shareAmount)
    external
    onlyStakingContract
  {
    _updateRewardCalculationParams();

    userRewardDebts[user] =
      userRewardDebts[user] +
      ((shareAmount * accRewardPerShare) / ACC_REWARD_PRECISION).toInt256();

    emit LogOnDeposit(user, shareAmount);
  }

  function onWithdraw(address user, uint256 shareAmount)
    external
    onlyStakingContract
  {
    _updateRewardCalculationParams();

    userRewardDebts[user] =
      userRewardDebts[user] -
      ((shareAmount * accRewardPerShare) / ACC_REWARD_PRECISION).toInt256();

    emit LogOnWithdraw(user, shareAmount);
  }

  function onHarvest(address user, address receiver)
    external
    onlyStakingContract
  {
    _updateRewardCalculationParams();

    int256 accumulatedRewards = ((_userShare(user) * accRewardPerShare) /
      ACC_REWARD_PRECISION).toInt256();
    uint256 pendingRewardAmount = (accumulatedRewards - userRewardDebts[user])
      .toUint256();

    userRewardDebts[user] = accumulatedRewards;

    if (pendingRewardAmount != 0) {
      _harvestToken(receiver, pendingRewardAmount);
    }

    emit LogHarvest(user, pendingRewardAmount);
  }

  function pendingReward(address user) external view returns (uint256) {
    uint256 projectedAccRewardPerShare = accRewardPerShare +
      _calculateAccRewardPerShare(_totalShare());
    int256 accumulatedRewards = ((_userShare(user) *
      projectedAccRewardPerShare) / ACC_REWARD_PRECISION).toInt256();

    if (accumulatedRewards < userRewardDebts[user]) return 0;
    return (accumulatedRewards - userRewardDebts[user]).toUint256();
  }

  function feed(uint256 feedAmount, uint256 duration) external onlyOwner {
    _feed(feedAmount, duration);
  }

  function feedWithExpiredAt(uint256 feedAmount, uint256 expiredAt)
    external
    onlyOwner
  {
    _feed(feedAmount, expiredAt - block.timestamp);
  }

  function _feed(uint256 feedAmount, uint256 duration) internal {
    _updateRewardCalculationParams();

    {
      // Transfer token, with decay check
      uint256 balanceBefore = IERC20(rewardToken).balanceOf(address(this));
      IERC20(rewardToken).safeTransferFrom(
        msg.sender,
        address(this),
        feedAmount
      );

      if (
        IERC20(rewardToken).balanceOf(address(this)) - balanceBefore !=
        feedAmount
      ) revert FeedableRewarderError_FeedAmountDecayed();
    }

    uint256 leftOverReward = rewardRateExpiredAt > block.timestamp
      ? (rewardRateExpiredAt - block.timestamp) * rewardRate
      : 0;
    uint256 totalRewardAmount = leftOverReward + feedAmount;

    rewardRate = totalRewardAmount / duration;
    rewardRateExpiredAt = block.timestamp + duration;
  }

  function _updateRewardCalculationParams() internal {
    uint256 totalShare = _totalShare();
    if (block.timestamp > lastRewardTime && totalShare > 0) {
      accRewardPerShare += _calculateAccRewardPerShare(totalShare);
      lastRewardTime = block.timestamp.toUint64();
      emit LogUpdateRewardCalculationParams(lastRewardTime, accRewardPerShare);
    }
  }

  function _calculateAccRewardPerShare(uint256 totalShare)
    internal
    view
    returns (uint128)
  {
    if (totalShare > 0) {
      uint256 _rewards = _timePast() * rewardRate;
      return ((_rewards * ACC_REWARD_PRECISION) / totalShare).toUint128();
    }
    return 0;
  }

  function _timePast() private view returns (uint256) {
    // Prevent timePast to go over intended reward distribution period.
    // On the other hand, prevent insufficient reward when harvest.
    if (block.timestamp < rewardRateExpiredAt) {
      return block.timestamp - lastRewardTime;
    } else if (rewardRateExpiredAt > lastRewardTime) {
      return rewardRateExpiredAt - lastRewardTime;
    } else {
      return 0;
    }
  }

  function _totalShare() private view returns (uint256) {
    return IStaking(staking).calculateTotalShare(address(this));
  }

  function _userShare(address user) private view returns (uint256) {
    return IStaking(staking).calculateShare(address(this), user);
  }

  function _harvestToken(address receiver, uint256 pendingRewardAmount)
    internal
    virtual
  {
    IERC20(rewardToken).safeTransfer(receiver, pendingRewardAmount);
  }
}