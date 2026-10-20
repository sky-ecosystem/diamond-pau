// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IWrapProxyETHController {

    function wrapProxyETH_VERSION() external pure returns (string memory);

    function wrapProxyETH_wrapAll() external;

    function wrapProxyETH_wrapRateLimitKey() external pure returns (bytes32 key);

    function wrapProxyETH_weth() external view returns (address);

}
