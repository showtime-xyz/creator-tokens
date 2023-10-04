// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IShowtimeVerifier, SignedAttestation, Attestation} from "src/lib/IShowtimeVerifier.sol";

/// @dev Implement a mock showtime verifier whose only purpose is to return `false` from its
/// `verify` family of methods. The existing showtime verifier onchain, which we use for most
/// tests, does not actually return `false` for any code paths. Therefore, to test that we correctly
/// check the return value and revert in our factory if verification fails, we use this mock.
contract MockFailingVerifier is IShowtimeVerifier {
  function nonces(address) external pure returns (uint256) {
    return 0;
  }

  function verify(SignedAttestation calldata) external pure returns (bool) {
    return false;
  }

  function verifyAndBurn(SignedAttestation calldata) external pure returns (bool) {
    return false;
  }

  function verify(Attestation calldata, bytes32, bytes memory, bytes calldata)
    external
    pure
    returns (bool)
  {
    return false;
  }

  function verifyAndBurn(Attestation calldata, bytes32, bytes memory, bytes calldata)
    external
    pure
    returns (bool)
  {
    return false;
  }

  function setManager(address) external pure {
    revert("Not implemented by mock");
  }

  function registerSigner(address, uint256) external pure returns (uint256) {
    revert("Not implemented by mock");
  }

  function revokeSigner(address) external pure {
    revert("Not implemented by mock");
  }

  function registerAndRevoke(address, address, uint256) external pure returns (uint256) {
    revert("Not implemented by mock");
  }
}
