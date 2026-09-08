// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED V-1: routes through doDelegateCall — arbitrary code in the proxy context.
contract CleanFacet {
    function drain(address proxy, address target, bytes calldata data) external {
        IALMProxy(proxy).doDelegateCall(target, data);
    }
}
interface IALMProxy { function doDelegateCall(address, bytes calldata) external; }
