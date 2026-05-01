// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { ICentrifugeFacet }        from "../../../src/facets/centrifuge/ICentrifugeFacet.sol";
import { IEnumerableIntegrations } from "../../../src/interfaces/IEnumerableIntegrations.sol";
import { IRateLimits }             from "../../../src/interfaces/IRateLimits.sol";

import {
    makeAddressAddressKey,
    makeAddressKey
} from "../../../src/libraries/RateLimitHelpers.sol";

import { CentrifugeFacet } from "../../../src/facets/centrifuge/CentrifugeFacet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

/**********************************************************************************************/
/*** Shared Interfaces                                                                      ***/
/**********************************************************************************************/

interface IControllerLike {

    function setCentrifugeRecipient(uint16 centrifugeId, bytes32 recipient) external;

    function getCentrifugeRecipient(uint16 centrifugeId) external view returns (bytes32);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

interface IControllerRelayerLike {

    function claimCentrifugeCancelDepositRequest(address token) external;

    function claimCentrifugeCancelRedeemRequest(address token) external;

    function proxy() external view returns (address);

    function rateLimits() external view returns (address);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

/**********************************************************************************************/
/*** Admin Base Contract (setRecipient)                                                     ***/
/**********************************************************************************************/

abstract contract CentrifugeFacet_TestBase is Integration_TestBase {

    IControllerLike internal controller;

    bytes32 internal centrifugeRecipient1 = bytes32(uint256(uint160(makeAddr("centrifugeRecipient1"))));
    bytes32 internal centrifugeRecipient2 = bytes32(uint256(uint160(makeAddr("centrifugeRecipient2"))));

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new CentrifugeFacet());

        vm.label(facet, "CentrifugeFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](2);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.setCentrifugeRecipient.selector,
            ICentrifugeFacet.setRecipient.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerLike.getCentrifugeRecipient.selector,
            ICentrifugeFacet.getRecipient.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("CENTRIFUGE_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "CENTRIFUGE_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);
    }

}

/**********************************************************************************************/
/*** setRecipient Tests                                                                     ***/
/**********************************************************************************************/

contract Controller_CentrifugeFacet_SetRecipient_Tests is CentrifugeFacet_TestBase {

    function test_setCentrifugeRecipient_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setCentrifugeRecipient(1, centrifugeRecipient1);
    }

    function test_setCentrifugeRecipient_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));

        vm.prank(unauthorized);
        controller.setCentrifugeRecipient(1, centrifugeRecipient1);
    }

    function test_setCentrifugeRecipient() external {
        assertEq(controller.getCentrifugeRecipient(1), bytes32(0));
        assertEq(controller.getCentrifugeRecipient(2), bytes32(0));

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeRecipientSet(1, centrifugeRecipient1);

        vm.prank(admin);
        controller.setCentrifugeRecipient(1, centrifugeRecipient1);

        assertEq(controller.getCentrifugeRecipient(1), centrifugeRecipient1);

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeRecipientSet(2, centrifugeRecipient2);

        vm.prank(admin);
        controller.setCentrifugeRecipient(2, centrifugeRecipient2);

        assertEq(controller.getCentrifugeRecipient(2), centrifugeRecipient2);

        vm.record();

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeRecipientSet(1, centrifugeRecipient2);

        vm.prank(admin);
        controller.setCentrifugeRecipient(1, centrifugeRecipient2);

        assertEq(controller.getCentrifugeRecipient(1), centrifugeRecipient2);

        _assertReentrancyGuardWrittenToTwice(address(controller));
    }

}

/**********************************************************************************************/
/*** claimCancelDepositRequest Tests                                                        ***/
/**********************************************************************************************/

contract Controller_CentrifugeFacet_ClaimCancelDepositRequest_Tests is Integration_TestBase {

    IControllerRelayerLike internal controller;

    address internal token;
    address internal asset;
    address internal proxy;
    bytes32 internal rateLimitKey;

    function setUp() external {
        controller = IControllerRelayerLike(_deploy());

        CentrifugeFacet facetImpl = new CentrifugeFacet();

        vm.label(address(facetImpl), "CentrifugeFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](2);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerRelayerLike.claimCentrifugeCancelDepositRequest.selector,
            ICentrifugeFacet.claimCancelDepositRequest.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerRelayerLike.claimCentrifugeCancelRedeemRequest.selector,
            ICentrifugeFacet.claimCancelRedeemRequest.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(address(facetImpl), wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("CENTRIFUGE_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "CENTRIFUGE_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);

        token = makeAddr("token");
        asset = makeAddr("asset");
        proxy = controller.proxy();

        // Build the same key as CentrifugeFacet._getDepositRateLimitKey:
        // makeAddressAddressKey(LIMIT_DEPOSIT, token.asset(), token)
        rateLimitKey = makeAddressAddressKey(
            facetImpl.LIMIT_DEPOSIT(),
            asset,
            token
        );

        // Mock token.asset() so the facet can derive the deposit rate limit key
        vm.mockCall(token, abi.encodeWithSignature("asset()"), abi.encode(asset));

        // Set a non-zero maxAmount so _rateLimitExists passes
        vm.prank(admin);
        IRateLimits(controller.rateLimits()).setRateLimitData(rateLimitKey, 1_000_000e6, 0);
    }

    function test_claimCentrifugeCancelDepositRequest_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.claimCentrifugeCancelDepositRequest(token);
    }

    function test_claimCentrifugeCancelDepositRequest_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            RELAYER_ROLE
        ));

        vm.prank(unauthorized);
        controller.claimCentrifugeCancelDepositRequest(token);
    }

    function test_claimCentrifugeCancelDepositRequest_invalidAction() external {
        // Zero out the rate limit so _rateLimitExists reverts
        vm.prank(admin);
        IRateLimits(controller.rateLimits()).setRateLimitData(rateLimitKey, 0, 0);

        vm.expectRevert("CentrifugeFacet/invalid-action");

        vm.prank(relayer);
        controller.claimCentrifugeCancelDepositRequest(token);
    }

    function test_claimCentrifugeCancelDepositRequest() external {
        uint256 assets = 1_000_000e6;

        vm.mockCall(
            token,
            abi.encodeWithSignature(
                "claimCancelDepositRequest(uint256,address,address)",
                uint256(0),
                proxy,
                proxy
            ),
            abi.encode(assets)
        );

        vm.record();

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeClaimCancelDepositRequest(token, assets);

        vm.prank(relayer);
        controller.claimCentrifugeCancelDepositRequest(token);

        _assertReentrancyGuardWrittenToTwice(address(controller));
    }

    function test_claimCentrifugeCancelDepositRequest_differentAmount() external {
        // Regression: confirm the emitted amount matches exactly what the vault returns
        uint256 assets = 500_000e6;

        vm.mockCall(
            token,
            abi.encodeWithSignature(
                "claimCancelDepositRequest(uint256,address,address)",
                uint256(0),
                proxy,
                proxy
            ),
            abi.encode(assets)
        );

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeClaimCancelDepositRequest(token, assets);

        vm.prank(relayer);
        controller.claimCentrifugeCancelDepositRequest(token);
    }

    function test_claimCentrifugeCancelDepositRequest_zeroAssets() external {
        // Boundary: vault returns 0 — event must still carry 0
        vm.mockCall(
            token,
            abi.encodeWithSignature(
                "claimCancelDepositRequest(uint256,address,address)",
                uint256(0),
                proxy,
                proxy
            ),
            abi.encode(uint256(0))
        );

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeClaimCancelDepositRequest(token, 0);

        vm.prank(relayer);
        controller.claimCentrifugeCancelDepositRequest(token);
    }

    function test_claimCentrifugeCancelDepositRequest_maxAssets() external {
        // Boundary: vault returns type(uint256).max — must decode and emit correctly
        uint256 assets = type(uint256).max;

        vm.mockCall(
            token,
            abi.encodeWithSignature(
                "claimCancelDepositRequest(uint256,address,address)",
                uint256(0),
                proxy,
                proxy
            ),
            abi.encode(assets)
        );

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeClaimCancelDepositRequest(token, assets);

        vm.prank(relayer);
        controller.claimCentrifugeCancelDepositRequest(token);
    }

}

/**********************************************************************************************/
/*** claimCancelRedeemRequest Tests                                                         ***/
/**********************************************************************************************/

contract Controller_CentrifugeFacet_ClaimCancelRedeemRequest_Tests is Integration_TestBase {

    IControllerRelayerLike internal controller;

    address internal token;
    address internal proxy;
    bytes32 internal rateLimitKey;

    function setUp() external {
        controller = IControllerRelayerLike(_deploy());

        CentrifugeFacet facetImpl = new CentrifugeFacet();

        vm.label(address(facetImpl), "CentrifugeFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](2);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerRelayerLike.claimCentrifugeCancelDepositRequest.selector,
            ICentrifugeFacet.claimCancelDepositRequest.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerRelayerLike.claimCentrifugeCancelRedeemRequest.selector,
            ICentrifugeFacet.claimCancelRedeemRequest.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(address(facetImpl), wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("CENTRIFUGE_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "CENTRIFUGE_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);

        token = makeAddr("token");
        proxy = controller.proxy();

        // Build the same key as CentrifugeFacet._getRedeemRateLimitKey:
        // makeAddressKey(LIMIT_REDEEM, token)
        rateLimitKey = makeAddressKey(
            facetImpl.LIMIT_REDEEM(),
            token
        );

        // Set a non-zero maxAmount so _rateLimitExists passes
        vm.prank(admin);
        IRateLimits(controller.rateLimits()).setRateLimitData(rateLimitKey, 1_000_000e6, 0);
    }

    function test_claimCentrifugeCancelRedeemRequest_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.claimCentrifugeCancelRedeemRequest(token);
    }

    function test_claimCentrifugeCancelRedeemRequest_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            RELAYER_ROLE
        ));

        vm.prank(unauthorized);
        controller.claimCentrifugeCancelRedeemRequest(token);
    }

    function test_claimCentrifugeCancelRedeemRequest_invalidAction() external {
        // Zero out the rate limit so _rateLimitExists reverts
        vm.prank(admin);
        IRateLimits(controller.rateLimits()).setRateLimitData(rateLimitKey, 0, 0);

        vm.expectRevert("CentrifugeFacet/invalid-action");

        vm.prank(relayer);
        controller.claimCentrifugeCancelRedeemRequest(token);
    }

    function test_claimCentrifugeCancelRedeemRequest() external {
        uint256 shares = 1_000_000e6;

        vm.mockCall(
            token,
            abi.encodeWithSignature(
                "claimCancelRedeemRequest(uint256,address,address)",
                uint256(0),
                proxy,
                proxy
            ),
            abi.encode(shares)
        );

        vm.record();

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeClaimCancelRedeemRequest(token, shares);

        vm.prank(relayer);
        controller.claimCentrifugeCancelRedeemRequest(token);

        _assertReentrancyGuardWrittenToTwice(address(controller));
    }

    function test_claimCentrifugeCancelRedeemRequest_differentAmount() external {
        // Regression: confirm the emitted amount matches exactly what the vault returns
        uint256 shares = 250_000e6;

        vm.mockCall(
            token,
            abi.encodeWithSignature(
                "claimCancelRedeemRequest(uint256,address,address)",
                uint256(0),
                proxy,
                proxy
            ),
            abi.encode(shares)
        );

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeClaimCancelRedeemRequest(token, shares);

        vm.prank(relayer);
        controller.claimCentrifugeCancelRedeemRequest(token);
    }

    function test_claimCentrifugeCancelRedeemRequest_zeroShares() external {
        // Boundary: vault returns 0 — event must still carry 0
        vm.mockCall(
            token,
            abi.encodeWithSignature(
                "claimCancelRedeemRequest(uint256,address,address)",
                uint256(0),
                proxy,
                proxy
            ),
            abi.encode(uint256(0))
        );

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeClaimCancelRedeemRequest(token, 0);

        vm.prank(relayer);
        controller.claimCentrifugeCancelRedeemRequest(token);
    }

    function test_claimCentrifugeCancelRedeemRequest_maxShares() external {
        // Boundary: vault returns type(uint256).max — must decode and emit correctly
        uint256 shares = type(uint256).max;

        vm.mockCall(
            token,
            abi.encodeWithSignature(
                "claimCancelRedeemRequest(uint256,address,address)",
                uint256(0),
                proxy,
                proxy
            ),
            abi.encode(shares)
        );

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeClaimCancelRedeemRequest(token, shares);

        vm.prank(relayer);
        controller.claimCentrifugeCancelRedeemRequest(token);
    }

}
