// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Constants} from "../library/Constants.sol";
import {ECDSA} from "../library/ECDSA.sol";
import {EIP712} from "../library/EIP712.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISurgeMarketSettle} from "../interface/ISurgeMarketSettle.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SurgeMarketSettle is
    Pausable,
    ISurgeMarketSettle,
    Constants,
    ReentrancyGuard,
    EIP712,
    Ownable,
    AccessControl
{
    using SafeERC20 for IERC20;
    bool private initialized;

    // token name string -> bytes32
    mapping(bytes32 => Token) public tokenInfos;

    // system config
    Config public config;

    mapping(uint256 => bool) public txNonce;

    function initialize() external {
        require(!initialized, "initialize: Already initialized!");
        _transferOwnership(0x518dB679e81A82b57f0e1220Cf27A7e9098087d9);
        eip712Initialize(EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION);
        _setRoleAdmin(OPERATOR_ROLE, OPERATOR_ROLE_ADMIN);
        _setupRole(
            OPERATOR_ROLE_ADMIN,
            0x518dB679e81A82b57f0e1220Cf27A7e9098087d9
        );
        _setupRole(OPERATOR_ROLE, 0xA4fce399AcDE70A9a96AF387B96A1125D2E99F5C);

        config.feeWallet = 0x518dB679e81A82b57f0e1220Cf27A7e9098087d9;
        config.pledgeRate = 1000000000000000000;
        config.settleRate = 25000000000000000;
        config.cancelRate = 5000000000000000;
        config.backoutRate = 25000000000000000;
        config.signer = 0x444643ec2e47E68b2e81e7cc58F5A7290336E045;

        initialized = true;
    }

    ///////////////////////////
    ////// SYSTEM ACTION //////
    //////// OPERATOR /////////
    ///////////////////////////
    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    function updateConfig(
        address _feeWallet,
        uint256 _pledgeRate,
        uint256 _settleRate,
        uint256 _cancelRate,
        uint256 _backoutRate,
        address _signer
    ) external onlyRole(OPERATOR_ROLE) {
        require(_feeWallet != address(0), "Invalid Fee Wallet");
        require(_cancelRate > 0, "Invalid Cancel Rate");
        require(_backoutRate > 0, "Invalid Backout Rate");
        require(_settleRate > 0, "Invalid Settle Rate");
        require(_signer != address(0), "Invalid Signer");
        config.feeWallet = _feeWallet;
        config.pledgeRate = _pledgeRate;
        config.settleRate = _settleRate;
        config.cancelRate = _cancelRate;
        config.backoutRate = _backoutRate;
        config.signer = _signer;
        emit UpdateConfig(
            _feeWallet,
            _pledgeRate,
            _settleRate,
            _cancelRate,
            _backoutRate,
            _signer
        );
    }

    function listToken(
        bytes32 token,
        address tokenAddress,
        uint48 settleTime,
        uint48 settleDuration,
        address pledgeToken
    ) external onlyRole(OPERATOR_ROLE) {
        require(token != bytes32(0), "Invalid Token Id");
        require(tokenAddress != address(0), "Invalid Token Address");
        require(settleDuration >= 24 * 60 * 60, "Invalid Settle Duration");

        Token memory tokenInfo;
        tokenInfo.token = token;
        tokenInfo.tokenAddress = tokenAddress;
        tokenInfo.settleTime = settleTime;
        tokenInfo.settleDuration = settleDuration;
        tokenInfo.pledgeToken = pledgeToken;

        tokenInfos[token] = tokenInfo;
        emit TokenListed(
            token,
            tokenAddress,
            settleTime,
            settleDuration,
            pledgeToken
        );
    }

    /////////////////////////
    ////// USER ACTION //////
    // USER OR FORCEOP  /////
    /////////////////////////
    function sellerSettle(
        uint256 nonce,
        uint256 sellOrderid,
        bytes32 token,
        uint256 settleAmount,
        uint256 sellOrderValue,
        uint256[] calldata buyOrderids,
        uint256[] calldata buyerSettleAmounts,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant returns (bool) {
        require(!txNonce[nonce], "sellerSettle: Order already completed");
        require(
            verifySignature(
                sellerSettleOrderHash(
                    nonce,
                    sellOrderid,
                    token,
                    settleAmount,
                    sellOrderValue,
                    buyOrderids,
                    buyerSettleAmounts
                ),
                _signature
            ),
            "sellerSettle: Invalid signature"
        );
        Token memory tokenInfo = tokenInfos[token];
        // transfer tokenAddress
        IERC20(tokenInfo.tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            settleAmount
        );
        emit SellerSettle(
            nonce,
            sellOrderid,
            token,
            settleAmount,
            sellOrderValue,
            buyOrderids,
            buyerSettleAmounts
        );
        txNonce[nonce] = true;
        return true;
    }

    function buyerSettle(
        uint256 nonce,
        address drawee,
        uint256 buyerOrderid,
        bytes32 token,
        uint256 settleAmount,
        uint256 buyerOrderValue,
        uint256[] calldata sellerOrderids,
        uint256[] calldata sellerSettleAmounts,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant {
        require(!txNonce[nonce], "buyerSettle: Order already completed");
        txNonce[nonce] = true;
        require(
            verifySignature(
                buyerSettleOrderHash(
                    nonce,
                    drawee,
                    buyerOrderid,
                    token,
                    settleAmount,
                    buyerOrderValue,
                    sellerOrderids,
                    sellerSettleAmounts
                ),
                _signature
            ),
            "buyerSettle: Invalid signature"
        );

        // withdraw tokenAddress
        uint256 settleFee = (settleAmount * config.settleRate) / BASERATE;
        uint256 withdrawSettleAmount = settleAmount - settleFee;
        Token memory tokenInfo = tokenInfos[token];
        IERC20(tokenInfo.tokenAddress).safeTransfer(
            drawee,
            withdrawSettleAmount
        );
        IERC20(tokenInfo.tokenAddress).safeTransfer(
            config.feeWallet,
            settleFee
        );

        emit BuyerSettle(
            nonce,
            drawee,
            buyerOrderid,
            token,
            settleAmount,
            buyerOrderValue,
            sellerOrderids,
            sellerSettleAmounts
        );
    }

    // internal function
    function verifySignature(
        bytes32 hash,
        bytes calldata signature
    ) internal view returns (bool) {
        return ECDSA.recover(hash, signature) == config.signer;
    }

    function sellerSettleOrderHash(
        uint256 nonce,
        uint256 sellOrderid,
        bytes32 token,
        uint256 settleAmount,
        uint256 sellOrderValue,
        uint256[] calldata buyOrderids,
        uint256[] calldata buyerSettleAmounts
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        EIP712_ORDER_TOKENSETTLE_SELLER,
                        nonce,
                        sellOrderid,
                        token,
                        settleAmount,
                        sellOrderValue,
                        keccak256(abi.encodePacked(buyOrderids)),
                        keccak256(abi.encodePacked(buyerSettleAmounts))
                    )
                )
            );
    }

    function buyerSettleOrderHash(
        uint256 nonce,
        address drawee,
        uint256 buyerOrderid,
        bytes32 token,
        uint256 settleAmount,
        uint256 buyerOrderValue,
        uint256[] calldata sellerOrderids,
        uint256[] calldata sellerSettleAmounts
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        EIP712_ORDER_TOKENSETTLE_BUYER,
                        nonce,
                        drawee,
                        buyerOrderid,
                        token,
                        settleAmount,
                        buyerOrderValue,
                        keccak256(abi.encodePacked(sellerOrderids)),
                        keccak256(abi.encodePacked(sellerSettleAmounts))
                    )
                )
            );
    }
}
