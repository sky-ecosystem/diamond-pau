// SPDX-License-Identifier: AGPL-3.0-or-later
//
// CCTPMocks.sol -- Certora mock standing in for the CCTP token messenger

pragma solidity ^0.8.34;

/**
 * @notice Records every depositForBurn forwarded by the ALMProxy, in call order. It also plays
 *         its own token minter, answering the two static reads the facet makes (`localMinter`
 *         and `burnLimitsPerMessage`). Any other selector lands in the fallback and is counted as
 *         an unexpected call.
 */
contract MockCCTP {

    uint256 public unexpectedCalls;

    mapping (address token => uint256 limit) public burnLimitsPerMessage;

    function localMinter() external view returns (address) {
        return address(this);
    }

    uint256 public depositCalls;
    uint256 public depositedTotal;

    mapping (uint256 index => uint256 amount)            public amounts;
    mapping (uint256 index => uint32  destinationDomain) public destinationDomains;
    mapping (uint256 index => bytes32 mintRecipient)     public mintRecipients;
    mapping (uint256 index => address burnToken)         public burnTokens;
    mapping (uint256 index => bytes32 destinationCaller) public destinationCallers;
    mapping (uint256 index => uint256 maxFee)            public maxFees;
    mapping (uint256 index => uint32  minFinality)       public minFinalityThresholds;

    function depositForBurn(
        uint256 amount,
        uint32  destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32  minFinalityThreshold
    ) external {
        uint256 i = depositCalls;

        amounts[i]               = amount;
        destinationDomains[i]    = destinationDomain;
        mintRecipients[i]        = mintRecipient;
        burnTokens[i]            = burnToken;
        destinationCallers[i]    = destinationCaller;
        maxFees[i]               = maxFee;
        minFinalityThresholds[i] = minFinalityThreshold;

        unchecked { depositCalls = i + 1; depositedTotal += amount; }
    }

    fallback() external payable {
        unchecked { unexpectedCalls++; }
    }

}
