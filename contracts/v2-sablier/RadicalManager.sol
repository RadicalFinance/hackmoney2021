// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./PatronageToken.sol";

import { IERC1620 } from "./external/IERC1620.sol";
import { StreamManager } from "./StreamManager.sol";
import { IRadicalToken } from "./IRadicalToken.sol";

// DONE: Mint patronage token
// DONE: Register radical token + link to patronage token
// DONE: Deposit patronage for radical token
// TODO: Withdraw patronage for radical token
// DONE: Collect patronage for patronage token
// DONE: Liquidate radical token
// DONE: Update price
// DONE: Force buy
// TODO: Transfer patronage token causes stream update

// Out of scope
// TODO: Regular transfers should settle existing streams
// TODO: Gas efficiency
// TODO: Customisable grace period
// TODO: Ensure robustness against vulnerabilities (eg reentrancy)
// TODO: Accept multiple tokens

contract RadicalManager is StreamManager {
    using Counters for Counters.Counter;

    struct RadicalTokenInfo {
        address tokenAddress;
        uint256 tokenId;
        uint256 patronageId;
        uint256 price;
        uint256 gracePeriodEnd;
        uint256 streamId;
    }

    struct RadicalTokenIdentifier {
        address tokenAddress;
        uint256 tokenId;
    }

    event Registered(address indexed tokenAddress, uint256 indexed tokenId, uint256 indexed patronageId, uint256 initialPrice);
    event Sold(address indexed from, address indexed to, address indexed tokenAddress, uint256 tokenId, uint256 price);

    // TODO: More events
    // event RentDeposited(address indexed depositor, uint256 indexed tokenId, uint256 amount);
    // event RentWithdrawn(address indexed withdrawer, uint256 indexed tokenId, uint256 amount);
    // event RentCollected(address indexed collector, uint256 indexed tokenId, uint256 amount);
    // event PriceChanged(address indexed owner, uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);

    Counters.Counter private _patronageTokenIds;
    PatronageToken public patronageTokenContract;

    uint256 private _maxRadicalTokensPerPatronageToken = 1;

    // tokenAddress => tokenId => RadicalTokenInfo
    mapping (address => mapping (uint256 => RadicalTokenInfo)) public radicalTokens;
    mapping (uint256 => RadicalTokenIdentifier[]) public radicalTokensForPatronageTokenId;

    constructor(
        IERC1620 _sablier,
        IERC20 _acceptedToken
    ) StreamManager(_sablier, _acceptedToken) {
        patronageTokenContract = new PatronageToken();
    }

    // VIEW FUNCTIONS
    function priceOf(address tokenAddress, uint256 tokenId) public view returns (uint256) {
        return radicalTokens[tokenAddress][tokenId].price;
    }

    function checkCanBeLiquidated(address tokenAddress, uint256 tokenId) public view {
        RadicalTokenInfo memory info = radicalTokens[tokenAddress][tokenId];
        require(info.tokenAddress != address(0), "RadicalManager: Token does not exist");
        require(block.timestamp >= info.gracePeriodEnd, "RadicalManager: Cannot liquidate token during grace period");
        require(!_isStreamActive(info.streamId), "RadicalManager: Cannot liquidate token while it has an active stream");
    }

    function register(address tokenAddress, uint256 tokenId, uint256 patronageId, uint256 price) public {
        require(tokenAddress == msg.sender, "RadicalManager: Only the token address can register its own tokens");
        require(
            radicalTokensForPatronageTokenId[patronageId].length < _maxRadicalTokensPerPatronageToken,
            "RadicalManager: Provided patronage token has too many linked radical tokens"
        );

        require(radicalTokens[tokenAddress][tokenId].tokenAddress == address(0), "RadicalManager: Radical token already registered");
        require(patronageTokenContract.ownerOf(patronageId) != address(0), "RadicalManager: Specified patronage token does not exist");

        uint256 gracePeriodEnd = block.timestamp + 8 hours;

        radicalTokens[tokenAddress][tokenId] = RadicalTokenInfo(tokenAddress, tokenId, patronageId, price, gracePeriodEnd, 0);
        radicalTokensForPatronageTokenId[patronageId].push(RadicalTokenIdentifier(tokenAddress, tokenId));

        emit Registered(tokenAddress, tokenId, patronageId, price);
    }

    function setPrice(address tokenAddress, uint256 tokenId, uint256 price) public {
        radicalTokens[tokenAddress][tokenId].price = price;
        uint256 newRate = getPaymentPerSecondFor(tokenAddress, tokenId);
        _updateStreamRate(radicalTokens[tokenAddress][tokenId].streamId, newRate);
    }

    function forceBuy(address tokenAddress, uint256 tokenId) public {
        _removeStream(radicalTokens[tokenAddress][tokenId].streamId);
        radicalTokens[tokenAddress][tokenId].streamId = 0;

        address from = IERC721(tokenAddress).ownerOf(tokenId);
        address to = msg.sender;
        uint256 price = radicalTokens[tokenAddress][tokenId].price;

        acceptedToken.transferFrom(to, from, price);
        IRadicalToken(tokenAddress).forceTransfer(to, tokenId);

        emit Sold(from, to, tokenAddress, tokenId, price);
    }

    function mintNewPatronageToken(address to, uint256 patronageRate) public returns (uint256) {
        _patronageTokenIds.increment();
        uint256 tokenId = _patronageTokenIds.current();
        patronageTokenContract.mint(to, tokenId, patronageRate);
        return tokenId;
    }

    function makeDepositFor(address tokenAddress, uint256 tokenId, uint256 deposit) public {
        RadicalTokenInfo memory info = radicalTokens[tokenAddress][tokenId];
        address streamReceiver = patronageTokenContract.ownerOf(info.patronageId);

        if (info.streamId == 0) {
            uint256 paymentPerSecond = getPaymentPerSecondFor(tokenAddress, tokenId);
            uint256 stopTime = deposit / paymentPerSecond;
            uint256 streamId = _createStream(msg.sender, streamReceiver, deposit, stopTime);
            radicalTokens[tokenAddress][tokenId].streamId = streamId;
        } else {
            _depositToStream(info.streamId, deposit);
        }
    }

    function liquidate(address tokenAddress, uint256 tokenId) public {
        RadicalTokenInfo memory info = radicalTokens[tokenAddress][tokenId];
        checkCanBeLiquidated(tokenAddress, tokenId);
        _closeStreamAndRefund(info.streamId);

        address patronageOwner = patronageTokenContract.ownerOf(info.patronageId);
        IRadicalToken(tokenAddress).forceTransfer(patronageOwner, tokenId);
        radicalTokens[tokenAddress][tokenId].streamId = 0;
    }

    function collectPatronage(uint256 patronageId) public {
        RadicalTokenIdentifier[] memory linkedRadicalTokenIdentifiers = radicalTokensForPatronageTokenId[patronageId];

        for (uint256 i = 0; i < linkedRadicalTokenIdentifiers.length; i++) {
            RadicalTokenIdentifier memory identifier = linkedRadicalTokenIdentifiers[i];
            _collectPatronageFor(identifier.tokenAddress, identifier.tokenId);
        }
    }

    function _collectPatronageFor(address tokenAddress, uint256 tokenId) internal {
        require(radicalTokens[tokenAddress][tokenId].tokenAddress != address(0), "RadicalManager: Token does not exist");
        require(radicalTokens[tokenAddress][tokenId].streamId != 0, "RadicalManager: Token does not have an active stream");
        _collectFromStream(radicalTokens[tokenAddress][tokenId].streamId);
    }

    // Utility functions
    function getPaymentPerSecondFor(address tokenAddress, uint256 tokenId) public view returns (uint256) {
        RadicalTokenInfo memory info = radicalTokens[tokenAddress][tokenId];
        uint256 ratePermille = patronageTokenContract.rateOf(info.patronageId);
        uint256 paymentPerSecond = info.price / ratePermille * 1000;
        return paymentPerSecond;
    }
}
