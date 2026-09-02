// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacet } from "../../../src/facets/IFacet.sol";

/**
 * @title  ICleanFacet
 * @notice Gate fixture interface — the clean baseline paired with CleanFacet.sol.
 */
interface ICleanFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when assets are deposited into a vault.
     * @param  vault  Address of the vault.
     * @param  assets Amount of underlying assets deposited.
     * @param  shares Amount of vault shares received.
     */
    event CleanDeposit(address indexed vault, uint256 assets, uint256 shares);

    /**
     * @notice Emitted when the max rate for a vault is updated.
     * @param  vault   Address of the vault.
     * @param  maxRate New max rate.
     */
    event CleanMaxRateSet(address indexed vault, uint256 maxRate);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Deposits underlying assets into a vault.
     * @param  vault        Address of the vault.
     * @param  amount       Amount of underlying assets to deposit.
     * @param  minSharesOut Minimum vault shares to receive.
     * @return shares       Actual vault shares received.
     */
    function deposit(address vault, uint256 amount, uint256 minSharesOut)
        external
        returns (uint256 shares);

    /**
     * @notice Sets the max rate for a vault.
     * @param  vault   Address of the vault.
     * @param  maxRate New max rate.
     */
    function setMaxRate(address vault, uint256 maxRate) external;

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the derived deposit rate limit key for a vault and asset,
     *         composed in the house (asset, origin) order.
     * @param  vault Address of the vault.
     * @param  asset Address of the asset being deposited.
     * @return key   Derived rate limit key.
     */
    function getDepositRateLimitKey(address vault, address asset)
        external
        pure
        returns (bytes32 key);

    /**
     * @notice Returns the configured max rate for a vault.
     * @param  vault   Address of the vault.
     * @return maxRate Configured max rate. Zero if not set.
     */
    function getMaxRate(address vault) external view returns (uint256 maxRate);

}
