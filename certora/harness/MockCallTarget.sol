// SPDX-License-Identifier: AGPL-3.0-or-later
//
// MockCallTarget.sol -- Certora mock standing in for a contract called through the ALMProxy

pragma solidity ^0.8.34;

/**
 * @notice Records every call it receives through its fallback: caller, value and calldata hash.
 *         Whether it reverts is read from storage, so a rule covers both outcomes. It has no
 *         external functions, so any calldata reaches the fallback.
 */
contract MockCallTarget {

    bool    internal shouldRevert;
    uint256 internal calls;
    address internal lastSender;
    uint256 internal lastValue;
    bytes32 internal lastDataHash;

    fallback() external payable {
        require(!shouldRevert);

        unchecked { calls++; }

        lastSender   = msg.sender;
        lastValue    = msg.value;
        lastDataHash = keccak256(msg.data);
    }

}
