// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Constants} from "../library/Constants.sol";
import {ISurgeMarket} from "./ISurgeMarket.sol";

interface ISurgeMarketSettle is ISurgeMarket {
    event TokenListed(
        bytes32 token,
        address tokenAddress,
        uint48 settleTime,
        uint48 settleDuration,
        address pledgeToken
    );

    event SellerSettle(
        uint256 nonce,
        uint256 sellOrderid,
        bytes32 token,
        uint256 settleAmount,
        uint256 sellOrderValue,
        uint256[] buyOrderids,
        uint256[] buyerSettleAmounts
    );

    event BuyerSettle(
        uint256 nonce,
        address drawee,
        uint256 buyOrderid,
        bytes32 token,
        uint256 settleAmount,
        uint256 sellOrderValue,
        uint256[] sellOrderids,
        uint256[] sellSettleAmounts
    );
}
