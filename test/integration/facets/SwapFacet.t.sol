// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ERC20Mock } from "../../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IEnumerableIntegrations }      from "../../../src/interfaces/IEnumerableIntegrations.sol";
import { IFacet }                       from "../../../src/facets/IFacet.sol";
import { ISwapFacet }                   from "../../../src/facets/swap/ISwapFacet.sol";
import { makeAddressAddressAddressKey } from "../../../src/libraries/RateLimitHelpers.sol";

import { SwapFacet } from "../../../src/facets/swap/SwapFacet.sol";

import { MockTokenReturnNull } from "../../mocks/Mocks.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function approve(address asset, address counterparty, uint256 allowance) external;

    function setParValue(address asset, uint256 parValue) external;

    function getAmountOut(address assetIn, address assetOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function getAssetParameters(address asset)
        external
        view
        returns (uint256 parValue, uint8 decimals);

    function getSwapRateLimitKey(address assetIn, address assetOut, address counterparty)
        external
        pure
        returns (bytes32 key);

    function proxy() external view returns (address);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

contract Controller_SwapFacet_Tests is Integration_TestBase {

    IControllerLike internal controller;

    address internal counterparty = makeAddr("counterparty");

    MockTokenReturnNull internal usdt;
    MockTokenReturnNull internal usds;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new SwapFacet());

        vm.label(facet, "SwapFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](5);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.approve.selector,
            ISwapFacet.approve.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerLike.setParValue.selector,
            ISwapFacet.setParValue.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IControllerLike.getAmountOut.selector,
            ISwapFacet.getAmountOut.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IControllerLike.getAssetParameters.selector,
            ISwapFacet.getAssetParameters.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IControllerLike.getSwapRateLimitKey.selector,
            ISwapFacet.getSwapRateLimitKey.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("SWAP_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "SWAP_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);

        usdt = new MockTokenReturnNull("USDT", "USDT", 6);
        usds = new MockTokenReturnNull("USDS", "USDS", 18);
    }

    /**********************************************************************************************/
    /*** approve Tests                                                                          ***/
    /**********************************************************************************************/

    function test_approve_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.approve(address(0), address(0), 0);
    }

    function test_approve_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IFacet.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        controller.approve(address(0), address(0), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFacet.AccessControlUnauthorizedAccount.selector,
                allocator,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(allocator);
        controller.approve(address(0), address(0), 0);
    }

    function test_approve_zeroAsset() external {
        vm.expectRevert("SwapFacet/asset-zero-address");
        vm.prank(admin);
        controller.approve(address(0), counterparty, 1);
    }

    function test_approve_zeroCounterparty() external {
        vm.expectRevert("SwapFacet/counterparty-zero-address");
        vm.prank(admin);
        controller.approve(address(usdt), address(0), 1);
    }

    function test_approve_counterpartyEqualsProxy() external {
        address proxy = controller.proxy();

        vm.expectRevert("SwapFacet/counterparty-equals-proxy");
        vm.prank(admin);
        controller.approve(address(usdt), proxy, 1);
    }

    function test_approve() external {
        address proxy = controller.proxy();

        assertEq(usdt.allowance(proxy, counterparty), 0);

        vm.expectEmit(address(controller));
        emit ISwapFacet.SwapAllowanceSet(address(usdt), counterparty, 1_000_000e6);

        vm.record();

        vm.prank(admin);
        controller.approve(address(usdt), counterparty, 1_000_000e6);

        _assertReentrancyGuardWrittenToTwice(address(controller));

        assertEq(usdt.allowance(proxy, counterparty), 1_000_000e6);

        // Allowance can be rotated and revoked without a zero-reset in between.
        vm.prank(admin);
        controller.approve(address(usdt), counterparty, 2_000_000e6);

        assertEq(usdt.allowance(proxy, counterparty), 2_000_000e6);

        vm.expectEmit(address(controller));
        emit ISwapFacet.SwapAllowanceSet(address(usdt), counterparty, 0);

        vm.prank(admin);
        controller.approve(address(usdt), counterparty, 0);

        assertEq(usdt.allowance(proxy, counterparty), 0);
    }

    function test_approve_standardToken() external {
        ERC20Mock token = new ERC20Mock();

        address proxy = controller.proxy();

        vm.prank(admin);
        controller.approve(address(token), counterparty, 1_000e18);

        assertEq(token.allowance(proxy, counterparty), 1_000e18);
    }

    /**********************************************************************************************/
    /*** setParValue Tests                                                                      ***/
    /**********************************************************************************************/

    function test_setParValue_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setParValue(address(0), 0);
    }

    function test_setParValue_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IFacet.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        controller.setParValue(address(0), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFacet.AccessControlUnauthorizedAccount.selector,
                allocator,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(allocator);
        controller.setParValue(address(0), 0);
    }

    function test_setParValue_zeroAsset() external {
        vm.expectRevert("SwapFacet/asset-zero-address");
        vm.prank(admin);
        controller.setParValue(address(0), 1e18);
    }

    function test_setParValue() external {
        ( uint256 parValue, uint8 decimals ) = controller.getAssetParameters(address(usdt));

        assertEq(parValue, 0);
        assertEq(decimals, 0);

        vm.expectEmit(address(controller));
        emit ISwapFacet.SwapParValueSet(address(usdt), 1e18, 6);

        vm.record();

        vm.prank(admin);
        controller.setParValue(address(usdt), 1e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));

        ( parValue, decimals ) = controller.getAssetParameters(address(usdt));

        assertEq(parValue, 1e18);
        assertEq(decimals, 6);

        // Haircut: one USDT is now worth 0.9 USDS.
        vm.expectEmit(address(controller));
        emit ISwapFacet.SwapParValueSet(address(usdt), 0.9e18, 6);

        vm.prank(admin);
        controller.setParValue(address(usdt), 0.9e18);

        ( parValue, decimals ) = controller.getAssetParameters(address(usdt));

        assertEq(parValue, 0.9e18);
        assertEq(decimals, 6);

        // Zero disables the asset, decimals snapshot is kept.
        vm.expectEmit(address(controller));
        emit ISwapFacet.SwapParValueSet(address(usdt), 0, 6);

        vm.prank(admin);
        controller.setParValue(address(usdt), 0);

        ( parValue, decimals ) = controller.getAssetParameters(address(usdt));

        assertEq(parValue, 0);
        assertEq(decimals, 6);
    }

    /**********************************************************************************************/
    /*** getAmountOut Tests                                                                     ***/
    /**********************************************************************************************/

    function test_getAmountOut_parValueInNotSet() external {
        vm.prank(admin);
        controller.setParValue(address(usds), 1e18);

        vm.expectRevert("SwapFacet/par-value-in-not-set");
        controller.getAmountOut(address(usdt), address(usds), 1e6);
    }

    function test_getAmountOut_parValueOutNotSet() external {
        vm.prank(admin);
        controller.setParValue(address(usdt), 1e18);

        vm.expectRevert("SwapFacet/par-value-out-not-set");
        controller.getAmountOut(address(usdt), address(usds), 1e6);
    }

    function test_getAmountOut_atPar() external {
        vm.startPrank(admin);
        controller.setParValue(address(usdt), 1e18);
        controller.setParValue(address(usds), 1e18);
        vm.stopPrank();

        assertEq(controller.getAmountOut(address(usdt), address(usds), 1_000_000e6),  1_000_000e18);
        assertEq(controller.getAmountOut(address(usds), address(usdt), 1_000_000e18), 1_000_000e6);

        assertEq(controller.getAmountOut(address(usdt), address(usds), 1), 1e12);
        assertEq(controller.getAmountOut(address(usds), address(usdt), 1), 0);  // Rounds down

        assertEq(controller.getAmountOut(address(usds), address(usdt), 1e12 - 1), 0);
        assertEq(controller.getAmountOut(address(usds), address(usdt), 1e12),     1);
    }

    function test_getAmountOut_haircut() external {
        vm.startPrank(admin);
        controller.setParValue(address(usdt), 0.9e18);
        controller.setParValue(address(usds), 1e18);
        vm.stopPrank();

        // 1,000,000 USDT * 0.9 = 900,000 USDS
        assertEq(controller.getAmountOut(address(usdt), address(usds), 1_000_000e6), 900_000e18);

        // 900,000 USDS / 0.9 = 1,000,000 USDT
        assertEq(controller.getAmountOut(address(usds), address(usdt), 900_000e18), 1_000_000e6);

        // 1 USDS / 0.9 = 1.111111 USDT (rounded down)
        assertEq(controller.getAmountOut(address(usds), address(usdt), 1e18), 1.111111e6);
    }

    /**********************************************************************************************/
    /*** getSwapRateLimitKey Tests                                                              ***/
    /**********************************************************************************************/

    function test_getSwapRateLimitKey() external {
        bytes32 keyPrefix = keccak256("LIMIT_SWAP");
        address assetIn   = makeAddr("assetIn");
        address assetOut  = makeAddr("assetOut");

        assertEq(
            controller.getSwapRateLimitKey(assetIn, assetOut, counterparty),
            makeAddressAddressAddressKey(keyPrefix, assetIn, assetOut, counterparty)
        );

        // Direction is part of the key.
        assertTrue(
            controller.getSwapRateLimitKey(assetIn, assetOut, counterparty) !=
            controller.getSwapRateLimitKey(assetOut, assetIn, counterparty)
        );
    }

}
