// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

interface OwnershipFacetInterface {
  function transferOwnership(address _newOwner) external;

  function owner() external view returns (address owner_);
}
