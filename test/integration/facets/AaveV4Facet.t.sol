// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IAaveV4Facet }            from "../../../src/facets/aave-v4/IAaveV4Facet.sol";
import { IEnumerableIntegrations } from "../../../src/interfaces/IEnumerableIntegrations.sol";

import {
    makeAddressUint256AddressUint16AddressKey,
    makeAddressUint256Key
} from "../../../src/libraries/RateLimitHelpers.sol";

import { AaveV4Facet } from "../../../src/facets/aave-v4/AaveV4Facet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function setMaxDeficit(address hub, uint16 assetId, uint256 maxDeficit) external;

    function setMaxSlippage(address spoke, uint256 reserveId, uint256 maxSlippage) external;

    function getMaxDeficit(address hub, uint16 assetId) external view returns (uint256);

    function getMaxSlippage(address spoke, uint256 reserveId) external view returns (uint256);

    function getDepositRateLimitKey(
        address spoke,
        uint256 reserveId,
        address hub,
        uint16  assetId,
        address underlying
    )
        external
        pure
        returns (bytes32);

    function getWithdrawRateLimitKey(address spoke, uint256 reserveId)
        external
        pure
        returns (bytes32);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

contract Controller_AaveV4Facet_Tests is Integration_TestBase {

    // RAY-denominated in the asset's own units, so this is 1,000 units of a 6-decimal asset.
    uint256 internal constant MAX_DEFICIT = 1_000e6 * 1e27;

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new AaveV4Facet());

        vm.label(facet, "AaveV4Facet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](6);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.setMaxDeficit.selector,
            IAaveV4Facet.setMaxDeficit.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerLike.getMaxDeficit.selector,
            IAaveV4Facet.getMaxDeficit.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IControllerLike.setMaxSlippage.selector,
            IAaveV4Facet.setMaxSlippage.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IControllerLike.getMaxSlippage.selector,
            IAaveV4Facet.getMaxSlippage.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IControllerLike.getDepositRateLimitKey.selector,
            IAaveV4Facet.getDepositRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IControllerLike.getWithdrawRateLimitKey.selector,
            IAaveV4Facet.getWithdrawRateLimitKey.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("AAVE_V4_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "AAVE_V4_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);
    }

    /**********************************************************************************************/
    /*** setMaxDeficit Tests                                                                    ***/
    /**********************************************************************************************/

    function test_setMaxDeficit_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setMaxDeficit(makeAddr("hub"), 5, MAX_DEFICIT);
    }

    function test_setMaxDeficit_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        controller.setMaxDeficit(makeAddr("hub"), 5, MAX_DEFICIT);
    }

    function test_setMaxDeficit_hubZeroAddress() external {
        vm.expectRevert("AaveV4Facet/hub-zero-address");
        vm.prank(admin);
        controller.setMaxDeficit(address(0), 5, MAX_DEFICIT);
    }

    function test_setMaxDeficit() external {
        address hub     = makeAddr("hub");
        uint16  assetId = 5;

        assertEq(controller.getMaxDeficit(hub, assetId), 0);

        vm.expectEmit(address(controller));
        emit IAaveV4Facet.AaveV4MaxDeficitSet(hub, assetId, MAX_DEFICIT);
        vm.prank(admin);
        controller.setMaxDeficit(hub, assetId, MAX_DEFICIT);

        assertEq(controller.getMaxDeficit(hub, assetId), MAX_DEFICIT);

        vm.record();

        vm.expectEmit(address(controller));
        emit IAaveV4Facet.AaveV4MaxDeficitSet(hub, assetId, 0);
        vm.prank(admin);
        controller.setMaxDeficit(hub, assetId, 0);

        assertEq(controller.getMaxDeficit(hub, assetId), 0);

        _assertReentrancyGuardWrittenToTwice(address(controller));
    }

    function test_setMaxDeficit_perHubAsset() external {
        address hub      = makeAddr("hub");
        address otherHub = makeAddr("otherHub");

        vm.prank(admin);
        controller.setMaxDeficit(hub, 5, MAX_DEFICIT);

        // Neither another asset on the same hub nor the same asset id on another hub inherits it.
        assertEq(controller.getMaxDeficit(hub,      5), MAX_DEFICIT);
        assertEq(controller.getMaxDeficit(hub,      6), 0);
        assertEq(controller.getMaxDeficit(otherHub, 5), 0);
    }

    /**********************************************************************************************/
    /*** setMaxSlippage Tests                                                                   ***/
    /**********************************************************************************************/

    function test_setMaxSlippage_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setMaxSlippage(makeAddr("spoke"), 2, 0.98e18);
    }

    function test_setMaxSlippage_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        controller.setMaxSlippage(makeAddr("spoke"), 2, 0.98e18);
    }

    function test_setMaxSlippage_spokeZeroAddress() external {
        vm.expectRevert("AaveV4Facet/spoke-zero-address");
        vm.prank(admin);
        controller.setMaxSlippage(address(0), 2, 0.98e18);
    }

    function test_setMaxSlippage() external {
        address spoke     = makeAddr("spoke");
        uint256 reserveId = 2;

        assertEq(controller.getMaxSlippage(spoke, reserveId), 0);

        vm.expectEmit(address(controller));
        emit IAaveV4Facet.AaveV4MaxSlippageSet(spoke, reserveId, 0.98e18);
        vm.prank(admin);
        controller.setMaxSlippage(spoke, reserveId, 0.98e18);

        assertEq(controller.getMaxSlippage(spoke, reserveId), 0.98e18);

        vm.record();

        vm.expectEmit(address(controller));
        emit IAaveV4Facet.AaveV4MaxSlippageSet(spoke, reserveId, 0.99e18);
        vm.prank(admin);
        controller.setMaxSlippage(spoke, reserveId, 0.99e18);

        assertEq(controller.getMaxSlippage(spoke, reserveId), 0.99e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));
    }

    function test_setMaxSlippage_perMarket() external {
        address spoke = makeAddr("spoke");

        vm.startPrank(admin);
        controller.setMaxSlippage(spoke, 0, 0.98e18);
        controller.setMaxSlippage(spoke, 2, 0.99e18);
        vm.stopPrank();

        // Each reserve on the same spoke keeps its own tolerance.
        assertEq(controller.getMaxSlippage(spoke, 0), 0.98e18);
        assertEq(controller.getMaxSlippage(spoke, 2), 0.99e18);
    }

    /**********************************************************************************************/
    /*** getDepositRateLimitKey Tests                                                           ***/
    /**********************************************************************************************/

    function test_getDepositRateLimitKey() external {
        bytes32 keyPrefix  = keccak256("LIMIT_AAVE_V4_DEPOSIT");
        address spoke      = makeAddr("spoke");
        uint256 reserveId  = 2;
        address hub        = makeAddr("hub");
        uint16  assetId    = 5;
        address underlying = makeAddr("underlying");

        assertEq(
            controller.getDepositRateLimitKey(spoke, reserveId, hub, assetId, underlying),
            makeAddressUint256AddressUint16AddressKey(keyPrefix, spoke, reserveId, hub, assetId, underlying)
        );
    }

    // Literals computed outside Solidity as
    // keccak256(abi.encode(keccak256("LIMIT_AAVE_V4_DEPOSIT"), spoke, reserveId, hub, assetId, underlying)).
    // The assertion above shares the key builder under test, so it cannot see a change to the key's
    // components, their order or their types; pinning the bytes fails here instead of silently
    // re-pointing every configured market at an unfunded key.
    function test_getDepositRateLimitKey_pinnedDerivation() external view {
        assertEq(
            controller.getDepositRateLimitKey(
                0x1111111111111111111111111111111111111111,
                2,
                0x2222222222222222222222222222222222222222,
                5,
                0x3333333333333333333333333333333333333333
            ),
            0x1c92a62c98faac6a4a22d9339a4be4b9321ac7f1667a709b2f8688a4bd9dc42c
        );
    }

    /**********************************************************************************************/
    /*** getWithdrawRateLimitKey Tests                                                          ***/
    /**********************************************************************************************/

    function test_getWithdrawRateLimitKey() external {
        bytes32 keyPrefix = keccak256("LIMIT_AAVE_V4_WITHDRAW");
        address spoke     = makeAddr("spoke");
        uint256 reserveId = 0;

        assertEq(
            controller.getWithdrawRateLimitKey(spoke, reserveId),
            makeAddressUint256Key(keyPrefix, spoke, reserveId)
        );
    }

    // Pinned for the same reason as the deposit key, and deliberately omitting the reserve-derived
    // components so a remapped reserve can still be exited.
    function test_getWithdrawRateLimitKey_pinnedDerivation() external view {
        assertEq(
            controller.getWithdrawRateLimitKey(0x1111111111111111111111111111111111111111, 2),
            0x8b4febf1cc919178afbbadcbae80feb4fcee33aa4c30ae0a4612427624ffd565
        );
    }

}
