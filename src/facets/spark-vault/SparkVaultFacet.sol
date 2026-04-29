// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { makeAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { ISparkVaultFacet } from "./ISparkVaultFacet.sol";

interface ISparkVaultLike {

    function take(uint256 assetAmount) external;

}

contract SparkVaultFacet is ISparkVaultFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkVaultFacet
    bytes32 public constant override LIMIT_TAKE = keccak256("LIMIT_SPARK_VAULT_TAKE");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkVaultFacet
    function setTakeRateLimit(
        address sparkVault,
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
        require(sparkVault != address(0), "SparkVaultFacet/spark-vault-zero-address");

        bytes32 key = _getTakeRateLimitKey(sparkVault);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit SparkVaultTakeRateLimitSet(key, sparkVault);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkVaultFacet
    function take(address sparkVault, uint256 assetAmount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        _decreaseRateLimit(_getTakeRateLimitKey(sparkVault), assetAmount);

        IALMProxy(_getSharedControllerStorage().proxy).doCall(
            sparkVault,
            abi.encodeCall(ISparkVaultLike.take, (assetAmount))
        );

        emit SparkVaultTake(sparkVault, assetAmount);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkVaultFacet
    function getTakeRateLimit(address sparkVault)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getTakeRateLimitKey(sparkVault));
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _getTakeRateLimitKey(address sparkVault) internal pure returns (bytes32) {
        return makeAddressKey(LIMIT_TAKE, sparkVault);
    }

}
