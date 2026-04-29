// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib } from "../../libraries/ApproveLib.sol";

import {
    makeAddressAddressAddressKey,
    makeAddressAddressKey,
    makeAddressKey
} from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { IWEETHFacet } from "./IWEETHFacet.sol";

interface IEETHLike {

    function liquidityPool() external view returns (address);

    function shares(address account) external view returns (uint256);

}

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

}

interface ILiquidityPoolLike {

    function amountForShare(uint256 shareAmount) external view returns (uint256);

    function sharesForAmount(uint256 amount) external view returns (uint256);

    function deposit() external payable returns (uint256 shareAmount);

    function requestWithdraw(address receiver, uint256 amount) external returns (uint256 requestId);

}

interface IWEETHLike {

    function eETH() external view returns (address);

    function unwrap(uint256 amount) external returns (uint256);

    function wrap(uint256 amount) external returns (uint256);

}

interface IWEETHModuleLike {

    function claimWithdrawal(uint256 requestId) external returns (uint256 ethReceived);

}

interface IWETHLike {

    function withdraw(uint256 amount) external;

}

contract WEETHFacet is IWEETHFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc IWEETHFacet
    bytes32 public constant override LIMIT_DEPOSIT = keccak256("LIMIT_WEETH_DEPOSIT");

    /// @inheritdoc IWEETHFacet
    bytes32 public constant override LIMIT_REQUEST_WITHDRAW =
        keccak256("LIMIT_WEETH_REQUEST_WITHDRAW");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IWEETHFacet
    address public immutable override weeth;

    /// @inheritdoc IWEETHFacet
    address public immutable override weth;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address weeth_, address weth_) {
        require(weeth_ != address(0), "WEETHFacet/zero-weeth");
        require(weth_  != address(0), "WEETHFacet/zero-weth");

        weeth = weeth_;
        weth  = weth_;
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc IWEETHFacet
    function setDepositRateLimit(
        address eeth,
        address liquidityPool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(eeth != address(0),          "WEETHFacet/eeth-zero-address");
        require(liquidityPool != address(0), "WEETHFacet/liquidity-pool-zero-address");

        bytes32 key = _getDepositRateLimitKey(eeth, liquidityPool);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit WEETHDepositRateLimitSet(key, eeth, liquidityPool);
    }

    /// @inheritdoc IWEETHFacet
    function setRequestWithdrawRateLimit(
        address weethModule,
        address eeth,
        address liquidityPool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(weethModule != address(0),   "WEETHFacet/weeth-module-zero-address");
        require(eeth != address(0),          "WEETHFacet/eeth-zero-address");
        require(liquidityPool != address(0), "WEETHFacet/liquidity-pool-zero-address");

        bytes32 key = _getRequestWithdrawRateLimitKey(weethModule, eeth, liquidityPool);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit WEETHRequestWithdrawRateLimitSet(key, weethModule, eeth, liquidityPool);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc IWEETHFacet
    function deposit(uint256 amount, uint256 minSharesOut)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 shares)
    {
        address proxy         = _getSharedControllerStorage().proxy;
        address eeth          = IWEETHLike(weeth).eETH();
        address liquidityPool = IEETHLike(eeth).liquidityPool();

        // Unwrap WETH to ETH.
        IALMProxy(proxy).doCall(weth, abi.encodeCall(IWETHLike.withdraw, (amount)));

        _decreaseRateLimit(_getDepositRateLimitKey(eeth, liquidityPool), amount);

        uint256 startingEETHShares = IEETHLike(eeth).shares(proxy);

        // Deposit ETH to eETH.
        IALMProxy(proxy).doCallWithValue(
            liquidityPool,
            abi.encodeCall(ILiquidityPoolLike.deposit, ()),
            amount
        );

        uint256 eethShares = IEETHLike(eeth).shares(proxy) - startingEETHShares;
        uint256 eethAmount = ILiquidityPoolLike(liquidityPool).amountForShare(eethShares);

        // Deposit eETH to weETH.
        ApproveLib.approve(eeth, proxy, weeth, eethAmount);

        uint256 startingWEETHShares = IERC20Like(weeth).balanceOf(proxy);

        IALMProxy(proxy).doCall(weeth, abi.encodeCall(IWEETHLike.wrap, (eethAmount)));

        shares = IERC20Like(weeth).balanceOf(proxy) - startingWEETHShares;

        require(shares >= minSharesOut, "WEETHFacet/slippage-too-high");

        emit WEETHDeposit(amount, eethAmount, shares);
    }

    /// @inheritdoc IWEETHFacet
    function requestWithdraw(address weethModule, uint256 weethShares, uint256 minEETHShares)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 requestId)
    {
        address proxy         = _getSharedControllerStorage().proxy;
        address eeth          = IWEETHLike(weeth).eETH();
        address liquidityPool = IEETHLike(eeth).liquidityPool();

        uint256 startingEETHAmount = IERC20Like(eeth).balanceOf(proxy);

        // Withdraw from weETH.
        IALMProxy(proxy).doCall(weeth, abi.encodeCall(IWEETHLike.unwrap, (weethShares)));

        uint256 eethAmount = IERC20Like(eeth).balanceOf(proxy) - startingEETHAmount;

        // Protect against cumulative rate slippage across both conversions.
        require(
            ILiquidityPoolLike(liquidityPool).sharesForAmount(eethAmount) >= minEETHShares,
            "WEETHFacet/slippage-too-high"
        );

        // NOTE: An authorized weethModule is enforced by the rate limit key.
        _decreaseRateLimit(_getRequestWithdrawRateLimitKey(weethModule, eeth, liquidityPool), eethAmount);

        // Request withdrawal of ETH from eETH.
        ApproveLib.approve(eeth, proxy, liquidityPool, eethAmount);

        // NOTE: Despite the liquidity pool contract being mutable, there is no other reliable way
        //       to get the requestId without decoding the return value.
        requestId = abi.decode(
            IALMProxy(proxy).doCall(
                liquidityPool,
                abi.encodeCall(ILiquidityPoolLike.requestWithdraw, (weethModule, eethAmount))
            ),
            (uint256)
        );

        emit WEETHRequestWithdraw(weethModule, requestId, eethAmount, weethShares);
    }

    /// @inheritdoc IWEETHFacet
    function claimWithdrawal(address weethModule, uint256 requestId)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 wethReceived)
    {
        address eeth = IWEETHLike(weeth).eETH();

        // NOTE: An authorized weethModule is enforced by the rate limit key.
        require(
            _rateLimitExists(
                _getRequestWithdrawRateLimitKey(weethModule, eeth, IEETHLike(eeth).liquidityPool())
            ),
            "WEETHFacet/invalid-action"
        );

        // NOTE: The weethModule contract is first party, so the return value can be trusted.
        wethReceived = abi.decode(
            IALMProxy(_getSharedControllerStorage().proxy).doCall(
                weethModule,
                abi.encodeCall(IWEETHModuleLike.claimWithdrawal, (requestId))
            ),
            (uint256)
        );

        emit WEETHClaimWithdrawal(weethModule, requestId, wethReceived);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IWEETHFacet
    function getDepositRateLimit(address eeth, address liquidityPool)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getDepositRateLimitKey(eeth, liquidityPool));
    }

    /// @inheritdoc IWEETHFacet
    function getRequestWithdrawRateLimit(address weethModule, address eeth, address liquidityPool)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getRequestWithdrawRateLimitKey(weethModule, eeth, liquidityPool));
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _getDepositRateLimitKey(address eeth, address liquidityPool)
        internal
        pure
        returns (bytes32)
    {
        return makeAddressAddressKey(LIMIT_DEPOSIT, eeth, liquidityPool);
    }

    function _getRequestWithdrawRateLimitKey(
        address weethModule,
        address eeth,
        address liquidityPool
    )
        internal
        pure
        returns (bytes32)
    {
        return makeAddressAddressAddressKey(
            LIMIT_REQUEST_WITHDRAW,
            eeth,
            liquidityPool,
            weethModule
        );
    }

}
