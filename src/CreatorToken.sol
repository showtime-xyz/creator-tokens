// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IBondingCurve} from "src/interfaces/IBondingCurve.sol";

contract CreatorToken is ERC721 {
  using SafeERC20 for IERC20;

  error CreatorToken__MaxFeeExceeded(uint256 fee, uint256 maxFee);
  error CreatorToken__MaxPaymentExceeded(uint256 price, uint256 maxPayment);
  error CreatorToken__Unauthorized(bytes32 reason, address caller);
  error CreatorToken__AddressZeroNotAllowed();
  error CreatorToken__CallerIsNotOwner(uint256 tokenId, address owner, address caller);
  error CreatorToken__MinAcceptedPriceExceeded(uint256 price, uint256 minAcceptedPrice);
  error CreatorToken__LastTokensCannotBeSold(uint256 circulatingSupply);
  error CreatorToken__ContractIsPaused();

  uint256 public lastId;
  uint256 public totalSupply;
  address public creator;
  address public admin;
  address public immutable REFERRER;
  bool public isPaused;
  string private creatorTokenURI;
  IERC20 public payToken;
  IBondingCurve public immutable BONDING_CURVE;

  uint256 constant BIP = 10_000;
  uint256 public immutable CREATOR_FEE_BIPS;
  uint256 public immutable ADMIN_FEE_BIPS;
  uint256 private constant MAX_FEE = 2500; // 25% in bips

  event Bought(
    address indexed payer,
    address indexed receiver,
    uint256 indexed tokenId,
    uint256 paymentAmount,
    uint256 creatorFee,
    uint256 adminFee
  );
  event Sold(
    address indexed seller,
    uint256 indexed tokenId,
    uint256 salePrice,
    uint256 creatorFee,
    uint256 adminFee
  );
  event ToggledPause(bool oldPauseState, bool newPauseState, address caller);
  event CreatorUpdated(address oldCreator, address newCreator);
  event AdminUpdated(address oldAdmin, address newAdmin);
  event TokenURIUpdated(string oldTokenURI, string newTokenURI);

  modifier isNotAddressZero(address _address) {
    if (_address == address(0)) revert CreatorToken__AddressZeroNotAllowed();
    _;
  }

  modifier onlyCreatorOrAdmin(address _caller) {
    if (_caller != creator && _caller != admin) {
      revert CreatorToken__Unauthorized("not creator or admin", _caller);
    }
    _;
  }

  modifier whenNotPaused() {
    if (isPaused) revert CreatorToken__ContractIsPaused();
    _;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _tokenURI,
    address _creator,
    uint256 _creatorFee,
    address _admin,
    uint256 _adminFee,
    address _referrer,
    IERC20 _payToken,
    IBondingCurve _bondingCurve
  ) ERC721(_name, _symbol) isNotAddressZero(_creator) isNotAddressZero(_admin) {
    if (_creatorFee > MAX_FEE) revert CreatorToken__MaxFeeExceeded(_creatorFee, MAX_FEE);
    if (_adminFee > MAX_FEE) revert CreatorToken__MaxFeeExceeded(_adminFee, MAX_FEE);

    creatorTokenURI = _tokenURI;
    creator = _creator;
    CREATOR_FEE_BIPS = _creatorFee;
    admin = _admin;
    ADMIN_FEE_BIPS = _adminFee;
    REFERRER = _referrer;
    payToken = _payToken;
    BONDING_CURVE = _bondingCurve;
    _mintAndIncrement(_creator);

    if (_referrer != address(0)) _mintAndIncrement(_referrer);
  }

  function buy(uint256 _maxPayment) public {
    _buy(msg.sender, _maxPayment);
  }

  function buy(address _to, uint256 _maxPayment) public {
    _buy(_to, _maxPayment);
  }

  function sell(uint256 _tokenId) public {
    _sell(_tokenId, 0); // TODO: consider how to test this is curried correctly
  }

  function sell(uint256 _tokenId, uint256 _minAcceptedPrice) public {
    _sell(_tokenId, _minAcceptedPrice);
  }

  function updateCreator(address _newCreator) public isNotAddressZero(_newCreator) {
    if (msg.sender != creator) revert CreatorToken__Unauthorized("not creator", msg.sender);
    creator = _newCreator;
    emit CreatorUpdated(msg.sender, _newCreator);
  }

  function updateAdmin(address _newAdmin) public isNotAddressZero(_newAdmin) {
    if (msg.sender != admin) revert CreatorToken__Unauthorized("not admin", msg.sender);
    admin = _newAdmin;
    emit AdminUpdated(msg.sender, _newAdmin);
  }

  function tokenURI(uint256) public view override returns (string memory) {
    return creatorTokenURI;
  }

  function updateTokenURI(string memory _newTokenURI) public onlyCreatorOrAdmin(msg.sender) {
    emit TokenURIUpdated(creatorTokenURI, _newTokenURI);
    creatorTokenURI = _newTokenURI;
  }

  function _buy(address _to, uint256 _maxPayment) internal whenNotPaused {
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = nextBuyPrice();
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

  function _sell(uint256 _tokenId, uint256 _minAcceptedPrice) internal whenNotPaused {
    if (msg.sender != ownerOf(_tokenId)) {
      revert CreatorToken__CallerIsNotOwner(_tokenId, ownerOf(_tokenId), msg.sender);
    }

    bool _isOneOfLastTokens =
      (REFERRER == address(0) && totalSupply == 1) || (REFERRER != address(0) && totalSupply == 2);
    if (_isOneOfLastTokens) revert CreatorToken__LastTokensCannotBeSold(totalSupply);

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = nextSellPrice();
    uint256 _netProceeds = _tokenPrice - _creatorFee - _adminFee;

    if (_netProceeds < _minAcceptedPrice) {
      revert CreatorToken__MinAcceptedPriceExceeded(_netProceeds, _minAcceptedPrice);
    }

    transferFrom(msg.sender, address(this), _tokenId);
    _burnAndDecrement(_tokenId);
    emit Sold(msg.sender, _tokenId, _tokenPrice, _creatorFee, _adminFee);

    payToken.safeTransfer(creator, _creatorFee);
    payToken.safeTransfer(msg.sender, _netProceeds);
    payToken.safeTransfer(admin, _adminFee);
  }

  function pause(bool _pauseState) public onlyCreatorOrAdmin(msg.sender) {
    emit ToggledPause(isPaused, _pauseState, msg.sender);
    isPaused = _pauseState;
  }

  function nextBuyPrice()
    public
    view
    returns (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee)
  {
    _tokenPrice = BONDING_CURVE.priceForTokenNumber((totalSupply + 1) - _preMintOffset());
    (_creatorFee, _adminFee) = calculateFees(_tokenPrice);
  }

  function nextSellPrice()
    public
    view
    returns (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee)
  {
    _tokenPrice = BONDING_CURVE.priceForTokenNumber(totalSupply - _preMintOffset());
    (_creatorFee, _adminFee) = calculateFees(_tokenPrice);
  }

  function calculateFees(uint256 _price)
    public
    view
    returns (uint256 _creatorFee, uint256 _adminFee)
  {
    _creatorFee = (_price * CREATOR_FEE_BIPS) / BIP;
    _adminFee = (_price * ADMIN_FEE_BIPS) / BIP;
  }

  function _preMintOffset() private view returns (uint256 _offset) {
    _offset = REFERRER == address(0) ? 1 : 2;
  }

  function _mintAndIncrement(address _to) private {
    lastId += 1;
    _mint(_to, lastId);
    totalSupply += 1;
  }

  function _burnAndDecrement(uint256 _tokenId) private {
    _burn(_tokenId);
    totalSupply -= 1;
  }
}
