// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IUSDSController {

    function usds_VERSION() external pure returns (string memory);

    function usds_setVault(address vault) external;

    function usds_mint(uint256 usdsAmount) external;

    function usds_burn(uint256 usdsAmount) external;

    function usds_vault() external view returns (address);

    function usds_mintRateLimitKey() external pure returns (bytes32 key);

    function usds_burnRateLimitKey() external pure returns (bytes32 key);

    function usds_usds() external view returns (address);

}
