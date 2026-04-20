// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }            from "../../libraries/ApproveLib.sol";
import { makeAddressAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { FacetBase } from "../FacetBase.sol";

import { IBasinFacet } from "./IBasinFacet.sol";

interface IBasinLike {

    function convertToShares(address asset, uint256 assets) external view returns (uint256);

    function deposit(address asset, address receiver, uint256 assetsToDeposit)
        external
        returns (uint256 newShares);

    function withdraw(address asset, address receiver, uint256 maxAssetsToWithdraw)
        external
        returns (uint256 assetsWithdrawn);

    function shares(address user) external view returns (uint256);

}

contract BasinFacet is IBasinFacet, FacetBase {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.BasinFacet.v1
    struct FacetStorage {
        mapping (address basin => uint256 maxSlippage) maxSlippages;  // 1e18 precision
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.BasinFacet.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant FACET_STORAGE_LOCATION =
        0x89ab93629cc54fc184e22c44051ccd8203bdf2513b73a13dd2b537a7c0711100;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant override LIMIT_DEPOSIT  = keccak256("LIMIT_BASIN_DEPOSIT");
    bytes32 public constant override LIMIT_WITHDRAW = keccak256("LIMIT_BASIN_WITHDRAW");

    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function setMaxSlippage(address basin, uint256 maxSlippage)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(basin != address(0), "BasinFacet/basin-zero-address");

        _getFacetStorage().maxSlippages[basin] = maxSlippage;

        emit BasinMaxSlippageSet(basin, maxSlippage);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    function deposit(address basin, address asset, uint256 amount, uint256 minSharesOut)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 shares)
    {
        uint256 maxSlippage = _getFacetStorage().maxSlippages[basin];

        require(maxSlippage != 0, "BasinFacet/max-slippage-not-set");

        // Ensure `minSharesOut` is within slippage tolerance of the fair share amount.
        require(
            minSharesOut >= IBasinLike(basin).convertToShares(asset, amount) * maxSlippage / 1e18,
            "BasinFacet/min-amount-not-met"
        );

        _decreaseRateLimit(LIMIT_DEPOSIT, basin, asset, amount);

        address proxy = _getSharedControllerStorage().proxy;

        // Approve `asset` to Basin from the proxy (assumes the proxy has enough `asset`).
        ApproveLib.approve(asset, proxy, basin, amount);

        // Deposit `amount` of `asset` in the Basin, decode the result to get `shares`.
        shares = abi.decode(
            IALMProxy(proxy).doCall(
                basin,
                abi.encodeCall(IBasinLike.deposit, (asset, proxy, amount))
            ),
            (uint256)
        );

        require(shares >= minSharesOut, "BasinFacet/min-shares-out-not-met");

        emit BasinDeposit(basin, asset, amount, shares);
    }

    function withdraw(address basin, address asset, uint256 maxAmount, uint256 maxSharesIn)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 assetsWithdrawn)
    {
        uint256 maxSlippage = _getFacetStorage().maxSlippages[basin];

        require(maxSlippage != 0, "BasinFacet/max-slippage-not-set");

        // Ensure `maxSharesIn` is within slippage tolerance of the fair share amount.
        require(
            maxSharesIn * maxSlippage
                <= IBasinLike(basin).convertToShares(asset, maxAmount) * 1e18,
            "BasinFacet/max-amount-not-met"
        );

        address proxy = _getSharedControllerStorage().proxy;

        uint256 sharesBefore = IBasinLike(basin).shares(proxy);

        // Withdraw up to `maxAmount` of `asset` in the Basin, decode the result to get
        // `assetsWithdrawn` (assumes the proxy has enough Basin shares).
        // NOTE: Rate limited at end of function, so cannot return here.
        assetsWithdrawn = abi.decode(
            IALMProxy(proxy).doCall(
                basin,
                abi.encodeCall(IBasinLike.withdraw, (asset, proxy, maxAmount))
            ),
            (uint256)
        );

        uint256 sharesIn = sharesBefore - IBasinLike(basin).shares(proxy);

        require(sharesIn <= maxSharesIn, "BasinFacet/shares-burned-too-high");

        _decreaseRateLimit(LIMIT_WITHDRAW, basin, asset, assetsWithdrawn);

        emit BasinWithdraw(
            basin,
            asset,
            assetsWithdrawn,
            sharesIn
        );
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function getMaxSlippage(address basin) external view override returns (uint256) {
        return _getFacetStorage().maxSlippages[basin];
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _decreaseRateLimit(
        bytes32 key,
        address basin,
        address asset,
        uint256 amount
    )
        internal
    {
        IRateLimits(_getSharedControllerStorage().rateLimits).triggerRateLimitDecrease(
            makeAddressAddressKey(key, asset, basin),
            amount
        );
    }

}
