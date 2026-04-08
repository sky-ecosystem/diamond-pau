// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IERC4626Facet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when a deposit is made.
     * @param token  Token address.
     * @param assets Amount of assets deposited.
     * @param shares Amount of shares received.
     */
    event ERC4626Deposit(address indexed token, uint256 assets, uint256 shares);

    /**
     * @dev   Event emitted when max exchange rate is set.
     * @param token           Token address.
     * @param maxExchangeRate Max exchange rate allowed.
     */
    event ERC4626MaxExchangeRateSet(address indexed token, uint256 maxExchangeRate);

    /**
     * @dev   Event emitted when shares are redeemed.
     * @param token  Token address.
     * @param shares Amount of shares redeemed.
     * @param assets Amount of assets received.
     */
    event ERC4626Redeem(address indexed token, uint256 shares, uint256 assets);

    /**
     * @dev   Event emitted when assets are withdrawn.
     * @param token  Token address.
     * @param assets Amount of assets withdrawn.
     * @param shares Amount of shares burnt.
     */
    event ERC4626Withdraw(address indexed token, uint256 assets, uint256 shares);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev    Deposits `amount` of tokens.
     * @param  token        Token address.
     * @param  amount       Amount of tokens to deposit.
     * @param  minSharesOut Minimum amount of shares to receive.
     * @return shares       Amount of shares received.
     */
    function deposit(address token, uint256 amount, uint256 minSharesOut)
        external
        returns (uint256 shares);

    /**
     * @dev    Redeems `shares` of tokens.
     * @param  token        Token address.
     * @param  shares       Amount of shares to redeem.
     * @param  minAssetsOut Minimum amount of assets to receive.
     * @return assets       Amount of assets received.
     */
    function redeem(address token, uint256 shares, uint256 minAssetsOut)
        external
        returns (uint256 assets);

    /**
     * @dev   Sets max exchange rate for a token.
     * @param token             Token address.
     * @param shares            Amount of shares.
     * @param maxExpectedAssets Maximum expected assets.
     */
    function setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets) external;

    /**
     * @dev    Withdraws `amount` of tokens.
     * @param  token       Token address.
     * @param  amount      Amount of tokens to withdraw.
     * @param  maxSharesIn Maximum amount of shares to withdraw.
     * @return shares      Amount of shares withdrawn.
     */
    function withdraw(address token, uint256 amount, uint256 maxSharesIn)
        external
        returns (uint256 shares);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Exchange rate precision.
     * @return uint256 Exchange rate precision.
     */
    function EXCHANGE_RATE_PRECISION() external pure returns (uint256);

    /**
     * @dev    Limit for deposit operations.
     * @return bytes32 Key for deposit limit.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Limit for withdraw operations.
     * @return bytes32 Key for withdraw limit.
     */
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Gets max exchange rate for a token.
     * @param  token           Token address.
     * @return maxExchangeRate Max exchange rate allowed.
     */
    function getMaxExchangeRate(address token) external view returns (uint256);

}
