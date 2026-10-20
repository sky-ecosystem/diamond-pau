// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IMerklController {

    function merkl_VERSION() external pure returns (string memory);

    function merkl_toggleOperator(address distributor, address operator) external;

    function merkl_getToggleOperatorRateLimitKey(address distributor, address operator)
        external
        pure
        returns (bytes32 key);

}
