// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IEthenaController {

    function ethena_VERSION() external pure returns (string memory);

    function ethena_setDelegatedSigner(address delegatedSigner) external;

    function ethena_removeDelegatedSigner(address delegatedSigner) external;

    function ethena_prepareMint(uint256 usdcAmount) external;

    function ethena_prepareBurn(uint256 usdeAmount) external;

    function ethena_cooldownAssets(uint256 usdeAmount) external returns (uint256 shares);

    function ethena_cooldownShares(uint256 susdeAmount) external returns (uint256 assets);

    function ethena_unstake() external;

    function ethena_setDelegatedSignerRateLimitKey() external pure returns (bytes32 key);

    function ethena_removeDelegatedSignerRateLimitKey() external pure returns (bytes32 key);

    function ethena_mintRateLimitKey() external pure returns (bytes32 key);

    function ethena_burnRateLimitKey() external pure returns (bytes32 key);

    function ethena_cooldownRateLimitKey() external pure returns (bytes32 key);

    function ethena_unstakeRateLimitKey() external pure returns (bytes32 key);

    function ethena_minter() external view returns (address);

    function ethena_susde() external view returns (address);

    function ethena_usdc() external view returns (address);

    function ethena_usde() external view returns (address);

}
