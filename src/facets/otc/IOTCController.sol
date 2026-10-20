// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IOTCController {

    function otc_VERSION() external pure returns (string memory);

    function otc_setMaxSlippage(address exchange, uint256 maxSlippage) external;

    function otc_setBuffer(address exchange, address otcBuffer) external;

    function otc_setRechargeRate(address exchange, uint256 normalizedRate) external;

    function otc_send(address exchange, address asset, uint256 amount) external;

    function otc_claim(address exchange, address asset) external;

    function otc_getBuffer(address exchange) external view returns (address);

    function otc_getMaxSlippage(address exchange) external view returns (uint256);

    function otc_getRechargeRate(address exchange) external view returns (uint256);

    function otc_getState(address exchange)
        external
        view
        returns (uint256 normalizedSent, uint256 sentTimestamp, uint256 normalizedClaimed);

    function otc_getClaimWithRecharge(address exchange) external view returns (uint256);

    function otc_getIsSwapReady(address exchange) external view returns (bool);

    function otc_getSendRateLimitKey(address exchange, address asset)
        external
        pure
        returns (bytes32 key);

    function otc_getClaimRateLimitKey(address exchange, address asset)
        external
        pure
        returns (bytes32 key);

}
