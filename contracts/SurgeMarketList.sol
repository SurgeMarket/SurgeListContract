// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Constants} from "./library/Constants.sol";
import {ISurgeMarketList} from "./interface/ISurgeMarketList.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "./library/ECDSA.sol";
import {EIP712} from "./library/EIP712.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/ISurgeInvitation.sol";
import "./interface/ISurgeInvitationManager.sol";

contract SurgeMarketList is
    Pausable,
    Constants,
    ISurgeMarketList,
    AccessControl,
    Ownable,
    ReentrancyGuard,
    EIP712
{
    using SafeERC20 for IERC20;
    // Add the library methods
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    bool private initialized;

    // Declare a set state variable
    EnumerableSet.Bytes32Set private tokenSets;
    EnumerableSet.AddressSet private pledgeTokenSets;

    // token name string -> bytes32
    mapping(bytes32 => Token) public tokenInfos;

    uint256 public orderid;
    mapping(uint256 => Order) public orderInfos;

    mapping(uint256 => bool) public txNonce;

    // system config
    Config public config;

    ISurgeInvitation public surgeInvitation;
    ISurgeInvitationManager public surgeInvitationManager;

    function initialize(
        address _owner,
        ISurgeInvitation _surgeInvitation,
        ISurgeInvitationManager _surgeInvitationManager,
        Config memory _config
    ) external {
        require(!initialized, "initialize: Already initialized!");
        _transferOwnership(_owner);
        eip712Initialize(EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION);
        _setRoleAdmin(OPERATOR_ROLE, OPERATOR_ROLE_ADMIN);
        _setupRole(OPERATOR_ROLE_ADMIN, _owner);

        surgeInvitationManager = _surgeInvitationManager;
        surgeInvitation = _surgeInvitation;
        config = _config;
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

    function listToken(
        bytes32 token,
        uint48 settleDuration,
        uint256 minPrice,
        address pledgeToken
    ) external onlyRole(OPERATOR_ROLE) {
        require(token != bytes32(0), "Invalid Token Id");
        require(settleDuration >= 24 * 60 * 60, "Invalid Settle Duration");
        require(!tokenSets.contains(token), "Token Already Exists");
        require(pledgeTokenSets.contains(pledgeToken), "Invalid Pledge Token");
        tokenSets.add(token);

        Token memory tokenInfo;
        tokenInfo.settleDuration = settleDuration;
        tokenInfo.settleDuration = settleDuration;
        tokenInfo.pledgeToken = pledgeToken;
        tokenInfo.minPrice = minPrice;
        tokenInfos[token] = tokenInfo;
        emit TokenListed(token, settleDuration, minPrice, pledgeToken);
    }

    function tokenToSettlePhase(
        bytes32 tokenId,
        uint48 settleTime,
        uint48 settleDuration,
        uint256 minPrice,
        address tokenAddress
    ) external onlyRole(OPERATOR_ROLE) {
        require(tokenSets.contains(tokenId), "Token Not Exists");
        Token storage _token = tokenInfos[tokenId];
        require(tokenAddress != address(0), "Invalid Token Address");
        _token.tokenAddress = tokenAddress;
        _token.settleDuration = settleDuration;
        // update token settle status & time
        _token.settleTime = settleTime;
        _token.minPrice = minPrice;
        emit TokenToSettlePhase(
            tokenId,
            tokenAddress,
            settleTime,
            settleDuration,
            minPrice
        );
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

    function setPledgeTokens(
        address[] memory tokenAddresses
    ) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            pledgeTokenSets.add(tokenAddresses[i]);
        }
        emit UpdatePledgeTokens(tokenAddresses);
    }

    /////////////////////////
    ////// USER ACTION //////
    // USER OR FORCEOP  /////
    /////////////////////////
    function createOrder(
        bytes32 token,
        OrderType orderType,
        uint256 amount,
        uint256 value,
        OrderTrade tradeType,
        OrderTokenType tokenType,
        string memory _inviterCode
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(tokenSets.contains(token), "Token Not Exists");
        Token memory tokenInfo = tokenInfos[token];
        require(
            tokenInfo.minPrice <= (value * BASERATE) / amount,
            "price too low"
        );
        require(
            orderType == OrderType.ORDER_BUY ||
                orderType == OrderType.ORDER_SELL,
            "Invalid Offer Type"
        );

        require(
            tradeType == OrderTrade.TRADE_LIMIT ||
                tradeType == OrderTrade.TRADE_MARKET,
            "Invalid Offer Type"
        );
        require(value > 0, "Invalid Value");

        // set inviterCode
        surgeInvitation.createInvitation(msg.sender, _inviterCode);

        // stake pledgeToken
        IERC20(tokenInfo.pledgeToken).safeTransferFrom(
            msg.sender,
            address(this),
            value
        );

        orderid++;
        orderInfos[orderid] = Order({
            orderId: orderid,
            maker: msg.sender,
            orderType: orderType,
            tradeType: tradeType,
            tokenType: tokenType,
            token: token,
            amount: amount,
            pledgeToken: tokenInfo.pledgeToken,
            value: value,
            filledAmount: 0,
            settleAmount: 0,
            cancelAmount: 0,
            backoutAmount: 0,
            takers: new address[](0)
        });
        emit CreateOrder(
            orderid,
            msg.sender,
            orderType,
            tradeType,
            tokenType,
            token,
            amount,
            value
        );
        return orderid;
    }

    function cancelOrder(
        uint256 _orderid,
        uint256 _amount,
        bool _createNewOrder, // _amount < (amount - fillAmount)
        uint256 _newOrderAmount, // _newOrderAmount = amount - _amount - fillAmount
        uint256 nonce,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant {
        // _amount <= (order.amount - order.filledAmount)
        require(txNonce[nonce] == false, "cancelOrder: Order already end");

        Order storage order = orderInfos[_orderid];
        require(
            order.maker == msg.sender || hasRole(OPERATOR_ROLE, msg.sender),
            "Invalid Order Maker"
        );

        require(
            _amount > 0 &&
                _amount <=
                (order.amount -
                    order.settleAmount -
                    order.cancelAmount -
                    order.filledAmount -
                    order.backoutAmount),
            "Invalid Amount"
        );
        require(
            verifySignature(
                cancelOrderHash(
                    nonce,
                    _orderid,
                    _amount,
                    _createNewOrder,
                    _newOrderAmount
                ),
                _signature
            ),
            "Invalid Signature"
        );

        uint256 totalCancelValue = (_amount * order.value) / order.amount;
        uint256 cancelFee = (totalCancelValue * config.cancelRate) / BASERATE;
        uint256 refundValue = totalCancelValue - cancelFee;

        // withdraw pledgeToken
        IERC20(tokenInfos[order.token].pledgeToken).safeTransfer(
            config.feeWallet,
            cancelFee
        );
        IERC20(tokenInfos[order.token].pledgeToken).safeTransfer(
            order.maker,
            refundValue
        );
        order.cancelAmount += _amount;

        txNonce[nonce] = true;

        // create new order
        if (_createNewOrder) {
            orderid++;
            orderInfos[orderid] = Order({
                orderId: orderid,
                maker: order.maker,
                orderType: order.orderType,
                tradeType: order.tradeType,
                tokenType: order.tokenType,
                token: order.token,
                amount: _newOrderAmount,
                pledgeToken: order.pledgeToken,
                value: (_newOrderAmount * order.value) / order.amount, //(order.value - totalCancelValue),
                filledAmount: 0,
                settleAmount: 0,
                cancelAmount: 0,
                backoutAmount: 0,
                takers: new address[](0)
            });
        }

        emit CancelOrder(
            msg.sender,
            _orderid,
            _amount,
            orderid,
            _newOrderAmount,
            nonce
        );
    }

    // signer do
    function matchOrder(
        uint256 sellOrderid,
        uint256 buyOrderid,
        uint256 fillAmount
    ) external whenNotPaused nonReentrant {
        // seller.taker.push(buyer.maker);
        // buyer.takers.push(seller.maker);
        // require(buyer.fillAmount>=fillAmount && seller.fillAmount>=fillAmount, "Invalid Fill Amount");
        // buyer.fillAmount = fillAmount; min(sellOrder.amount, buyOrder.amount);
        // seller.fillAmount =  fillAmount; min(sellOrder.amount, buyOrder.amount);
    }

    function _settleRequire(
        // uint256 nonce,
        // uint256 sellOrderid,
        // uint256 sellerLevel,
        // uint256 sellerReferralLevel,
        // uint256 settleAmount,
        uint256[] calldata sellArg,
        bytes calldata _signature,
        // uint256[] calldata buyOrderids,
        // uint256[] calldata buyerSettleAmounts,
        // uint256[] calldata buyerReferLevels
        uint256[][] calldata buyArgs
    ) internal returns (Order storage sellOrder) {
        require(txNonce[sellArg[0]] == false, "settle: Order already end");
        txNonce[sellArg[0]] = true;

        sellOrder = orderInfos[sellArg[1]];
        // buyerOrderid
        require(
            sellOrder.maker == msg.sender || hasRole(OPERATOR_ROLE, msg.sender),
            "Invalid Order Maker"
        );
        require(
            sellOrder.orderType == OrderType.ORDER_SELL,
            "Invalid Order Type"
        );
        require(
            sellArg[4] > 0 &&
                sellArg[4] <=
                (sellOrder.amount -
                    sellOrder.settleAmount -
                    sellOrder.cancelAmount -
                    sellOrder.backoutAmount),
            "Invalid Settle Amount"
        );
        require(
            verifySignature(settleOrderHash(sellArg, buyArgs), _signature),
            "Invalid Signature"
        );
    }

    function _settleSellerValue(
        // uint256 settleAmount,
        // uint256 orderAmount,
        // uint256 orderValue,
        // address pledgeToken,
        // uint256 sellerLevel,
        // uint256 sellerReferralLevel,
        uint256[] calldata sellArg,
        address pledgeToken,
        uint256 orderAmount,
        uint256 orderValue,
        address maker
    ) internal returns (uint256 totalSettleFee, uint256 sellerCommission) {
        uint256 settleAmount = sellArg[4];
        uint256 settleValue = (2 * (settleAmount * orderValue)) / orderAmount;
        totalSettleFee = (settleValue * config.settleRate) / BASERATE;

        uint256 sellerLevel = sellArg[2];

        // seller level discount
        if (sellerLevel > 0) {
            uint256 discountRate = surgeInvitationManager.getDiscountRate(
                sellerLevel
            );
            uint256 discount = (totalSettleFee * discountRate) / BASERATE;
            totalSettleFee -= discount;
        }

        // seller referral commission
        uint256 sellerReferralLevel = sellArg[3];
        if (sellerReferralLevel > 0) {
            uint256 commissionRate = surgeInvitationManager.getCommissionRate(
                sellerReferralLevel
            );

            sellerCommission = (totalSettleFee * commissionRate) / BASERATE;

            IERC20(pledgeToken).safeTransfer(
                address(surgeInvitationManager),
                sellerCommission
            );

            // InvitationManager transfer pledgeToken to inviter
            surgeInvitationManager.settleCommission(
                maker,
                sellerCommission,
                pledgeToken
            );

            // IERC20(pledgeToken).safeTransfer(
            //     config.feeWallet,
            //     settleFee - sellerCommission
            // );
        }

        uint256 withdrawValue = settleValue - totalSettleFee;
        IERC20(pledgeToken).safeTransfer(maker, withdrawValue);
        return (totalSettleFee, sellerCommission);
    }

    // seller can take the locked token back and pledge token
    function settle(
        uint256[] calldata sellArg,
        // uint256 nonce,
        // uint256 sellOrderid,
        // uint256 sellerLevel,
        // uint256 sellerReferralLevel,
        // uint256 settleAmount,
        // uint256[] calldata buyOrderids,
        // uint256[] calldata buyerSettleAmounts,
        // uint256[] calldata buyerReferLevels
        uint256[][] calldata buyArgs,
        bytes calldata _signature
    ) external whenNotPaused nonReentrant {
        Order storage sellOrder = _settleRequire(sellArg, _signature, buyArgs);

        address pledgeToken_ = tokenInfos[sellOrder.token].pledgeToken;
        (uint256 settleFee, uint256 sellerCommission) = _settleSellerValue(
            sellArg,
            pledgeToken_,
            sellOrder.amount,
            sellOrder.value,
            sellOrder.maker
        );

        sellOrder.settleAmount += sellArg[4];
        uint256[] memory buyOrderids = buyArgs[0];
        uint256[] memory buyerSettleAmounts = buyArgs[1];
        uint256[] memory buyerReferLevels = buyArgs[2];
        uint256 buyerCommission;
        for (uint256 i = 0; i < buyOrderids.length; i++) {
            Order storage buyOrder = orderInfos[buyOrderids[i]];
            uint256 buyerSettleAmount = buyerSettleAmounts[i];
            require(buyerSettleAmount > 0, "Invalid Settle Amount");
            buyOrder.settleAmount += buyerSettleAmount;
            // settleFee
            uint256 commissionRate = surgeInvitationManager.getCommissionRate(
                buyerReferLevels[i]
            );

            uint256 commission = (settleFee * commissionRate) / BASERATE;

            IERC20(pledgeToken_).safeTransfer(
                address(surgeInvitationManager),
                commission
            );

            // InvitationManager transfer pledgeToken to inviter
            surgeInvitationManager.settleCommission(
                buyOrder.maker,
                commission,
                pledgeToken_
            );
            buyerCommission += commission;
        }
        // uint256 receivedSettleFee = (settleFee -
        //     buyerCommission -
        //     sellerCommission);

        IERC20(pledgeToken_).safeTransfer(
            config.feeWallet,
            (settleFee - buyerCommission - sellerCommission)
        );
        emit SettleOrder(msg.sender, sellArg, buyArgs);
    }

    function backout(
        // uint256 nonce,
        // uint256 _orderid,
        // uint256 _amount,
        uint256[] calldata args,
        uint256[] calldata sellOrderids,
        uint256[] calldata sellerBackoutAmounts,
        bytes calldata _signature
    ) external nonReentrant {
        require(txNonce[args[0]] == false, "backout: Order already end");
        txNonce[args[0]] = true;
        Order storage order = orderInfos[args[1]];
        require(
            block.timestamp >=
                tokenInfos[order.token].settleTime +
                    tokenInfos[order.token].settleDuration,
            "backout: Order not end"
        );
        require(
            order.maker == msg.sender || hasRole(OPERATOR_ROLE, msg.sender),
            "Invalid Order Maker"
        );
        require(order.orderType == OrderType.ORDER_BUY, "Invalid Order Type");
        require(
            args[2] > 0 &&
                args[2] <=
                (order.amount -
                    order.settleAmount -
                    order.cancelAmount -
                    order.backoutAmount),
            "Invalid Amount"
        );
        require(
            verifySignature(
                backoutOrderHash(args, sellOrderids, sellerBackoutAmounts),
                _signature
            ),
            "Invalid Signature"
        );

        order.backoutAmount += args[2];
        // back original pledgeToken
        uint256 returnValue = (args[2] * order.value) / order.amount;
        // back backoutValue to buyer

        uint256 totalBackoutValue;
        for (uint256 i = 0; i < sellOrderids.length; i++) {
            Order storage sellOrder = orderInfos[sellOrderids[i]];
            uint256 sellerBackoutAmount = sellerBackoutAmounts[i];
            require(sellerBackoutAmount > 0, "Invalid Settle Amount");
            sellOrder.backoutAmount += sellerBackoutAmount;

            uint256 backoutValue = (sellerBackoutAmount * sellOrder.value) /
                sellOrder.amount;
            totalBackoutValue += backoutValue;
        }

        uint256 backoutFee = (totalBackoutValue * config.backoutRate) /
            BASERATE;
        uint256 totalRefundValue = returnValue +
            (totalBackoutValue - backoutFee);
        // return pledgeToken fee
        IERC20(tokenInfos[order.token].pledgeToken).safeTransfer(
            config.feeWallet,
            backoutFee
        );

        // to buyers
        IERC20(tokenInfos[order.token].pledgeToken).safeTransfer(
            order.maker,
            totalRefundValue
        );
        emit BackoutOrder(msg.sender, args, sellOrderids, sellerBackoutAmounts);
    }

    /////////////////////////
    //////// view ///////////
    /////////////////////////

    //////// token //////////
    function tokens() external view returns (bytes32[] memory) {
        return tokenSets.values();
    }

    ////////  pledge //////////
    function pledgeTokens() external view returns (address[] memory) {
        return pledgeTokenSets.values();
    }

    function orderTakers(
        uint256 _orderid
    ) external view returns (address[] memory) {
        return orderInfos[_orderid].takers;
    }

    // internal function
    function verifySignature(
        bytes32 hash,
        bytes calldata signature
    ) internal view returns (bool) {
        return ECDSA.recover(hash, signature) == config.signer;
    }

    function cancelOrderHash(
        uint256 _nonce,
        uint256 _orderid,
        uint256 _amount,
        bool _createNewOrder,
        uint256 _newOrderAmount
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        EIP712_ORDER_CANCEL,
                        _nonce,
                        _orderid,
                        _amount,
                        _createNewOrder,
                        _newOrderAmount
                    )
                )
            );
    }

    function settleOrderHash(
        // uint256 _nonce,
        // uint256 sellOrderid,
        // uint256 sellerLevel,
        // uint256 sellerReferralLevel,
        // uint256 settleAmount,
        // uint256[] calldata buyOrderids,
        // uint256[] calldata buyerSettleAmounts,
        // uint256[] calldata buyerReferLevels
        uint256[] calldata sellArg,
        uint256[][] calldata buyArg
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        EIP712_ORDER_SETTLE,
                        sellArg[0],
                        sellArg[1],
                        sellArg[2],
                        sellArg[3],
                        sellArg[4],
                        keccak256(abi.encodePacked(buyArg[0])),
                        keccak256(abi.encodePacked(buyArg[1])),
                        keccak256(abi.encodePacked(buyArg[2]))
                    )
                )
            );
    }

    function backoutOrderHash(
        // uint256 _nonce,
        // uint256 _orderid,
        // uint256 _amount,
        uint256[] calldata args,
        uint256[] calldata sellOrderids,
        uint256[] calldata sellerBackoutAmounts
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        EIP712_ORDER_BACKOUT,
                        args[0],
                        args[1],
                        args[2],
                        keccak256(abi.encodePacked(sellOrderids)),
                        keccak256(abi.encodePacked(sellerBackoutAmounts))
                    )
                )
            );
    }
}
