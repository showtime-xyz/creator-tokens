// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice The interface a contract must implement to function as a bonding curve for a
/// CreatorToken contract.
interface IBondingCurve {
  /// @notice View method that returns the price to purchase the Nth token as derived by a given
  /// bonding curve implementation.
  /// @param _tokenNumber The Nth token for which we want to derive the price to buy or sell.
  /// @return _price The price of the Nth token as derived by the bonding curve implementation.
  /// @dev It is assumed that the number returned is deterministic, and will not vary over time.
  /// A bonding curve that returned different values, given the same argument for `_tokenNumber`,
  /// would break a critical invariant of the CreatorToken contract.
  function priceForTokenNumber(uint256 _tokenNumber) external view returns (uint256 _price);
}
