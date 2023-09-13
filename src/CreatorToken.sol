// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract CreatorToken is ERC721 {
  using SafeERC20 for IERC20;

  error CreatorToken__MaxPaymentExceeded(uint256 _price, uint256 _maxPayment);

  uint256 public lastId;
  address public creator;
  IERC20 public payToken;

  event Bought(
    address indexed _payer,
    address indexed _receiver,
    uint256 indexed _tokenId,
    uint256 _paymentAmount
  );

  constructor(string memory _name, string memory _symbol, address _creator, IERC20 _payToken)
    ERC721(_name, _symbol)
  {
    creator = _creator;
    payToken = _payToken;
    _mintAndIncrement(_creator);
  }

  function buy(uint256 _maxPayment) public {
    _buy(msg.sender, _maxPayment);
  }

  function buy(address _to, uint256 _maxPayment) public {
    _buy(_to, _maxPayment);
  }

  function _buy(address _to, uint256 _maxPayment) internal {
    uint256 _price = _temporaryGetNextTokenPrice();
    if (_price > _maxPayment) revert CreatorToken__MaxPaymentExceeded(_price, _maxPayment);
    _mintAndIncrement(_to);
    emit Bought(msg.sender, _to, lastId, _price);
    payToken.safeTransferFrom(msg.sender, address(this), _price);
  }

  // Placeholder function for an eventual bonding curve function and/or contract
  function _temporaryGetNextTokenPrice() public pure returns (uint256) {
    return 1e18;
  }

  function _mintAndIncrement(address _to) private {
    lastId += 1;
    _mint(_to, lastId);
  }
}
