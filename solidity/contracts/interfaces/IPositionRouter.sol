// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IPositionRouter {
  function increasePositionRequestKeysStart() external returns (uint256);

  function decreasePositionRequestKeysStart() external returns (uint256);

  function swapOrderRequestKeysStart() external returns (uint256);

  function executeIncreasePositions(
    uint256 _endIndex,
    address payable _executionFeeReceiver
  ) external;

  function executeDecreasePositions(
    uint256 _endIndex,
    address payable _executionFeeReceiver
  ) external;

  function executeSwapOrders(
    uint256 _endIndex,
    address payable _executionFeeReceiver
  ) external;
}
