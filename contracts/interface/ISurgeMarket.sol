// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Constants} from "../library/Constants.sol";

interface ISurgeMarket {
    struct Token {
        bytes32 token;
        address tokenAddress;
        uint48 settleTime;
        uint48 settleDuration;
        address pledgeToken;
        uint256 minPrice; // decimals 10_000_000
    }

    struct Config {
        address feeWallet;
        uint256 pledgeRate; // 1:1  BASE: 1_000_000_000_000_000_000
        uint256 settleRate; // 1:1  BASE: 1_000_000_000_000_000_000
        uint256 cancelRate; // 1:1  BASE: 1_000_000_000_000_000_000
        uint256 backoutRate; // 1:1  BASE: 1_000_000_000_000_000_000
        address signer;
    }

    event UpdateConfig(
        address newFeeWallet,
        uint256 newPledgeRate,
        uint256 newSettleRate,
        uint256 newFeeSettle,
        uint256 newFeeRefund,
        address newSigner
    );
}
