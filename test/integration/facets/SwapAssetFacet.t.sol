// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ISwapAssetFacet }              from "../../../src/facets/swap-asset/ISwapAssetFacet.sol";
import { IEnumerableIntegrations }      from "../../../src/interfaces/IEnumerableIntegrations.sol";
import { makeAddressAddressAddressKey } from "../../../src/libraries/RateLimitHelpers.sol";

import { SwapAssetFacet } from "../../../src/facets/swap-asset/SwapAssetFacet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function getInitiateSwapRateLimitKey(address assetOut, address counterpartyProxy, address assetIn)
        external
        pure
        returns (bytes32);

    function getCompleteSwapRateLimitKey(address assetOut, address counterpartyProxy, address assetIn)
        external
        pure
        returns (bytes32);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

contract Controller_SwapAssetFacet_Tests is Integration_TestBase {

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new SwapAssetFacet());

        vm.label(facet, "SwapAssetFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](2);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.getInitiateSwapRateLimitKey.selector,
            ISwapAssetFacet.getInitiateSwapRateLimitKey.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerLike.getCompleteSwapRateLimitKey.selector,
            ISwapAssetFacet.getCompleteSwapRateLimitKey.selector
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
    /*** getInitiateSwapRateLimitKey Tests                                                        ***/
    /**********************************************************************************************/

    function test_getInitiateSwapRateLimitKey() external {
        bytes32 keyPrefix         = keccak256("LIMIT_INITIATE_ASSET_SWAP");
        address assetOut          = makeAddr("assetOut");
        address counterpartyProxy = makeAddr("counterpartyProxy");
        address assetIn           = makeAddr("assetIn");

        assertEq(
            controller.getInitiateSwapRateLimitKey(assetOut, counterpartyProxy, assetIn),
            makeAddressAddressAddressKey(keyPrefix, assetOut, counterpartyProxy, assetIn)
        );
    }

    /**********************************************************************************************/
    /*** getCompleteSwapRateLimitKey Tests                                                        ***/
    /**********************************************************************************************/

    function test_getCompleteSwapRateLimitKey() external {
        bytes32 keyPrefix         = keccak256("LIMIT_COMPLETE_ASSET_SWAP");
        address assetOut          = makeAddr("assetOut");
        address counterpartyProxy = makeAddr("counterpartyProxy");
        address assetIn           = makeAddr("assetIn");

        assertEq(
            controller.getCompleteSwapRateLimitKey(assetOut, counterpartyProxy, assetIn),
            makeAddressAddressAddressKey(keyPrefix, assetOut, counterpartyProxy, assetIn)
        );
    }

}
