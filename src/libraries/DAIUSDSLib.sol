// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { IALMProxy }   from "../interfaces/IALMProxy.sol";
import { IRateLimits } from "../interfaces/IRateLimits.sol";

import { ApproveLib } from "./ApproveLib.sol";

interface IDAIUSDSLike {

    function daiToUsds(address usr, uint256 wad) external;

    function usdsToDai(address usr, uint256 wad) external;

}

library DAIUSDSLib {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant LIMIT_SWAP = keccak256("LIMIT_DAIUSDS_SWAP");

    /**********************************************************************************************/
    /*** External interactive functions                                                         ***/
    /**********************************************************************************************/

    function swapUSDSToDAI(address proxy, address rateLimits, uint256 usdsAmount) external {
        IRateLimits(rateLimits).triggerRateLimitDecrease(LIMIT_SWAP, usdsAmount);

        ApproveLib.approve(Ethereum.USDS, proxy, Ethereum.DAI_USDS, usdsAmount);

        IALMProxy(proxy).doCall(
            Ethereum.DAI_USDS,
            abi.encodeCall(IDAIUSDSLike.usdsToDai, (proxy, usdsAmount))
        );
    }

    function swapDAIToUSDS(address proxy, address rateLimits, uint256 daiAmount) external {
        IRateLimits(rateLimits).triggerRateLimitIncrease(LIMIT_SWAP, daiAmount);

        ApproveLib.approve(Ethereum.DAI, proxy, Ethereum.DAI_USDS, daiAmount);

        IALMProxy(proxy).doCall(
            Ethereum.DAI_USDS,
            abi.encodeCall(IDAIUSDSLike.daiToUsds, (proxy, daiAmount))
        );
    }

}
