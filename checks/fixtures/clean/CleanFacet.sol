// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// Gate fixture: a compact facet that satisfies every deterministic rule. It pins the
// gate's false-positive behavior — if a check ever flags this file, the check is wrong.
// Not compiled by forge (lives outside src/ and test/).

import { ApproveLib } from "../../../src/libraries/ApproveLib.sol";
import { makeAddressAddressKey } from "../../../src/libraries/RateLimitHelpers.sol";

import { IALMProxy } from "../../../src/interfaces/IALMProxy.sol";

import { IFacet } from "../../../src/facets/IFacet.sol";

import { Facet } from "../../../src/facets/Facet.sol";

import { ICleanFacet } from "./ICleanFacet.sol";

interface IVaultLike {

    function deposit(uint256 amount, address receiver) external returns (uint256 shares);

    function asset() external view returns (address);

}

interface IERC20Like {

    function balanceOf(address owner) external view returns (uint256);

}

contract CleanFacet is ICleanFacet, Facet {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.CleanFacet.v1
    struct FacetStorage {
        mapping (address vault => uint256 maxRate) maxRates;
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.CleanFacet.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant FACET_STORAGE_LOCATION =
        0xf594a8ca12dadf50dba7dc9c08d28f640b84c2d74fa565d08896f13e25924400;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 internal constant _LIMIT_DEPOSIT = keccak256("LIMIT_CLEAN_DEPOSIT");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc ICleanFacet
    function setMaxRate(address vault, uint256 maxRate)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(vault != address(0), "CleanFacet/vault-zero-address");

        emit CleanMaxRateSet(vault, _getFacetStorage().maxRates[vault] = maxRate);
    }

    /**********************************************************************************************/
    /*** External Interactive Allocator Functions                                               ***/
    /**********************************************************************************************/

    /// @inheritdoc ICleanFacet
    function deposit(address vault, uint256 amount, uint256 minSharesOut)
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
        returns (uint256 shares)
    {
        address proxy = _getSharedControllerStorage().proxy;
        address asset = IVaultLike(vault).asset();

        _decreaseRateLimit(getDepositRateLimitKey(vault, asset), amount);

        ApproveLib.approve(asset, proxy, vault, amount);

        uint256 startingShares = IERC20Like(vault).balanceOf(proxy);

        IALMProxy(proxy).doCall(vault, abi.encodeCall(IVaultLike.deposit, (amount, proxy)));

        shares = IERC20Like(vault).balanceOf(proxy) - startingShares;

        require(shares >= minSharesOut, "CleanFacet/min-shares-out-not-met");

        ApproveLib.approve(asset, proxy, vault, 0);

        emit CleanDeposit(vault, amount, shares);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ICleanFacet
    function getMaxRate(address vault) external view override returns (uint256) {
        return _getFacetStorage().maxRates[vault];
    }

    /// @inheritdoc ICleanFacet
    function getDepositRateLimitKey(address vault, address asset)
        public
        pure
        override
        returns (bytes32)
    {
        return makeAddressAddressKey(_LIMIT_DEPOSIT, asset, vault);
    }

}
