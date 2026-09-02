// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IAaveV4Controller {

    function aaveV4_VERSION() external pure returns (string memory);

    function aaveV4_setMaxDeficit(address hub, uint16 assetId, uint256 maxDeficit) external;

    function aaveV4_setMaxSlippage(address spoke, uint256 reserveId, uint256 maxSlippage) external;

    function aaveV4_deposit(address spoke, uint256 reserveId, uint256 amount) external;

    function aaveV4_withdraw(address spoke, uint256 reserveId, uint256 amount)
        external
        returns (uint256 amountWithdrawn);

    function aaveV4_getMaxDeficit(address hub, uint16 assetId) external view returns (uint256);

    function aaveV4_getMaxSlippage(address spoke, uint256 reserveId)
        external
        view
        returns (uint256);

    function aaveV4_getDepositRateLimitKey(
        address spoke,
        uint256 reserveId,
        address hub,
        uint16  assetId,
        address underlying
    )
        external
        pure
        returns (bytes32 key);

    function aaveV4_getWithdrawRateLimitKey(address spoke, uint256 reserveId)
        external
        pure
        returns (bytes32 key);

}
