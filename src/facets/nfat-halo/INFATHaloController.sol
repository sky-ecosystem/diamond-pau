// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface INFATHaloController {

    function nfatHalo_VERSION() external pure returns (string memory);

    function nfatHalo_setMaxAnnualGrowthRate(address facility, uint256 maxAnnualGrowthRate)
        external;

    function nfatHalo_issue(address facility, address to, uint256 tokenId, uint256 amount) external;

    function nfatHalo_repayPrincipal(address facility, uint256 tokenId, uint256 amount) external;

    function nfatHalo_repayInterest(address facility, uint256 tokenId, uint256 amount) external;

    function nfatHalo_getMaxAnnualGrowthRate(address facility) external view returns (uint256);

    function nfatHalo_getFacilityState(address facility)
        external
        view
        returns (uint256 interestIndex, uint256 lastUpdated);

    function nfatHalo_getPosition(address facility, uint256 tokenId)
        external
        view
        returns (
            bool    issued,
            uint256 outstandingPrincipal,
            uint256 maxOutstandingInterest,
            uint256 interestIndex
        );

    function nfatHalo_getCurrentMaxOutstandingInterest(address facility, uint256 tokenId)
        external
        view
        returns (uint256);

    function nfatHalo_getIssueRateLimitKey(address facility, address to)
        external
        pure
        returns (bytes32 key);

    function nfatHalo_getRepayInterestRateLimitKey(address facility, address gem)
        external
        pure
        returns (bytes32 key);

    function nfatHalo_getRepayPrincipalRateLimitKey(address facility, address gem)
        external
        pure
        returns (bytes32 key);

}
