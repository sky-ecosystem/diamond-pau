// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface INFATPrimeController {

    function nfatPrime_VERSION() external pure returns (string memory);

    function nfatPrime_subscribe(address facility, uint256 amount, bytes calldata data) external;

    function nfatPrime_withdraw(address facility, uint256 amount) external;

    function nfatPrime_collect(address facility, uint256 tokenId, uint256 amount) external;

    function nfatPrime_getCollectRateLimitKey(address facility) external pure returns (bytes32 key);

    function nfatPrime_getSubscribeRateLimitKey(address facility, address gem)
        external
        pure
        returns (bytes32 key);

    function nfatPrime_getWithdrawRateLimitKey(address facility)
        external
        pure
        returns (bytes32 key);

}
