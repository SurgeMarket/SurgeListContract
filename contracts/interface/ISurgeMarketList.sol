// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Constants} from "../library/Constants.sol";
import {ISurgeMarket} from "./ISurgeMarket.sol";

interface ISurgeMarketList is ISurgeMarket {
    struct Order {
        uint256 orderId;
        address maker;
        Constants.OrderType orderType; // Buy or Sell
        Constants.OrderTrade tradeType; // Market or Limit
        Constants.OrderTokenType tokenType; // Token or Point
        bytes32 token;
        uint256 amount;
        address pledgeToken;
        uint256 value;
        uint256 filledAmount;
        uint256 settleAmount;
        uint256 cancelAmount;
        uint256 backoutAmount;
        address[] takers;
    }

    event TokenListed(
        bytes32 token,
        uint48 settleDuration,
        uint256 minPrice,
        address pledgeToken
    );

    event TokenToSettlePhase(
        bytes32 tokenId,
        address token,
        uint256 settleTime,
        uint256 settleDuration,
        uint256 minPrice
    );

    event UpdatePledgeTokens(address[] tokenAddresses);

    // order
    event CreateOrder(
        uint256 indexed orderId,
        address maker,
        Constants.OrderType orderType,
        Constants.OrderTrade tradeType,
        Constants.OrderTokenType tokenType,
        bytes32 token,
        uint256 amount,
        uint256 value
    );

    event CancelOrder(
        address indexed sender,
        uint256 indexed cancelOrderId,
        uint256 indexed cancelAmount,
        uint256 newOrderId,
        uint256 newOrderAmount,
        uint256 nonce
    );
    event SettleOrder(
        address indexed sender,
        uint256[] sellArg,
        uint256[][] buyArg
    );

    // uint256 nonce,
    // uint256 indexed backoutOrderId,
    // uint256 indexed backoutAmount,
    // args
    event BackoutOrder(
        address indexed sender,
        uint256[] args,
        uint256[] sellOrderids,
        uint256[] sellerSettleAmounts
    );
}
