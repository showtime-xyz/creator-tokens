// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IShowtimeVerifier, Attestation} from "src/lib/IShowtimeVerifier.sol";

// We define this interface to extend the vendored verifier interface used in the
// core contracts to expose some methods that do exist on the showtime contract, but
// aren't defined on that interface. These are only needed as part of testing.
interface ITestableShowTimeVerifier is IShowtimeVerifier {
  function owner() external view returns (address);
  function signerValidity(address signer) external view returns (uint256);
  function encode(Attestation memory attestation) external pure returns (bytes memory);
  function REQUEST_TYPE_HASH() external view returns (bytes32);
  function domainSeparator() external view returns (bytes32);
  function nonces(address) external view returns (uint256);
}
