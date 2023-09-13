// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract CreatorToken is ERC721 {
  using SafeERC20 for IERC20;

  error CreatorToken__MaxPaymentExceeded(uint256 _price, uint256 _maxPayment);
  error CreatorToken__CallerIsNotCreator(address _creator, address _caller);
  error CreatorToken__CallerIsNotAdmin(address _admin, address _caller);
  error CreatorToken__AddressZeroNotAllowed();

  uint256 public lastId;
  address public creator;
  address public admin;
  IERC20 public payToken;

  uint256 constant BIP = 10_000;
  uint256 public constant CREATOR_FEE_BIPS = 700; // 7% in 4 decimals
  uint256 public constant ADMIN_FEE_BIPS = 300; // 3% in 4 decimals

  event Bought(
    address indexed _payer,
    address indexed _receiver,
    uint256 indexed _tokenId,
    uint256 _paymentAmount,
    uint256 _creatorFee,
    uint256 _adminFee
  );

  modifier isNotAddressZero(address _address) {
    if (_address == address(0)) revert CreatorToken__AddressZeroNotAllowed();
    _;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    address _creator,
    address _admin,
    IERC20 _payToken
  ) ERC721(_name, _symbol) {
    creator = _creator;
    admin = _admin;
    payToken = _payToken;
    _mintAndIncrement(_creator);
  }

  function buy(uint256 _maxPayment) public {
    _buy(msg.sender, _maxPayment);
  }

  function buy(address _to, uint256 _maxPayment) public {
    _buy(_to, _maxPayment);
  }

  function updateCreator(address _newCreator) public isNotAddressZero(_newCreator) {
    if (msg.sender != creator) revert CreatorToken__CallerIsNotCreator(creator, msg.sender);
    creator = _newCreator;
  }

  function updateAdmin(address _newAdmin) public isNotAddressZero(_newAdmin) {
    if (msg.sender != admin) revert CreatorToken__CallerIsNotAdmin(admin, msg.sender);
    admin = _newAdmin;
  }

  function _buy(address _to, uint256 _maxPayment) internal {
    uint256 _tokenPrice = _temporaryGetNextTokenPrice();
    (uint256 _creatorFee, uint256 _adminFee) = calculateFees(_tokenPrice);
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;

    if (_totalPrice > _maxPayment) {
      revert CreatorToken__MaxPaymentExceeded(_totalPrice, _maxPayment);
    }
    _mintAndIncrement(_to);
    emit Bought(msg.sender, _to, lastId, _tokenPrice, _creatorFee, _adminFee);
    payToken.safeTransferFrom(msg.sender, address(this), _tokenPrice);
    payToken.safeTransferFrom(msg.sender, creator, _creatorFee);
    payToken.safeTransferFrom(msg.sender, admin, _adminFee);
  }

  function calculateFees(uint256 _price)
    public
    pure
    returns (uint256 _creatorFee, uint256 _adminFee)
  {
    _creatorFee = (_price * CREATOR_FEE_BIPS) / BIP;
    _adminFee = (_price * ADMIN_FEE_BIPS) / BIP;
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
