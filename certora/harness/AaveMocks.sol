// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AaveMocks.sol -- Certora mocks standing in for the underlying token and the Aave pool

pragma solidity ^0.8.34;

/**
 * @notice The calls forwarded by the ALMProxy are dispatched to these mocks, which record the
 *         arguments they receive. Any selector that is not modelled lands in the fallback and is
 *         counted as an unexpected call, so that a facet cannot hide an action behind another
 *         function of the token or the pool.
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

contract MockAavePool {

    uint256 public unexpectedCalls;

    uint256 public supplyCalls;
    address public suppliedAsset;
    uint256 public suppliedAmount;
    address public suppliedOnBehalfOf;

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        unchecked { supplyCalls++; }

        suppliedAsset      = asset;
        suppliedAmount     = amount;
        suppliedOnBehalfOf = onBehalfOf;
    }

    fallback() external payable {
        unchecked { unexpectedCalls++; }
    }

}
