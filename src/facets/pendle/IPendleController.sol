// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IPendleController {

    function pendle_VERSION() external pure returns (string memory);

    function pendle_router() external view returns (address);

    function pendle_redeem(address pendleMarket, uint256 pyAmountIn, uint256 minAmountOut) external;

    function pendle_getRedeemRateLimitKey(address pendleMarket, address pt)
        external
        pure
        returns (bytes32 key);

}
