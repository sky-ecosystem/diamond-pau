// SPDX-License-Identifier: AGPL-3.0-or-later
//
// MockERC20.sol -- Certora mock standing in for a token approved through the ALMProxy

pragma solidity ^0.8.34;

/**
 * @notice Records every approve forwarded by the ALMProxy. Any other selector lands in the
 *         fallback and is counted as an unexpected call.
 */
contract MockERC20 {

    uint256 public unexpectedCalls;

    uint256 public approveCalls;
    uint256 public lastApprovedAmount;

    mapping (address spender => uint256 count)  public approvalsTo;
    mapping (uint256 amount  => bool    seen)   public approvedAmountSeen;

    function approve(address spender, uint256 amount) external returns (bool) {
        unchecked { approveCalls++; approvalsTo[spender]++; }

        approvedAmountSeen[amount] = true;
        lastApprovedAmount         = amount;

        return true;
    }

    fallback() external payable {
        unchecked { unexpectedCalls++; }
    }

}
