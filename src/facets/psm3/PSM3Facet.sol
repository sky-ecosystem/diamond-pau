// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }     from "../../libraries/ApproveLib.sol";
import { makeAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IFacet } from "../IFacet.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { Facet } from "../Facet.sol";

import { IPSM3Facet } from "./IPSM3Facet.sol";

interface IPSM3Like {

    function deposit(address asset, address receiver, uint256 assetsToDeposit)
        external
        returns (uint256 newShares);

    function withdraw(address asset, address receiver, uint256 maxAssetsToWithdraw)
        external
        returns (uint256 assetsWithdrawn);

    function shares(address user) external view returns (uint256);

}

contract PSM3Facet is IPSM3Facet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc IPSM3Facet
    bytes32 public constant override LIMIT_DEPOSIT = keccak256("LIMIT_PSM_DEPOSIT");

    /// @inheritdoc IPSM3Facet
    bytes32 public constant override LIMIT_WITHDRAW = keccak256("LIMIT_PSM_WITHDRAW");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IPSM3Facet
    address public immutable override psm;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address psm_) {
        require(psm_ != address(0), "PSM3Facet/zero-psm");

        psm = psm_;
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc IPSM3Facet
    function setDepositRateLimit(
        address asset,
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
        require(asset != address(0), "PSM3Facet/asset-zero-address");

        bytes32 key = _getDepositRateLimitKey(asset);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit PSM3DepositRateLimitSet(key, asset);
    }

    /// @inheritdoc IPSM3Facet
    function setWithdrawRateLimit(
        address asset,
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
        require(asset != address(0), "PSM3Facet/asset-zero-address");

        bytes32 key = _getWithdrawRateLimitKey(asset);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit PSM3WithdrawRateLimitSet(key, asset);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc IPSM3Facet
    function deposit(address asset, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 shares)
    {
        _decreaseRateLimit(_getDepositRateLimitKey(asset), amount);

        address proxy = _getSharedControllerStorage().proxy;

        // Approve `asset` to PSM from the proxy (assumes the proxy has enough `asset`).
        ApproveLib.approve(asset, proxy, psm, amount);

        // Deposit `amount` of `asset` in the PSM, decode the result to get `shares`.
        // NOTE: The PSM3 contract is immutable, so the return value can be trusted.
        shares = abi.decode(
            IALMProxy(proxy).doCall(
                psm,
                abi.encodeCall(IPSM3Like.deposit, (asset, proxy, amount))
            ),
            (uint256)
        );

        emit PSM3Deposit(asset, amount, shares);
    }

    /// @inheritdoc IPSM3Facet
    function withdraw(address asset, uint256 maxAmount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 assetsWithdrawn)
    {
        address proxy = _getSharedControllerStorage().proxy;

        uint256 startingShares = IPSM3Like(psm).shares(proxy);

        // Withdraw up to `maxAmount` of `asset` in the PSM, decode the result to get
        // `assetsWithdrawn` (assumes the proxy has enough PSM shares).
        // NOTE: The PSM3 contract is immutable, so the return value can be trusted.
        assetsWithdrawn = abi.decode(
            IALMProxy(proxy).doCall(
                psm,
                abi.encodeCall(IPSM3Like.withdraw, (asset, proxy, maxAmount))
            ),
            (uint256)
        );

        _decreaseRateLimit(_getWithdrawRateLimitKey(asset), assetsWithdrawn);

        emit PSM3Withdraw(asset, assetsWithdrawn, startingShares - IPSM3Like(psm).shares(proxy));
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IPSM3Facet
    function getDepositRateLimit(address asset)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getDepositRateLimitKey(asset));
    }

    /// @inheritdoc IPSM3Facet
    function getWithdrawRateLimit(address asset)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getWithdrawRateLimitKey(asset));
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _getDepositRateLimitKey(address asset) internal pure returns (bytes32) {
        return makeAddressKey(LIMIT_DEPOSIT, asset);
    }

    function _getWithdrawRateLimitKey(address asset) internal pure returns (bytes32) {
        return makeAddressKey(LIMIT_WITHDRAW, asset);
    }

}
