// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

abstract contract TestUtils {
  function encodeError(string memory error)
    internal
    pure
    returns (bytes memory encoded)
    {
      encoded = abi.encodeWithSignature(error);
    }
}