// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ISwapAssetFacet }              from "../../../src/facets/swap-asset/ISwapAssetFacet.sol";
import { IEnumerableIntegrations }      from "../../../src/interfaces/IEnumerableIntegrations.sol";
import { makeAddressAddressAddressKey } from "../../../src/libraries/RateLimitHelpers.sol";

import { SwapAssetFacet } from "../../../src/facets/swap-asset/SwapAssetFacet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function getSwapRateLimitKey(address assetOut, address counterpartyProxy, address assetIn) external pure returns (bytes32);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

contract Controller_SwapAssetFacet_Tests is Integration_TestBase {

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new SwapAssetFacet());

        vm.label(facet, "SwapAssetFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](1);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.getSwapRateLimitKey.selector,
            ISwapAssetFacet.getSwapRateLimitKey.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("SWAP_ASSET_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "SWAP_ASSET_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);
    }

    /**********************************************************************************************/
    /*** getSwapRateLimitKey Tests                                                              ***/
    /**********************************************************************************************/

    function test_getSwapRateLimitKey() external {
        bytes32 keyPrefix         = keccak256("LIMIT_ASSET_SWAP");
        address assetOut          = makeAddr("assetOut");
        address counterpartyProxy = makeAddr("counterpartyProxy");
        address assetIn           = makeAddr("assetIn");

        assertEq(
            controller.getSwapRateLimitKey(assetOut, counterpartyProxy, assetIn),
            makeAddressAddressAddressKey(keyPrefix, assetOut, counterpartyProxy, assetIn)
        );
    }

}
