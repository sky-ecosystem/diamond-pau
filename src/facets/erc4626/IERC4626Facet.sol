// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IERC4626Facet
 * @notice DiamondPAU facet for depositing into, withdrawing from, and redeeming
 *         shares of ERC-4626 tokenized vaults. Enforces exchange rate caps and
 *         per-token rate limits on both deposit and withdraw flows.
 */
interface IERC4626Facet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when assets are deposited into an ERC-4626 vault.
     * @param token  Address of the ERC-4626 vault token.
     * @param assets Amount of underlying assets deposited.
     * @param shares Amount of vault shares received.
     */
    event ERC4626Deposit(address indexed token, uint256 assets, uint256 shares);

    /**
     * @dev   Emitted when the max exchange rate for a vault token is updated.
     * @param token           Address of the ERC-4626 vault token.
     * @param maxExchangeRate New max exchange rate in 1e36 precision.
     */
    event ERC4626MaxExchangeRateSet(address indexed token, uint256 maxExchangeRate);

    /**
     * @dev   Emitted when vault shares are redeemed for underlying assets.
     * @param token  Address of the ERC-4626 vault token.
     * @param shares Amount of shares redeemed.
     * @param assets Amount of underlying assets received.
     */
    event ERC4626Redeem(address indexed token, uint256 shares, uint256 assets);

    /**
     * @dev   Emitted when underlying assets are withdrawn from a vault.
     * @param token  Address of the ERC-4626 vault token.
     * @param assets Amount of assets withdrawn.
     * @param shares Amount of shares burned.
     */
    event ERC4626Withdraw(address indexed token, uint256 assets, uint256 shares);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev    Deposits underlying assets into an ERC-4626 vault.
     * @param  token        Address of the ERC-4626 vault token.
     * @param  amount       Amount of underlying assets to deposit.
     * @param  minSharesOut Minimum vault shares to receive.
     * @return shares       Actual vault shares received.
     */
    function deposit(address token, uint256 amount, uint256 minSharesOut)
        external
        returns (uint256 shares);

    /**
     * @dev    Redeems vault shares for underlying assets.
     * @param  token        Address of the ERC-4626 vault token.
     * @param  shares       Amount of vault shares to redeem.
     * @param  minAssetsOut Minimum underlying assets to receive.
     * @return assets       Actual underlying assets received.
     */
    function redeem(address token, uint256 shares, uint256 minAssetsOut)
        external
        returns (uint256 assets);

    /**
     * @dev   Sets the max exchange rate for a vault token. The rate is computed
     *        as `EXCHANGE_RATE_PRECISION * maxExpectedAssets / shares`.
     * @param token             Address of the ERC-4626 vault token.
     * @param shares            Reference share amount for the rate calculation.
     * @param maxExpectedAssets Maximum expected assets for the given shares.
     */
    function setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets) external;

    /**
     * @dev    Withdraws a specific amount of underlying assets from a vault.
     * @param  token       Address of the ERC-4626 vault token.
     * @param  amount      Amount of underlying assets to withdraw.
     * @param  maxSharesIn Maximum vault shares willing to burn.
     * @return shares      Actual vault shares burned.
     */
    function withdraw(address token, uint256 amount, uint256 maxSharesIn)
        external
        returns (uint256 shares);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Precision used for exchange rate calculations (1e36).
     * @return uint256 The exchange rate precision constant.
     */
    function EXCHANGE_RATE_PRECISION() external pure returns (uint256);

    /**
     * @dev    Rate limit key for ERC-4626 deposit operations, combined with the
     *         vault token address to form per-vault keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Rate limit key for ERC-4626 withdraw operations, combined with
     *         the vault token address to form per-vault keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Returns the configured max exchange rate for a vault token.
     * @param  token           Address of the ERC-4626 vault token.
     * @return maxExchangeRate Max exchange rate in 1e36 precision. Zero if not set.
     */
    function getMaxExchangeRate(address token) external view returns (uint256);

}
