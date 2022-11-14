// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

interface ILZReceiver {
  function lzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes calldata _payload
  ) external;
}
