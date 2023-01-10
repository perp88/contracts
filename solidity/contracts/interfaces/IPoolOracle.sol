// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

interface IPoolOracle {
  function getMaxPrice(address token) external returns (uint256);

  function getMinPrice(address token) external returns (uint256);

  function getPrice(
    address token,
    bool isUseMaxPrice
  ) external returns (uint256);
}
