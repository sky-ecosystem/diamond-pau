// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IERC4626Facet
 * @notice PAU facet for depositing into, withdrawing from, and redeeming shares of ERC-4626
 *         tokenized vaults. Enforces exchange rate caps and per-token rate limits on both deposit
 *         and withdraw flows.
 */
interface IERC4626Facet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when assets are deposited into an ERC-4626 vault.
     * @param  token  Address of the ERC-4626 vault token.
     * @param  assets Amount of underlying assets deposited.
     * @param  shares Amount of vault shares received.
     */
    event ERC4626Deposit(address indexed token, uint256 assets, uint256 shares);

    /**
     * @notice Emitted when the deposit rate limit is set.
     * @param  key   Rate limit key.
     * @param  token Address of the ERC-4626 vault token.
     * @param  asset Address of the asset being deposited.
     */
    event ERC4626DepositRateLimitSet(bytes32 indexed key, address indexed token, address asset);

    /**
     * @notice Emitted when the max exchange rate for a vault token is updated.
     * @param  token           Address of the ERC-4626 vault token.
     * @param  maxExchangeRate New max exchange rate in 1e36 precision.
     */
    event ERC4626MaxExchangeRateSet(address indexed token, uint256 maxExchangeRate);

    /**
     * @notice Emitted when vault shares are redeemed for underlying assets.
     * @param  token  Address of the ERC-4626 vault token.
     * @param  shares Amount of shares redeemed.
     * @param  assets Amount of underlying assets received.
     */
    event ERC4626Redeem(address indexed token, uint256 shares, uint256 assets);

    /**
     * @notice Emitted when underlying assets are withdrawn from a vault.
     * @param  token  Address of the ERC-4626 vault token.
     * @param  assets Amount of assets withdrawn.
     * @param  shares Amount of shares burned.
     */
    event ERC4626Withdraw(address indexed token, uint256 assets, uint256 shares);

    /**
     * @notice Emitted when the withdraw rate limit is set.
     * @param  key   Rate limit key.
     * @param  token Address of the ERC-4626 vault token.
     */
    event ERC4626WithdrawRateLimitSet(bytes32 indexed key, address indexed token);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Deposits underlying assets into an ERC-4626 vault.
     * @param  token        Address of the ERC-4626 vault token.
     * @param  amount       Amount of underlying assets to deposit.
     * @param  minSharesOut Minimum vault shares to receive.
     * @return shares       Actual vault shares received.
     */
    function deposit(address token, uint256 amount, uint256 minSharesOut)
        external
        returns (uint256 shares);

    /**
     * @notice Redeems vault shares for underlying assets.
     * @param  token        Address of the ERC-4626 vault token.
     * @param  shares       Amount of vault shares to redeem.
     * @param  minAssetsOut Minimum underlying assets to receive.
     * @return assets       Actual underlying assets received.
     */
    function redeem(address token, uint256 shares, uint256 minAssetsOut)
        external
        returns (uint256 assets);

    /**
     * @notice Sets the deposit rate limit for a given token and asset.
     * @param  token       Address of the ERC-4626 vault token.
     * @param  asset       Address of the asset being deposited.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setDepositRateLimit(
        address token,
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Sets the max exchange rate for a vault token. The rate is computed as
     *         `EXCHANGE_RATE_PRECISION * maxExpectedAssets / shares`.
     * @param  token             Address of the ERC-4626 vault token.
     * @param  shares            Reference share amount for the rate calculation.
     * @param  maxExpectedAssets Maximum expected assets for the given shares.
     */
    function setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets) external;

    /**
     * @notice Sets the withdraw rate limit for a given token.
     * @param  token       Address of the ERC-4626 vault token.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setWithdrawRateLimit(
        address token,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Withdraws a specific amount of underlying assets from a vault.
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

    /// @notice Precision used for exchange rate calculations (1e36).
    function EXCHANGE_RATE_PRECISION() external pure returns (uint256);

    /// @notice Rate limit key prefix for deposit operations.
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /// @notice Rate limit key prefix for withdraw operations.
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured max exchange rate for a vault token.
     * @param  token           Address of the ERC-4626 vault token.
     * @return maxExchangeRate Max exchange rate in 1e36 precision. Zero if not set.
     */
    function getMaxExchangeRate(address token) external view returns (uint256 maxExchangeRate);

    /**
     * @notice Returns the deposit rate limit for a given token and asset.
     * @param  token Address of the ERC-4626 vault token.
     * @param  asset Address of the asset being deposited.
     * @return data  Rate limit data.
     */
    function getDepositRateLimit(address token, address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

    /**
     * @notice Returns the withdraw rate limit for a given token.
     * @param  token Address of the ERC-4626 vault token.
     * @return data  Rate limit data.
     */
    function getWithdrawRateLimit(address token)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
