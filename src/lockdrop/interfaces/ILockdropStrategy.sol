// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

interface ILockdropStrategy {
  function simpleStrategyExecute(uint256 _tokenAmount, address _tokenAddress)
    external
    returns (uint256);
}
