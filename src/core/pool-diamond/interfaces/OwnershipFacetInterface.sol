// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

interface OwnershipFacetInterface {
  function transferOwnership(address _newOwner) external;

  function owner() external view returns (address owner_);
}