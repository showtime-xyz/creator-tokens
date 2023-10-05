// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CreatorToken, IBondingCurve} from "src/CreatorToken.sol";
import {IERC20, ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC165} from "openzeppelin/interfaces/IERC165.sol";
import {MockIncrementingBondingCurve} from "test/mocks/MockIncrementingBondingCurve.sol";

abstract contract CreatorTokenTest is Test {
  IERC20 public payToken;
  IBondingCurve public bondingCurve;
  CreatorToken public creatorToken;
  address public creator = address(0xc2ea702);
  address public admin = address(0xb055);
  address public referrer;

  string CREATOR_TOKEN_NAME = "Test Token";
  string CREATOR_TOKEN_SYMBOL = "TEST";
  string CREATOR_TOKEN_URI = "URI";

  string PAY_TOKEN_NAME = "Payment Token";
  string PAY_TOKEN_SYMBOL = "PAY";
  uint256 BASE_PAY_AMOUNT = 1e18; // Because our test token has 18 decimals
  uint256 creatorFee;
  uint96 creatorRoyalty;
  uint256 adminFee;
  uint256 constant MAX_FEE = 2500; // matches private variable in CreatorToken

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

  function setUp() public {
    (address _referrer, uint256 _creatorFee, uint96 _creatorRoyalty, uint256 _adminFee) =
      deployConfig();
    referrer = _referrer;
    creatorFee = _creatorFee;
    creatorRoyalty = _creatorRoyalty;
    adminFee = _adminFee;
    payToken = new ERC20(PAY_TOKEN_NAME, PAY_TOKEN_SYMBOL);
    bondingCurve = new MockIncrementingBondingCurve(BASE_PAY_AMOUNT);
    creatorToken =
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, CREATOR_TOKEN_URI, creator, creatorFee, creatorRoyalty, admin, adminFee, referrer, payToken, bondingCurve);
  }

  function _assumeSafeBuyer(address _buyer) public view {
    vm.assume(
      _buyer != address(0) && _buyer != address(creatorToken) && _buyer != creator
        && _buyer != admin && _buyer != referrer
    );
  }

  function deployConfig()
    internal
    pure
    virtual
    returns (address referrer, uint256 creatorFee, uint96 creatorRoyalty, uint256 adminFee);

  function buyAToken(address _buyer) public {
    _assumeSafeBuyer(_buyer);
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalBuyerBalanceOfCreatorTokens = creatorToken.balanceOf(_buyer);
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();
    uint256 _originalPayTokenBalanceOfCreator = payToken.balanceOf(creator);
    uint256 _originalPayTokenBalanceOfAdmin = payToken.balanceOf(admin);
    deal(address(payToken), _buyer, _totalPrice);
    uint256 _originalPayTokenBalanceOfBuyer = payToken.balanceOf(_buyer);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    creatorToken.buy(_totalPrice);
    vm.stopPrank();

    assertEq(
      creatorToken.balanceOf(_buyer),
      _originalBuyerBalanceOfCreatorTokens + 1,
      "buyAToken: Buyer balance of creator tokens mismatch"
    );
    assertEq(
      creatorToken.ownerOf(creatorToken.lastId()), _buyer, "buyAToken: Buyer is not owner of token"
    );
    assertEq(
      payToken.balanceOf(address(creatorToken)),
      _originalPayTokenBalanceOfCreatorTokenContract + _tokenPrice,
      "buyAToken: Creator token contract balance mismatch"
    );
    assertEq(
      payToken.balanceOf(_buyer),
      _originalPayTokenBalanceOfBuyer - _totalPrice,
      "buyAToken: Buyer pay token balance mismatch"
    );
    assertEq(
      creatorToken.totalSupply(),
      _originalCreatorTokenSupply + 1,
      "buyAToken: Creator token supply mismatch"
    );
    assertEq(
      payToken.balanceOf(creator),
      _originalPayTokenBalanceOfCreator + _creatorFee,
      "buyAToken: Creator balance mismatch"
    );
    assertEq(
      payToken.balanceOf(admin),
      _originalPayTokenBalanceOfAdmin + _adminFee,
      "buyAToken: Admin balance mismatch"
    );
  }

  function sellAToken(address _seller, uint256 _tokenId) public {
    require(
      creatorToken.ownerOf(_tokenId) == _seller,
      "Broken test invariant: seller does not own the token to sell."
    );
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();
    uint256 _netProceeds = _tokenPrice - _creatorFee - _adminFee;
    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalPayTokenBalanceOfSeller = payToken.balanceOf(_seller);
    uint256 _originalSellerBalanceOfCreatorTokens = creatorToken.balanceOf(_seller);
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();
    uint256 _originalPayTokenBalanceOfCreator = payToken.balanceOf(creator);
    uint256 _originalPayTokenBalanceOfAdmin = payToken.balanceOf(admin);

    vm.startPrank(_seller);
    creatorToken.approve(address(creatorToken), _tokenId);
    creatorToken.sell(_tokenId, _netProceeds);
    vm.stopPrank();

    assertEq(creatorToken.balanceOf(_seller), _originalSellerBalanceOfCreatorTokens - 1);
    assertEq(
      payToken.balanceOf(address(creatorToken)),
      _originalPayTokenBalanceOfCreatorTokenContract - _tokenPrice
    );
    assertEq(payToken.balanceOf(_seller), _originalPayTokenBalanceOfSeller + _netProceeds);
    assertEq(creatorToken.totalSupply(), _originalCreatorTokenSupply - 1);
    assertEq(payToken.balanceOf(creator), _originalPayTokenBalanceOfCreator + _creatorFee);
    assertEq(payToken.balanceOf(admin), _originalPayTokenBalanceOfAdmin + _adminFee);
  }
}

abstract contract Deployment is CreatorTokenTest {
  function test_TokenIsConfiguredAtDeployment() public {
    assertEq(creatorToken.name(), CREATOR_TOKEN_NAME);
    assertEq(creatorToken.symbol(), CREATOR_TOKEN_SYMBOL);
    assertEq(creatorToken.tokenURI(1), CREATOR_TOKEN_URI);
    assertEq(creatorToken.creator(), creator);
    assertEq(creatorToken.CREATOR_FEE_BIPS(), creatorFee);
    assertEq(creatorToken.CREATOR_ROYALTY_BIPS(), creatorRoyalty);
    assertEq(creatorToken.admin(), admin);
    assertEq(creatorToken.ADMIN_FEE_BIPS(), adminFee);
    assertEq(creatorToken.REFERRER(), referrer);
    assertEq(address(creatorToken.payToken()), address(payToken));
    assertEq(address(creatorToken.BONDING_CURVE()), address(bondingCurve));
  }

  function test_RevertIf_TokenIsConfiguredWithZeroAddressAsCreator() public {
    CreatorToken _creatorTokenInstance;
    address _creatorZeroAddress = address(0);
    vm.expectRevert(CreatorToken.CreatorToken__AddressZeroNotAllowed.selector);
    _creatorTokenInstance =
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, CREATOR_TOKEN_URI, _creatorZeroAddress, creatorFee, creatorRoyalty, admin, adminFee, referrer, payToken, bondingCurve);
  }

  function test_RevertIf_TokenIsConfiguredWithZeroAddressAsAdmin() public {
    CreatorToken _creatorTokenInstance;
    address _adminZeroAddress = address(0);
    vm.expectRevert(CreatorToken.CreatorToken__AddressZeroNotAllowed.selector);
    _creatorTokenInstance =
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, CREATOR_TOKEN_URI, creator, creatorFee, creatorRoyalty, _adminZeroAddress, adminFee, referrer, payToken, bondingCurve);
  }

  function test_RevertIf_CreatorFeeExceedsMaxFee(uint256 _creatorFee) public {
    _creatorFee = bound(_creatorFee, MAX_FEE + 1, type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__MaxFeeExceeded.selector, _creatorFee, MAX_FEE
      )
    );
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, CREATOR_TOKEN_URI, creator, _creatorFee, creatorRoyalty, admin, adminFee, referrer, payToken, bondingCurve);
  }

  function test_RevertIf_AdminFeeExceedsMaxFee(uint256 _adminFee) public {
    _adminFee = bound(_adminFee, MAX_FEE + 1, type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(CreatorToken.CreatorToken__MaxFeeExceeded.selector, _adminFee, MAX_FEE)
    );
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, CREATOR_TOKEN_URI, creator, creatorFee, creatorRoyalty, admin, _adminFee, referrer, payToken, bondingCurve);
  }

  function test_FirstTokensAreMintedCorrectly() public {
    bool _isThereAReferrer = referrer != address(0);

    assertEq(creatorToken.balanceOf(creator), 1);
    assertEq(creatorToken.ownerOf(1), creator);

    if (_isThereAReferrer) {
      assertEq(creatorToken.balanceOf(referrer), 1);
      assertEq(creatorToken.ownerOf(2), referrer);
    }
  }
}

abstract contract Buying is CreatorTokenTest {
  function test_FirstTokenOnBondingCurveCostsTheBasePrice() public {
    (uint256 _tokenPrice,,) = creatorToken.nextBuyPrice();
    assertEq(_tokenPrice, BASE_PAY_AMOUNT);
  }

  function test_BuyAToken(address _buyer) public {
    buyAToken(_buyer);
  }

  function test_BuyWithReceiverAddress(address _buyer, address _to) public {
    _assumeSafeBuyer(_buyer);
    vm.assume(_to != address(0) && _to != address(creatorToken));
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();
    uint256 _originalReceiverBalanceOfCreatorTokens = creatorToken.balanceOf(_to);

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    creatorToken.buy(_to, _totalPrice);
    vm.stopPrank();

    assertEq(creatorToken.balanceOf(_to), _originalReceiverBalanceOfCreatorTokens + 1);
    assertEq(creatorToken.totalSupply(), _originalCreatorTokenSupply + 1);
    assertEq(payToken.balanceOf(_buyer), 0);
    assertEq(payToken.balanceOf(address(creatorToken)), _tokenPrice);
    assertEq(payToken.balanceOf(creatorToken.creator()), _creatorFee);
    assertEq(payToken.balanceOf(creatorToken.admin()), _adminFee);
  }

  function test_EmitsBoughtEvent(address _buyer) public {
    vm.assume(_buyer != address(0) && _buyer != address(creatorToken));

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    vm.expectEmit(true, true, true, true);
    emit Bought(_buyer, _buyer, creatorToken.lastId() + 1, _tokenPrice, _creatorFee, _adminFee);
    creatorToken.buy(_totalPrice);
    vm.stopPrank();
  }

  function test_BulkBuy(address _buyer, uint256 _numTokensToBuy) public {
    _assumeSafeBuyer(_buyer);
    _numTokensToBuy = bound(_numTokensToBuy, 1, 100);

    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalBuyerBalanceOfCreatorTokens = creatorToken.balanceOf(_buyer);
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();
    uint256 _originalPayTokenBalanceOfBuyer = payToken.balanceOf(_buyer);
    uint256 _originalPayTokenBalanceOfCreator = payToken.balanceOf(creator);
    uint256 _originalPayTokenBalanceOfAdmin = payToken.balanceOf(admin);

    uint256 _expectedPayTokenAddedToContract;
    uint256 _expectedTotalPricePaidByBuyer;
    uint256 _expectedPayTokenEarnedByCreator;
    uint256 _expectedPayTokenEarnedByAdmin;

    uint256 _preMintOffset = referrer == address(0) ? 1 : 2;

    for (uint256 _i = 1; _i <= _numTokensToBuy; _i++) {
      // Determine the total expected payment by asking the bonding curve for token price and
      // calculating the fees manually.
      (uint256 _tokenPrice) =
        bondingCurve.priceForTokenNumber((creatorToken.totalSupply() + _i) - _preMintOffset);
      (uint256 _creatorFee, uint256 _adminFee) = creatorToken.calculateFees(_tokenPrice);
      uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
      _expectedPayTokenAddedToContract += _tokenPrice;
      _expectedTotalPricePaidByBuyer += _totalPrice;
      _expectedPayTokenEarnedByCreator += _creatorFee;
      _expectedPayTokenEarnedByAdmin += _adminFee;
    }

    deal(address(payToken), _buyer, _expectedTotalPricePaidByBuyer);
    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    creatorToken.bulkBuy(_numTokensToBuy, _expectedTotalPricePaidByBuyer);
    vm.stopPrank();

    for (uint256 _i; _i < _numTokensToBuy; _i++) {
      assertEq(creatorToken.ownerOf(creatorToken.lastId() - _i), _buyer);
    }
    assertEq(creatorToken.balanceOf(_buyer), _originalBuyerBalanceOfCreatorTokens + _numTokensToBuy);
    assertEq(
      payToken.balanceOf(address(creatorToken)),
      _originalPayTokenBalanceOfCreatorTokenContract + _expectedPayTokenAddedToContract
    );
    assertEq(payToken.balanceOf(_buyer), _originalPayTokenBalanceOfBuyer);
    assertEq(creatorToken.totalSupply(), _originalCreatorTokenSupply + _numTokensToBuy);
    assertEq(
      payToken.balanceOf(creator),
      _originalPayTokenBalanceOfCreator + _expectedPayTokenEarnedByCreator
    );
    assertEq(
      payToken.balanceOf(admin), _originalPayTokenBalanceOfAdmin + _expectedPayTokenEarnedByAdmin
    );
  }

  function test_BulkBuyWithReceiverAddress(
    address _buyer,
    address _receiver,
    uint256 _numTokensToBuy
  ) public {
    _assumeSafeBuyer(_buyer);
    _assumeSafeBuyer(_receiver);
    vm.assume(_receiver != _buyer);
    _numTokensToBuy = bound(_numTokensToBuy, 1, 100);

    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalBuyerBalanceOfCreatorTokens = creatorToken.balanceOf(_buyer);
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();
    uint256 _originalPayTokenBalanceOfBuyer = payToken.balanceOf(_buyer);
    uint256 _originalPayTokenBalanceOfCreator = payToken.balanceOf(creator);
    uint256 _originalPayTokenBalanceOfAdmin = payToken.balanceOf(admin);

    uint256 _expectedPayTokenAddedToContract;
    uint256 _expectedTotalPricePaidByBuyer;
    uint256 _expectedPayTokenEarnedByCreator;
    uint256 _expectedPayTokenEarnedByAdmin;

    for (uint256 _i = 1; _i <= _numTokensToBuy; _i++) {
      // Determine the total expected payment by asking the bonding curve for token price and
      // calculating the fees manually.
      (uint256 _tokenPrice) = bondingCurve.priceForTokenNumber(
        (creatorToken.totalSupply() + _i) - (referrer == address(0) ? 1 : 2)
      );
      (uint256 _creatorFee, uint256 _adminFee) = creatorToken.calculateFees(_tokenPrice);
      uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
      _expectedPayTokenAddedToContract += _tokenPrice;
      _expectedTotalPricePaidByBuyer += _totalPrice;
      _expectedPayTokenEarnedByCreator += _creatorFee;
      _expectedPayTokenEarnedByAdmin += _adminFee;
    }

    deal(address(payToken), _buyer, _expectedTotalPricePaidByBuyer);
    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    creatorToken.bulkBuy(_receiver, _numTokensToBuy, _expectedTotalPricePaidByBuyer);
    vm.stopPrank();

    for (uint256 _i; _i < _numTokensToBuy; _i++) {
      assertEq(creatorToken.ownerOf(creatorToken.lastId() - _i), _receiver);
    }
    assertEq(
      creatorToken.balanceOf(_receiver), _originalBuyerBalanceOfCreatorTokens + _numTokensToBuy
    );
    assertEq(
      payToken.balanceOf(address(creatorToken)),
      _originalPayTokenBalanceOfCreatorTokenContract + _expectedPayTokenAddedToContract
    );
    assertEq(payToken.balanceOf(_buyer), _originalPayTokenBalanceOfBuyer);
    assertEq(creatorToken.totalSupply(), _originalCreatorTokenSupply + _numTokensToBuy);
    assertEq(
      payToken.balanceOf(creator),
      _originalPayTokenBalanceOfCreator + _expectedPayTokenEarnedByCreator
    );
    assertEq(
      payToken.balanceOf(admin), _originalPayTokenBalanceOfAdmin + _expectedPayTokenEarnedByAdmin
    );
  }

  function test_RevertIf_PriceExceedsMaxPayment(address _buyer, uint256 _maxPayment) public {
    vm.assume(_buyer != address(0) && _buyer != address(creatorToken));

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    _maxPayment = bound(_maxPayment, 0, _totalPrice - 1);
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__MaxPaymentExceeded.selector, _totalPrice, _maxPayment
      )
    );
    creatorToken.buy(_maxPayment);
    vm.stopPrank();
  }

  function test_RevertIf_BulkBuyPriceExceedsMaxPayment(address _buyer, uint256 _numTokensToBuy)
    public
  {
    _assumeSafeBuyer(_buyer);
    _numTokensToBuy = bound(_numTokensToBuy, 1, 100);

    uint256 _expectedTotalPricePaidByBuyer;
    uint256 _preMintOffset = referrer == address(0) ? 1 : 2;

    for (uint256 _i = 1; _i <= _numTokensToBuy; _i++) {
      (uint256 _tokenPrice) =
        bondingCurve.priceForTokenNumber((creatorToken.totalSupply() + _i) - _preMintOffset);
      (uint256 _creatorFee, uint256 _adminFee) = creatorToken.calculateFees(_tokenPrice);
      uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
      _expectedTotalPricePaidByBuyer += _totalPrice;
    }

    deal(address(payToken), _buyer, _expectedTotalPricePaidByBuyer);
    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__MaxPaymentExceeded.selector,
        _expectedTotalPricePaidByBuyer,
        _expectedTotalPricePaidByBuyer - 1
      )
    );
    creatorToken.bulkBuy(_numTokensToBuy, _expectedTotalPricePaidByBuyer - 1);
    vm.stopPrank();
  }
}

abstract contract Selling is CreatorTokenTest {
  function test_SellAToken(address _seller) public {
    buyAToken(_seller);
    sellAToken(_seller, creatorToken.lastId());
  }

  function test_BulkSell(address _seller, uint256 _numTokensToBuyAndSell) public {
    _assumeSafeBuyer(_seller);
    _numTokensToBuyAndSell = bound(_numTokensToBuyAndSell, 1, 100);
    uint256[] memory _tokenIds = new uint256[](_numTokensToBuyAndSell);

    uint256 _originalCreatorTokenBalanceOfSeller = creatorToken.balanceOf(_seller);
    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();
    uint256 _expectedNetProceeds;
    uint256 _expectedPayTokenToBeEarnedByCreator;
    uint256 _expectedPayTokenToBeEarnedByAdmin;

    // buy n tokens
    for (uint256 _i = 0; _i < _numTokensToBuyAndSell; _i++) {
      buyAToken(_seller);
      (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();
      _expectedNetProceeds += (_tokenPrice - _creatorFee - _adminFee);
      _expectedPayTokenToBeEarnedByCreator += _creatorFee;
      _expectedPayTokenToBeEarnedByAdmin += _adminFee;
      _tokenIds[_i] = (creatorToken.lastId());
    }
    require(
      creatorToken.balanceOf(_seller) == _numTokensToBuyAndSell,
      "Broken test invariant: seller does not own correct number of tokens to sell."
    );
    uint256 _originalPayTokenBalanceOfSeller = payToken.balanceOf(_seller);
    uint256 _originalPayTokenBalanceOfCreator = payToken.balanceOf(creator);
    uint256 _originalPayTokenBalanceOfAdmin = payToken.balanceOf(admin);

    vm.prank(_seller);
    (uint256 _netProceeds) = creatorToken.bulkSell(_tokenIds);

    assertEq(creatorToken.balanceOf(_seller), _originalCreatorTokenBalanceOfSeller);
    assertEq(
      payToken.balanceOf(address(creatorToken)), _originalPayTokenBalanceOfCreatorTokenContract
    );
    assertEq(creatorToken.totalSupply(), _originalCreatorTokenSupply);

    assertEq(_netProceeds, _expectedNetProceeds);
    assertEq(payToken.balanceOf(_seller), _originalPayTokenBalanceOfSeller + _expectedNetProceeds);
    assertEq(
      payToken.balanceOf(creator),
      _originalPayTokenBalanceOfCreator + _expectedPayTokenToBeEarnedByCreator
    );
    assertEq(
      payToken.balanceOf(admin),
      _originalPayTokenBalanceOfAdmin + _expectedPayTokenToBeEarnedByAdmin
    );
  }

  function test_BulkSellAfterOthersBuyAndSell(
    address _seller,
    address _secondSeller,
    uint256 _numTokensToBuyAndSell
  ) public {
    _assumeSafeBuyer(_seller);
    _assumeSafeBuyer(_secondSeller);
    vm.assume(_seller != _secondSeller);
    _numTokensToBuyAndSell = bound(_numTokensToBuyAndSell, 1, 100);
    uint256[] memory _tokenIds = new uint256[](_numTokensToBuyAndSell);

    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();
    uint256 _expectedNetProceeds;

    // buy n tokens
    for (uint256 _i = 0; _i < _numTokensToBuyAndSell; _i++) {
      buyAToken(_seller);
      (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();
      _expectedNetProceeds += _tokenPrice - _creatorFee - _adminFee;

      _tokenIds[_i] = (creatorToken.lastId());

      // _secondSeller buys and sells a token
      buyAToken(_secondSeller);
      sellAToken(_secondSeller, creatorToken.lastId());
    }

    require(creatorToken.balanceOf(_seller) == _numTokensToBuyAndSell);

    vm.prank(_seller);
    (uint256 _netProceeds) = creatorToken.bulkSell(_tokenIds);

    assertEq(
      payToken.balanceOf(address(creatorToken)), _originalPayTokenBalanceOfCreatorTokenContract
    );
    assertEq(creatorToken.totalSupply(), _originalCreatorTokenSupply);
    assertEq(
      _netProceeds,
      _expectedNetProceeds,
      "test_BulkSellAfterOthersBuyAndSell: Net proceeds mismatch"
    );
  }

  function test_LastTokenOnBondingCurveCostsTheBasePrice(address _seller) public {
    buyAToken(_seller);

    (uint256 _tokenPrice,,) = creatorToken.nextSellPrice();
    assertEq(_tokenPrice, BASE_PAY_AMOUNT);
  }

  function test_EmitsSoldEvent(address _seller) public {
    buyAToken(_seller);

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();
    uint256 _netProceeds = _tokenPrice - _creatorFee - _adminFee;

    vm.startPrank(_seller);
    creatorToken.approve(address(creatorToken), creatorToken.lastId());
    vm.expectEmit(true, true, true, true);
    emit Sold(_seller, creatorToken.lastId(), _tokenPrice, _creatorFee, _adminFee);
    creatorToken.sell(creatorToken.lastId(), _netProceeds);
    vm.stopPrank();
  }

  function test_RevertIf_BulkSellMinAcceptedPriceExceeded(
    address _seller,
    uint256 _numTokensToBuyAndSell
  ) public {
    _assumeSafeBuyer(_seller);
    _numTokensToBuyAndSell = bound(_numTokensToBuyAndSell, 1, 100);
    uint256[] memory _tokenIds = new uint256[](_numTokensToBuyAndSell);
    uint256 _expectedNetProceeds;

    // buy n tokens
    for (uint256 _i = 0; _i < _numTokensToBuyAndSell; _i++) {
      buyAToken(_seller);
      (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();
      _expectedNetProceeds += _tokenPrice - _creatorFee - _adminFee;
      _tokenIds[_i] = (creatorToken.lastId());
    }
    require(creatorToken.balanceOf(_seller) == _numTokensToBuyAndSell);

    vm.prank(_seller);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__MinAcceptedPriceExceeded.selector,
        _expectedNetProceeds,
        _expectedNetProceeds + 1
      )
    );
    creatorToken.bulkSell(_tokenIds, _expectedNetProceeds + 1);
  }

  function test_RevertIf_MinAcceptedPriceIsHigherThanNetProceeds(
    address _seller,
    uint256 _minAcceptedPrice
  ) public {
    buyAToken(_seller);
    assertEq(creatorToken.ownerOf(creatorToken.lastId()), _seller);
    assertEq(payToken.balanceOf(_seller), 0);

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();
    uint256 _netProceeds = _tokenPrice - _creatorFee - _adminFee;
    _minAcceptedPrice = bound(_minAcceptedPrice, _netProceeds + 1, type(uint256).max);
    uint256 _tokenId = creatorToken.lastId();

    vm.startPrank(_seller);
    creatorToken.approve(address(creatorToken), creatorToken.lastId());
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__MinAcceptedPriceExceeded.selector,
        _netProceeds,
        _minAcceptedPrice
      )
    );
    creatorToken.sell(_tokenId, _minAcceptedPrice);
    vm.stopPrank();
  }

  function test_RevertIf_SellerIsNotTokenOwner(address _owner, address _seller) public {
    vm.assume(_owner != _seller);
    _assumeSafeBuyer(_seller);

    buyAToken(_owner);
    uint256 _tokenId = creatorToken.lastId();

    vm.startPrank(_seller);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__CallerIsNotOwner.selector, creatorToken.lastId(), _owner, _seller
      )
    );
    creatorToken.sell(_tokenId);
    vm.stopPrank();
  }

  function test_RevertIf_OneOfLastTokensIsBeingSold() public {
    bool _isThereAReferrer = referrer != address(0);
    address _seller = _isThereAReferrer ? referrer : creator;

    require(
      creatorToken.ownerOf(creatorToken.lastId()) == _seller,
      "Test invariant violated: creator or seller should be owner of last token"
    );

    uint256 _tokenId = creatorToken.lastId();

    vm.startPrank(_seller);
    creatorToken.approve(address(creatorToken), _tokenId);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__LastTokensCannotBeSold.selector, creatorToken.totalSupply()
      )
    );
    creatorToken.sell(_tokenId);
    vm.stopPrank();
  }
}

abstract contract UpdatingCreatorAndAdminAddresses is CreatorTokenTest {
  function test_UpdateCreatorAddress(address _newCreator, address _secondNewCreator) public {
    vm.assume(_newCreator != address(0) && _newCreator != creator);
    vm.assume(_secondNewCreator != address(0) && _secondNewCreator != _newCreator);

    vm.prank(creator);
    vm.expectEmit(true, true, true, true);
    emit CreatorUpdated(creator, _newCreator);
    creatorToken.updateCreator(_newCreator);
    assertEq(creatorToken.creator(), _newCreator);

    vm.prank(_newCreator);
    vm.expectEmit(true, true, true, true);
    emit CreatorUpdated(_newCreator, _secondNewCreator);
    creatorToken.updateCreator(_secondNewCreator);
    assertEq(creatorToken.creator(), _secondNewCreator);
  }

  function test_RevertIf_NewCreatorAddressIsZero() public {
    address _newCreator = address(0);

    vm.prank(creator);
    vm.expectRevert(CreatorToken.CreatorToken__AddressZeroNotAllowed.selector);
    creatorToken.updateCreator(_newCreator);
  }

  function test_RevertIf_CallerIsNotCreator(address _caller, address _newCreator) public {
    vm.assume(_caller != address(0) && _caller != creator);
    vm.assume(_newCreator != address(0));

    vm.prank(_caller);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__Unauthorized.selector, bytes32("not creator"), _caller
      )
    );
    creatorToken.updateCreator(_newCreator);
  }

  function test_UpdateAdminAddress(address _newAdmin, address _secondNewAdmin) public {
    vm.assume(_newAdmin != address(0) && _newAdmin != admin);
    vm.assume(_secondNewAdmin != address(0) && _secondNewAdmin != _newAdmin);

    vm.prank(admin);
    vm.expectEmit(true, true, true, true);
    emit AdminUpdated(admin, _newAdmin);
    creatorToken.updateAdmin(_newAdmin);
    assertEq(creatorToken.admin(), _newAdmin);

    vm.prank(_newAdmin);
    vm.expectEmit(true, true, true, true);
    emit AdminUpdated(_newAdmin, _secondNewAdmin);
    creatorToken.updateAdmin(_secondNewAdmin);
    assertEq(creatorToken.admin(), _secondNewAdmin);
  }

  function test_RevertIf_NewAdminAddressIsZero() public {
    address _newAdmin = address(0);

    vm.prank(admin);
    vm.expectRevert(CreatorToken.CreatorToken__AddressZeroNotAllowed.selector);
    creatorToken.updateAdmin(_newAdmin);
  }

  function test_RevertIf_CallerIsNotAdmin(address _caller, address _newAdmin) public {
    vm.assume(_caller != address(0) && _caller != admin);
    vm.assume(_newAdmin != address(0));

    vm.prank(_caller);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__Unauthorized.selector, bytes32("not admin"), _caller
      )
    );
    creatorToken.updateAdmin(_newAdmin);
  }
}

abstract contract Pausing is CreatorTokenTest {
  function test_PauseContractCreator() public {
    vm.startPrank(creator);

    // Pause
    vm.expectEmit(true, true, true, true);
    emit ToggledPause(false, true, creator);
    creatorToken.pause(true);
    assertEq(creatorToken.isPaused(), true);

    // Unpause
    vm.expectEmit(true, true, true, true);
    emit ToggledPause(true, false, creator);
    creatorToken.pause(false);
    assertEq(creatorToken.isPaused(), false);

    vm.stopPrank();
  }

  function test_PauseContractAdmin() public {
    vm.startPrank(admin);

    // Pause
    vm.expectEmit(true, true, true, true);
    emit ToggledPause(false, true, admin);
    creatorToken.pause(true);
    assertEq(creatorToken.isPaused(), true);

    // Unpause
    vm.expectEmit(true, true, true, true);
    emit ToggledPause(true, false, admin);
    creatorToken.pause(false);
    assertEq(creatorToken.isPaused(), false);

    vm.stopPrank();
  }

  function test_RevertIf_CallerIsNotCreatorOrAdmin(address _caller, bool _pauseState) public {
    vm.assume(_caller != address(0) && _caller != creator && _caller != admin);

    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__Unauthorized.selector, bytes32("not creator or admin"), _caller
      )
    );
    vm.prank(_caller);
    creatorToken.pause(_pauseState);
  }

  function test_RevertIf_PausedAndBuyIsCalled(address _buyer) public {
    vm.prank(creator);
    creatorToken.pause(true);
    assertEq(creatorToken.isPaused(), true);

    _assumeSafeBuyer(_buyer);

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    vm.expectRevert(CreatorToken.CreatorToken__ContractIsPaused.selector);
    creatorToken.buy(_totalPrice);
    vm.stopPrank();
  }

  function test_RevertIf_PausedAndBuyIsCalled(address _buyer, address _receiver) public {
    vm.prank(creator);
    creatorToken.pause(true);
    assertEq(creatorToken.isPaused(), true);

    _assumeSafeBuyer(_buyer);

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    vm.expectRevert(CreatorToken.CreatorToken__ContractIsPaused.selector);
    creatorToken.buy(_receiver, _totalPrice);
    vm.stopPrank();
  }

  function test_RevertIf_PausedAndSellIsCalled(address _seller) public {
    buyAToken(_seller);

    // Pause
    vm.prank(creator);
    creatorToken.pause(true);

    // Try to sell the token
    vm.startPrank(_seller);
    creatorToken.approve(address(creatorToken), creatorToken.lastId());
    uint256 _tokenId = creatorToken.lastId();
    vm.expectRevert(CreatorToken.CreatorToken__ContractIsPaused.selector);
    creatorToken.sell(_tokenId);
    vm.stopPrank();
  }
}

abstract contract CreatorTokenFollowsBondingCurveContract is CreatorTokenTest {
  function test_BuyPriceIsCorrect(address _buyer, uint256 _numTokensToBuy) public {
    _numTokensToBuy = bound(_numTokensToBuy, 1, 100);

    for (uint256 _i = 0; _i < _numTokensToBuy; _i++) {
      (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();

      uint256 _preMintOffset = referrer == address(0) ? 1 : 2;
      uint256 _bondingCurveTokenPrice =
        bondingCurve.priceForTokenNumber((creatorToken.totalSupply() + 1) - _preMintOffset);
      (
        uint256 _creatorFeeCalculatedWithBondingCurveTokenPrice,
        uint256 _adminFeeCalculatedWithBondingCurveTokenPrice
      ) = creatorToken.calculateFees(_bondingCurveTokenPrice);

      assertEq(_tokenPrice, _bondingCurveTokenPrice);
      assertEq(_creatorFee, _creatorFeeCalculatedWithBondingCurveTokenPrice);
      assertEq(_adminFee, _adminFeeCalculatedWithBondingCurveTokenPrice);
      buyAToken(_buyer);
    }
  }

  function test_SellPriceIsCorrect(address _seller, uint256 _numTokensToBuyAndSell) public {
    _numTokensToBuyAndSell = bound(_numTokensToBuyAndSell, 1, 100);
    uint256[] memory _tokenIds = new uint256[](_numTokensToBuyAndSell);
    // buy n tokens
    for (uint256 _i = 0; _i < _numTokensToBuyAndSell; _i++) {
      buyAToken(_seller);
      _tokenIds[_i] = (creatorToken.lastId());
    }
    require(creatorToken.balanceOf(_seller) == _numTokensToBuyAndSell);

    // sell n tokens
    for (uint256 _i = 0; _i < _numTokensToBuyAndSell; _i++) {
      (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();

      uint256 _preMintOffset = referrer == address(0) ? 1 : 2;
      uint256 _bondingCurveTokenPrice =
        bondingCurve.priceForTokenNumber(creatorToken.totalSupply() - _preMintOffset);
      (
        uint256 _creatorFeeCalculatedWithBondingCurveTokenPrice,
        uint256 _adminFeeCalculatedWithBondingCurveTokenPrice
      ) = creatorToken.calculateFees(_bondingCurveTokenPrice);

      assertEq(_tokenPrice, _bondingCurveTokenPrice);
      assertEq(_creatorFee, _creatorFeeCalculatedWithBondingCurveTokenPrice);
      assertEq(_adminFee, _adminFeeCalculatedWithBondingCurveTokenPrice);
      sellAToken(_seller, _tokenIds[_i]);
    }
  }
}

abstract contract UpdatingBaseURI is CreatorTokenTest {
  function test_CreatorCanUpdateBaseURI() public {
    string memory _newBaseURI = "https://newURI.com/metadata/";
    vm.prank(creator);
    vm.expectEmit(true, true, true, true);
    emit TokenURIUpdated(CREATOR_TOKEN_URI, _newBaseURI);
    creatorToken.updateTokenURI(_newBaseURI);
    assertEq(creatorToken.tokenURI(1), _newBaseURI);
  }

  function test_AdminCanUpdateBaseURI() public {
    string memory _newBaseURI = "https://newURI.com/metadata/";
    vm.prank(admin);
    vm.expectEmit(true, true, true, true);
    emit TokenURIUpdated(CREATOR_TOKEN_URI, _newBaseURI);
    creatorToken.updateTokenURI(_newBaseURI);
    assertEq(creatorToken.tokenURI(1), _newBaseURI);
  }

  function test_RevertIf_CallerIsNotCreatorOrAdmin(address _caller) public {
    vm.assume(_caller != address(0) && _caller != creator && _caller != admin);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__Unauthorized.selector, bytes32("not creator or admin"), _caller
      )
    );
    vm.prank(_caller);
    creatorToken.updateTokenURI("updatedURI");
  }
}

abstract contract Royalty is CreatorTokenTest {
  function test_ContractSupportERC2981Interface() public {
    bytes4 _INTERFACE_ID_ERC2981 = 0x2a55205a;
    assertTrue(IERC165(creatorToken).supportsInterface(_INTERFACE_ID_ERC2981));
  }

  function test_RoyaltyInfo(uint256 _tokenId, uint256 _salePrice) public {
    _tokenId = bound(_tokenId, 0, 100_000);
    _salePrice = bound(_salePrice, 1, 10_000 ether);
    (address _royaltyReceiver, uint256 _royaltyAmount) =
      creatorToken.royaltyInfo(_tokenId, _salePrice);
    assertEq(_royaltyReceiver, creator);
    assertEq(_royaltyAmount, (_salePrice * creatorToken.CREATOR_ROYALTY_BIPS()) / 10_000);
  }

  function test_UpdateRoyaltyReceiverWhenCreatorIsUpdated(
    address _newCreator,
    address _secondNewCreator,
    uint256 _tokenId,
    uint256 _salePrice
  ) public {
    vm.assume(_newCreator != address(0) && _newCreator != creator);
    vm.assume(_secondNewCreator != address(0) && _secondNewCreator != _newCreator);
    _tokenId = bound(_tokenId, 0, 100_000);
    _salePrice = bound(_salePrice, 1, 10_000 ether);

    vm.prank(creator);
    creatorToken.updateCreator(_newCreator);
    assertEq(creatorToken.creator(), _newCreator);
    (address _royaltyReceiver,) = creatorToken.royaltyInfo(_tokenId, _salePrice);
    assertEq(_royaltyReceiver, _newCreator);

    vm.prank(_newCreator);
    creatorToken.updateCreator(_secondNewCreator);
    assertEq(creatorToken.creator(), _secondNewCreator);
    (address _secondRoyaltyReceiver,) = creatorToken.royaltyInfo(_tokenId, _salePrice);
    assertEq(_secondRoyaltyReceiver, _secondNewCreator);
  }

  function test_RevertIf_CreatorRoyaltyExceedsMaxFee(uint96 _creatorRoyalty) public {
    _creatorRoyalty = uint96(bound(_creatorRoyalty, MAX_FEE + 1, type(uint256).max));

    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__MaxFeeExceeded.selector, _creatorRoyalty, MAX_FEE
      )
    );
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, CREATOR_TOKEN_URI, creator, creatorFee, _creatorRoyalty, admin, adminFee, referrer, payToken, bondingCurve);
  }
}

contract ConfigWithReferrerAndStandardFees is
  Deployment,
  Buying,
  Selling,
  UpdatingCreatorAndAdminAddresses,
  Pausing,
  CreatorTokenFollowsBondingCurveContract,
  UpdatingBaseURI,
  Royalty
{
  function deployConfig()
    internal
    pure
    override
    returns (address referrer, uint256 creatorFee, uint96 creatorRoyalty, uint256 adminFee)
  {
    return (address(0xaceface), 700, 1000, 300);
  }
}

contract ConfigWithReferrerAndMaxFees is
  Deployment,
  Buying,
  Selling,
  UpdatingCreatorAndAdminAddresses,
  Pausing,
  CreatorTokenFollowsBondingCurveContract,
  UpdatingBaseURI,
  Royalty
{
  function deployConfig()
    internal
    pure
    override
    returns (address referrer, uint256 creatorFee, uint96 creatorRoyalty, uint256 adminFee)
  {
    return (address(0xaceface), 2500, 2500, 2500);
  }
}

contract ConfigWithReferrerAndZeroFees is
  Deployment,
  Buying,
  Selling,
  UpdatingCreatorAndAdminAddresses,
  Pausing,
  CreatorTokenFollowsBondingCurveContract,
  UpdatingBaseURI,
  Royalty
{
  function deployConfig()
    internal
    pure
    override
    returns (address referrer, uint256 creatorFee, uint96 creatorRoyalty, uint256 adminFee)
  {
    return (address(0xaceface), 0, 0, 0);
  }
}

contract ConfigWithoutReferrerAndStandardFees is
  Deployment,
  Buying,
  Selling,
  UpdatingCreatorAndAdminAddresses,
  Pausing,
  CreatorTokenFollowsBondingCurveContract,
  UpdatingBaseURI,
  Royalty
{
  function deployConfig()
    internal
    pure
    override
    returns (address referrer, uint256 creatorFee, uint96 creatorRoyalty, uint256 adminFee)
  {
    return (address(0), 700, 1000, 300);
  }
}

contract ConfigWithoutReferrerAndMaxFees is
  Deployment,
  Buying,
  Selling,
  UpdatingCreatorAndAdminAddresses,
  Pausing,
  CreatorTokenFollowsBondingCurveContract,
  UpdatingBaseURI,
  Royalty
{
  function deployConfig()
    internal
    pure
    override
    returns (address referrer, uint256 creatorFee, uint96 creatorRoyalty, uint256 adminFee)
  {
    return (address(0), 2500, 2500, 2500);
  }
}

contract ConfigWithoutReferrerAndZeroFees is
  Deployment,
  Buying,
  Selling,
  UpdatingCreatorAndAdminAddresses,
  Pausing,
  CreatorTokenFollowsBondingCurveContract,
  UpdatingBaseURI,
  Royalty
{
  function deployConfig()
    internal
    pure
    override
    returns (address referrer, uint256 creatorFee, uint96 creatorRoyalty, uint256 adminFee)
  {
    return (address(0), 0, 0, 0);
  }
}
