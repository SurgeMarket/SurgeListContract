// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract Constants {
    enum OrderType {
        ORDER_BUY,
        ORDER_SELL
    }

    enum OrderTrade {
        TRADE_MARKET,
        TRADE_LIMIT
    }

    enum OrderTokenType {
        DEFULT_TOKEN,
        POINT_TOKEN
    }

    uint256 public constant BASERATE = 1_000_000_000_000_000_000;

    bytes32 public constant OPERATOR_ROLE_ADMIN =
        keccak256("OPERATOR_ROLE_ADMIN");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Signature
    string constant EIP712_DOMAIN_NAME = "SurgeMarket";
    string constant EIP712_DOMAIN_VERSION = "1.0.0";

    // Signature for list of orders
    bytes32 constant EIP712_ORDER_CANCEL =
        keccak256(
            "CancelOrder(uint256 nonce,uint256 orderid,uint256 amount,bool createNewOrder,uint256 newOrderAmount)"
        );
    bytes32 constant EIP712_ORDER_SETTLE =
        keccak256(
            "SettleOrder(uint256 nonce,uint256 sellOrderid,uint256 sellerLevel,uint256 sellerReferralLevel,uint256 settleAmount,uint256[] buyOrderids,uint256[] buyerSettleAmounts,uint256[] buyerLevels)"
        );
    bytes32 constant EIP712_ORDER_BACKOUT =
        keccak256(
            "BackoutOrder(uint256 nonce,uint256 orderid,uint256 amount,uint256[] sellOrderids,uint256[] sellerSettleAmounts)"
        );

    // Signature for settle order
    bytes32 constant EIP712_ORDER_TOKENSETTLE_SELLER =
        keccak256(
            "SellerSettleToken(uint256 nonce,uint256 sellOrderid,bytes32 token,uint256 settleAmount,uint256 sellOrderValue,uint256[] buyOrderids,uint256[] buyerSettleAmounts)"
        );
    bytes32 constant EIP712_ORDER_TOKENSETTLE_BUYER =
        keccak256(
            "BuyerSettleToken(uint256 nonce,address drawee,uint256 buyOrderid,bytes32 token,uint256 settleAmount,uint256 buyOrderValue,uint256[] sellOrderids,uint256[] sellerSettleAmounts)"
        );
}
