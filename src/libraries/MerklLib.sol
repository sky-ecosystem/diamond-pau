// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IALMProxy } from "../interfaces/IALMProxy.sol";

interface IMerklDistributorLike {

    function toggleOperator(address user, address operator) external;

}

library MerklLib {

    struct MerklToggleOperatorParams {
        address proxy;
        address distributor;
        address operator;
    }

    function toggleOperator(MerklToggleOperatorParams memory params) external {
        IALMProxy(params.proxy).doCall(
            params.distributor,
            abi.encodeCall(IMerklDistributorLike.toggleOperator, (params.proxy, params.operator))
        );
    }

}
