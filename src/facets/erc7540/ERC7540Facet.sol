// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }                            from "../../libraries/ApproveLib.sol";
import { makeAddressAddressKey, makeAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { IERC7540Facet } from "./IERC7540Facet.sol";

interface IERC4626Like {

    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    function withdraw(uint256 assets, address receiver, address owner)
        external
        returns (uint256 shares);

    function asset() external view returns (address);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    function maxMint(address receiver) external view returns (uint256 maxShares);

    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

}

interface IERC7540Like {

    function requestDeposit(uint256 assets, address controller, address owner)
        external
        returns (uint256 requestId);

    function requestRedeem(uint256 shares, address controller, address owner)
        external
        returns (uint256 requestId);

}

contract ERC7540Facet is IERC7540Facet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc IERC7540Facet
    bytes32 public constant override LIMIT_DEPOSIT = keccak256("LIMIT_7540_DEPOSIT");

    /// @inheritdoc IERC7540Facet
    bytes32 public constant override LIMIT_REDEEM = keccak256("LIMIT_7540_REDEEM");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc IERC7540Facet
    function setDepositRateLimit(
        address token,
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
        require(token != address(0), "ERC7540Facet/token-zero-address");
        require(asset != address(0), "ERC7540Facet/asset-zero-address");

        bytes32 key = _getDepositRateLimitKey(token, asset);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit ERC7540DepositRateLimitSet(key, token, asset);
    }

    /// @inheritdoc IERC7540Facet
    function setRedeemRateLimit(
        address token,
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
        require(token != address(0), "ERC7540Facet/token-zero-address");

        bytes32 key = _getRedeemRateLimitKey(token);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit ERC7540RedeemRateLimitSet(key, token);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc IERC7540Facet
    function requestDeposit(address token, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        address proxy = _getSharedControllerStorage().proxy;
        address asset = IERC4626Like(token).asset();

        ApproveLib.approve(asset, proxy, token, amount);

        _decreaseRateLimit(_getDepositRateLimitKey(token, asset), amount);

        // Submit deposit request by transferring assets
        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(IERC7540Like.requestDeposit, (amount, proxy, proxy))
        );

        emit ERC7540RequestDeposit(token, amount);
    }

    /// @inheritdoc IERC7540Facet
    function claimDeposit(address token) external override nonReentrant onlyRole(RELAYER_ROLE) {
        _requireRateLimitExists(_getDepositRateLimitKey(token, IERC4626Like(token).asset()));

        address proxy  = _getSharedControllerStorage().proxy;
        uint256 shares = IERC4626Like(token).maxMint(proxy);

        // Claim shares from the vault to the proxy
        IALMProxy(proxy).doCall(token, abi.encodeCall(IERC4626Like.mint, (shares, proxy)));

        emit ERC7540ClaimDeposit(token, shares);
    }

    /// @inheritdoc IERC7540Facet
    function requestRedeem(address token, uint256 shares)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        _decreaseRateLimit(
            _getRedeemRateLimitKey(token),
            IERC4626Like(token).convertToAssets(shares)
        );

        address proxy = _getSharedControllerStorage().proxy;

        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(IERC7540Like.requestRedeem, (shares, proxy, proxy))
        );

        emit ERC7540RequestRedeem(token, shares);
    }

    /// @inheritdoc IERC7540Facet
    function claimRedeem(address token) external override nonReentrant onlyRole(RELAYER_ROLE) {
        _requireRateLimitExists(_getRedeemRateLimitKey(token));

        address proxy  = _getSharedControllerStorage().proxy;
        uint256 assets = IERC4626Like(token).maxWithdraw(proxy);

        // Claim assets from the vault to the proxy
        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(IERC4626Like.withdraw, (assets, proxy, proxy))
        );

        emit ERC7540ClaimRedeem(token, assets);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IERC7540Facet
    function getDepositRateLimit(address token, address asset)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getDepositRateLimitKey(token, asset));
    }

    /// @inheritdoc IERC7540Facet
    function getRedeemRateLimit(address token)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getRedeemRateLimitKey(token));
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _getDepositRateLimitKey(address token, address asset) internal pure returns (bytes32) {
        return makeAddressAddressKey(LIMIT_DEPOSIT, asset, token);
    }

    function _getRedeemRateLimitKey(address token) internal pure returns (bytes32) {
        return makeAddressKey(LIMIT_REDEEM, token);
    }

    function _requireRateLimitExists(bytes32 key) internal view {
        require(_rateLimitExists(key), "ERC7540Facet/invalid-action");
    }

}
