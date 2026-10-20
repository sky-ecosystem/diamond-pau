// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IERC4626Controller {

    function erc4626_VERSION() external pure returns (string memory);

    function erc4626_EXCHANGE_RATE_PRECISION() external pure returns (uint256);

    function erc4626_deposit(address token, uint256 amount, uint256 minSharesOut)
        external
        returns (uint256 shares);

    function erc4626_redeem(address token, uint256 shares, uint256 minAssetsOut)
        external
        returns (uint256 assets);

    function erc4626_setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets)
        external;

    function erc4626_withdraw(address token, uint256 amount, uint256 maxSharesIn)
        external
        returns (uint256 shares);

    function erc4626_getDepositRateLimitKey(address token, address asset)
        external
        pure
        returns (bytes32 key);

    function erc4626_getMaxExchangeRate(address token)
        external
        view
        returns (uint256 maxExchangeRate);

    function erc4626_getWithdrawRateLimitKey(address token) external pure returns (bytes32 key);

}
