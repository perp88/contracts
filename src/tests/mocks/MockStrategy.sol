// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StrategyInterface } from "../../interfaces/StrategyInterface.sol";
import { MockDonateVault } from "./MockDonateVault.sol";

/// @title MockStrategy - For testing purpuse only. DO NOT USE IN PROD.
contract MockStrategy is StrategyInterface {
  address public token;
  MockDonateVault public vault;
  address public pool;

  modifier onlyPool() {
    require(msg.sender == pool, "MockStrategy: only pool");
    _;
  }

  constructor(
    address token_,
    MockDonateVault vault_,
    address pool_
  ) {
    token = token_;
    vault = vault_;
    pool = pool_;

    IERC20(token).approve(address(vault), type(uint256).max);
  }

  function run(
    uint256 /* amount */
  ) external onlyPool {
    // Deposit funds into vault
    vault.deposit(IERC20(token).balanceOf(address(this)));
  }

  function realized(uint256 principle, address sender)
    external
    onlyPool
    returns (int256 amountDelta)
  {
    (bool isProfit, uint256 amount) = getStrategyDelta(principle);
    if (isProfit) {
      vault.withdraw(vault.valueToShare(amount));
      IERC20(token).transfer(sender, amount);
      return int256(amount);
    } else {
      return -int256(amount);
    }
  }

  function withdraw(uint256 amount)
    external
    onlyPool
    returns (uint256 actualAmount)
  {
    vault.withdraw(vault.valueToShare(amount));
    actualAmount = IERC20(token).balanceOf(address(this));
    IERC20(token).transfer(msg.sender, actualAmount);

    return actualAmount;
  }

  function exit(uint256 principle)
    external
    onlyPool
    returns (int256 amountDelta)
  {
    // Calculate profit/losee
    (bool isProfit, uint256 uamountDelta) = getStrategyDelta(principle);

    // Withdraw all funds from vault
    vault.withdraw(vault.balanceOf(address(this)));

    // Transfer what left back to pool
    IERC20(token).transfer(pool, IERC20(token).balanceOf(address(this)));

    return isProfit ? int256(uamountDelta) : -int256(uamountDelta);
  }

  function getStrategyDelta(uint256 principle)
    public
    view
    returns (bool isProfit, uint256 amountDelta)
  {
    uint256 value = vault.shareToValue(vault.balanceOf(address(this)));
    if (value > principle) {
      return (true, value - principle);
    } else {
      return (false, principle - value);
    }
  }
}
