// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Beacon }     from "../../src/Beacon.sol";
import { PAUFactory } from "../../src/PAUFactory.sol";

import { IController }             from "../../src/interfaces/IController.sol";
import { IEnumerableIntegrations } from "../../src/interfaces/IEnumerableIntegrations.sol";

import { PAUInit, PAUInstance } from "../../deploy/PAUInit.sol";

interface IAccessControlLike {
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IALMProxyLike {
    function CONTROLLER() external view returns (bytes32);
}

interface IRateLimitsLike {
    function CONTROLLER() external view returns (bytes32);
}

interface IControllerIntegrationsLike {
    function getConfig(bytes32 id) external view returns (IEnumerableIntegrations.Config memory);
    function integrations() external view returns (IEnumerableIntegrations.Integration[] memory);
}

// Minimal facet stand-in: registering an integration only requires the facet to have code.
contract MockFacet {}

/**
 * @notice Governance-proxy stand-in (PauseProxy / SubProxy) executing a spell action. PAUInit is
 *         internal-functions-only, so it inlines here and executes with this contract as
 *         `msg.sender` / `address(this)` — as it would in a delegatecalled spell. Deployed as the
 *         sole DEFAULT_ADMIN_ROLE holder on every component.
 */
contract GovernanceHarness {

    function initPAU(PAUInstance memory inst, bytes32[] memory integrationIds) external {
        PAUInit.init(inst, integrationIds);
    }

    function addAllocator(PAUInstance memory inst, address agent) external {
        PAUInit.addAllocator(inst, agent);
    }

    function setIntegrations(PAUInstance memory inst, bytes32[] memory ids) external {
        PAUInit.setIntegrations(inst, ids);
    }

    function removeIntegrations(PAUInstance memory inst, bytes32[] memory ids) external {
        PAUInit.removeIntegrations(inst, ids);
    }

}

contract PAUInit_Integration_Tests is Test {

    bytes32 internal constant ALLOCATOR_ROLE     = keccak256("ALLOCATOR_ROLE");
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    GovernanceHarness internal governance;

    Beacon     internal beacon;
    PAUFactory internal factory;

    address internal beaconAdmin;

    // Monotonic source of unique call selectors so registrations never collide on the beacon's
    // global dispatch table.
    uint32 internal wireNonce;

    function setUp() external {
        governance  = new GovernanceHarness();
        beaconAdmin = makeAddr("beaconAdmin");
        beacon      = new Beacon(beaconAdmin);
        factory     = new PAUFactory(address(beacon));
    }

    /**********************************************************************************************/
    /*** Helpers                                                                                ***/
    /**********************************************************************************************/

    // Deploy a fresh stack owned solely by `admin`, WITHOUT the CONTROLLER grants — granting those
    // is exactly what PAUInit.init performs.
    function _deployStack(address admin) internal returns (PAUInstance memory inst) {
        inst.accessControls = factory.deployAccessControls(admin);
        inst.almProxy       = factory.deployALMProxy(admin);
        inst.rateLimits     = factory.deployRateLimits(admin);
        inst.controller     =
            factory.deployController(inst.accessControls, inst.almProxy, inst.rateLimits);
        inst.beacon         = address(beacon);
    }

    // Like `_deployStack`, but with an independent admin per component so individual admin sanity
    // checks in PAUInit.init can be exercised. The Controller's immutable wiring is unaffected.
    function _deployStackWithAdmins(
        address accessControlsAdmin,
        address almProxyAdmin,
        address rateLimitsAdmin
    )
        internal
        returns (PAUInstance memory inst)
    {
        inst.accessControls = factory.deployAccessControls(accessControlsAdmin);
        inst.almProxy       = factory.deployALMProxy(almProxyAdmin);
        inst.rateLimits     = factory.deployRateLimits(rateLimitsAdmin);
        inst.controller     =
            factory.deployController(inst.accessControls, inst.almProxy, inst.rateLimits);
        inst.beacon         = address(beacon);
    }

    function _controllerRoleGranted(address component, address controller)
        internal
        view
        returns (bool)
    {
        return IAccessControlLike(component).hasRole(
            IALMProxyLike(component).CONTROLLER(),
            controller
        );
    }

    // Register `id` on the beacon (as its admin) with a fresh mock facet and a unique wire, so the
    // Controller's updateIntegrations accepts it.
    function _registerIntegration(bytes32 id) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](1);
        wires[0] = IEnumerableIntegrations.Wire(bytes4(++wireNonce), bytes4(bytes32(uint256(0xf))));

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : address(new MockFacet()),
            wires : wires
        });

        vm.prank(beaconAdmin);
        beacon.setIntegration(id, config);
    }

    function _integrationSet(address controller, bytes32 id) internal view returns (bool) {
        return IControllerIntegrationsLike(controller).getConfig(id).facet != address(0);
    }

    /**********************************************************************************************/
    /*** Init Tests                                                                             ***/
    /**********************************************************************************************/

    function test_init_wiresControllerRoles() external {
        PAUInstance memory inst = _deployStack(address(governance));

        // Precondition: the Controller holds no CONTROLLER role yet.
        assertFalse(_controllerRoleGranted(inst.almProxy,   inst.controller));
        assertFalse(_controllerRoleGranted(inst.rateLimits, inst.controller));

        governance.initPAU(inst, new bytes32[](0));

        assertTrue(_controllerRoleGranted(inst.almProxy,   inst.controller));
        assertTrue(_controllerRoleGranted(inst.rateLimits, inst.controller));
    }

    function test_init_emptyIntegrationIds_skipsUpdate() external {
        PAUInstance memory inst = _deployStack(address(governance));

        // With no IDs, init must NOT reach updateIntegrations (the Controller reverts on an empty
        // array), so no integration ends up registered.
        vm.expectCall(
            inst.controller,
            abi.encodeWithSelector(IController.updateIntegrations.selector),
            0
        );

        governance.initPAU(inst, new bytes32[](0));

        assertEq(IControllerIntegrationsLike(inst.controller).integrations().length, 0);
    }

    function test_init_mismatchedAccessControls_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));
        inst.accessControls = makeAddr("wrong");

        vm.expectRevert(bytes("PAUInit/controller-access-controls-mismatch"));
        governance.initPAU(inst, new bytes32[](0));
    }

    function test_init_mismatchedProxy_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));
        inst.almProxy = makeAddr("wrong");

        vm.expectRevert(bytes("PAUInit/controller-proxy-mismatch"));
        governance.initPAU(inst, new bytes32[](0));
    }

    function test_init_mismatchedBeacon_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));
        inst.beacon = makeAddr("wrong");

        vm.expectRevert(bytes("PAUInit/controller-beacon-mismatch"));
        governance.initPAU(inst, new bytes32[](0));
    }

    function test_init_mismatchedRateLimits_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));
        inst.rateLimits = makeAddr("wrong");

        vm.expectRevert(bytes("PAUInit/controller-rate-limits-mismatch"));
        governance.initPAU(inst, new bytes32[](0));
    }

    function test_init_notAdmin_reverts() external {
        // Stack owned by someone else: the harness holds no admin anywhere.
        PAUInstance memory inst = _deployStack(makeAddr("otherAdmin"));

        vm.expectRevert(bytes("PAUInit/not-access-controls-admin"));
        governance.initPAU(inst, new bytes32[](0));
    }

    function test_init_accessControlsNotSoleAdmin_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));

        // Governance is admin, but a second DEFAULT_ADMIN_ROLE holder means it is not the *sole*
        // admin, so init must reject the stack.
        vm.prank(address(governance));
        IAccessControlLike(inst.accessControls).grantRole(DEFAULT_ADMIN_ROLE, makeAddr("secondAdmin"));

        vm.expectRevert(bytes("PAUInit/access-controls-not-sole-admin"));
        governance.initPAU(inst, new bytes32[](0));
    }

    function test_init_notAlmProxyAdmin_reverts() external {
        // Admin on AccessControls but not on the ALMProxy: the second admin check must catch it.
        PAUInstance memory inst = _deployStackWithAdmins(
            address(governance),   // accessControls
            makeAddr("otherAdmin"), // almProxy
            address(governance)    // rateLimits
        );

        vm.expectRevert(bytes("PAUInit/not-alm-proxy-admin"));
        governance.initPAU(inst, new bytes32[](0));
    }

    function test_init_notRateLimitsAdmin_reverts() external {
        // Admin on AccessControls and ALMProxy but not on RateLimits: the third admin check catches it.
        PAUInstance memory inst = _deployStackWithAdmins(
            address(governance),   // accessControls
            address(governance),   // almProxy
            makeAddr("otherAdmin") // rateLimits
        );

        vm.expectRevert(bytes("PAUInit/not-rate-limits-admin"));
        governance.initPAU(inst, new bytes32[](0));
    }

    function test_init_allocatorAgentsPresent_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));

        // Governance is the sole admin everywhere, but an allocator agent has already been granted
        // ALLOCATOR_ROLE on the AccessControls, so init must reject the stack.
        vm.prank(address(governance));
        IAccessControlLike(inst.accessControls).grantRole(ALLOCATOR_ROLE, makeAddr("allocatorAgent"));

        vm.expectRevert(bytes("PAUInit/allocator-agents-present"));
        governance.initPAU(inst, new bytes32[](0));
    }

    function test_init_nonEmptyIntegrationIds_syncsToController() external {
        PAUInstance memory inst = _deployStack(address(governance));

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = "INTEGRATION_1";
        ids[1] = "INTEGRATION_2";
        _registerIntegration(ids[0]);
        _registerIntegration(ids[1]);

        governance.initPAU(inst, ids);

        // Both the structural role wiring and the integration sync happen in one call.
        assertTrue(_controllerRoleGranted(inst.almProxy,   inst.controller));
        assertTrue(_controllerRoleGranted(inst.rateLimits, inst.controller));
        assertTrue(_integrationSet(inst.controller, ids[0]));
        assertTrue(_integrationSet(inst.controller, ids[1]));
        assertEq(IControllerIntegrationsLike(inst.controller).integrations().length, 2);
    }

    /**********************************************************************************************/
    /*** Allocator Tests                                                                        ***/
    /**********************************************************************************************/

    function test_addAllocator_grantsAllocatorRole() external {
        PAUInstance memory inst = _deployStack(address(governance));

        address agent = makeAddr("agent");

        assertFalse(IAccessControlLike(inst.accessControls).hasRole(ALLOCATOR_ROLE, agent));

        governance.addAllocator(inst, agent);

        assertTrue(IAccessControlLike(inst.accessControls).hasRole(ALLOCATOR_ROLE, agent));
    }

    function test_addAllocator_zeroAgent_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));

        vm.expectRevert(bytes("PAUInit/agent-zero-address"));
        governance.addAllocator(inst, address(0));
    }

    function test_addAllocator_mismatchedAccessControls_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));
        // Point the instance at AccessControls the Controller was not wired to; the sanity check
        // must reject the stack before any role is granted.
        inst.accessControls = makeAddr("wrong");

        vm.expectRevert(bytes("PAUInit/controller-access-controls-mismatch"));
        governance.addAllocator(inst, makeAddr("agent"));
    }

    /**********************************************************************************************/
    /*** setIntegrations Tests                                                                  ***/
    /**********************************************************************************************/

    function test_setIntegrations_syncsToController() external {
        PAUInstance memory inst = _deployStack(address(governance));

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = "INTEGRATION_1";
        ids[1] = "INTEGRATION_2";
        _registerIntegration(ids[0]);
        _registerIntegration(ids[1]);

        // Precondition: the Controller knows about neither integration.
        assertFalse(_integrationSet(inst.controller, ids[0]));
        assertFalse(_integrationSet(inst.controller, ids[1]));

        governance.setIntegrations(inst, ids);

        assertTrue(_integrationSet(inst.controller, ids[0]));
        assertTrue(_integrationSet(inst.controller, ids[1]));
        assertEq(IControllerIntegrationsLike(inst.controller).integrations().length, 2);
    }

    function test_setIntegrations_emptyArray_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));

        vm.expectRevert(IController.EmptyArray.selector);
        governance.setIntegrations(inst, new bytes32[](0));
    }

    function test_setIntegrations_unregisteredId_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));

        bytes32[] memory ids = new bytes32[](1);
        ids[0] = "UNKNOWN";

        vm.expectRevert(
            abi.encodeWithSelector(IEnumerableIntegrations.IntegrationNotFound.selector, ids[0])
        );
        governance.setIntegrations(inst, ids);
    }

    function test_setIntegrations_notAdmin_reverts() external {
        // Stack owned by someone else: the harness holds no admin, so the Controller rejects it.
        PAUInstance memory inst = _deployStack(makeAddr("otherAdmin"));

        bytes32[] memory ids = new bytes32[](1);
        ids[0] = "INTEGRATION_1";
        _registerIntegration(ids[0]);

        vm.expectRevert(
            abi.encodeWithSelector(IController.NotAdmin.selector, address(governance))
        );
        governance.setIntegrations(inst, ids);
    }

    /**********************************************************************************************/
    /*** removeIntegrations Tests                                                               ***/
    /**********************************************************************************************/

    function test_removeIntegrations_removesFromController() external {
        PAUInstance memory inst = _deployStack(address(governance));

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = "INTEGRATION_1";
        ids[1] = "INTEGRATION_2";
        _registerIntegration(ids[0]);
        _registerIntegration(ids[1]);

        governance.setIntegrations(inst, ids);

        // Remove only the first; the second must remain.
        bytes32[] memory toRemove = new bytes32[](1);
        toRemove[0] = ids[0];

        governance.removeIntegrations(inst, toRemove);

        assertFalse(_integrationSet(inst.controller, ids[0]));
        assertTrue(_integrationSet(inst.controller, ids[1]));
        assertEq(IControllerIntegrationsLike(inst.controller).integrations().length, 1);
    }

    function test_removeIntegrations_emptyArray_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));

        vm.expectRevert(IController.EmptyArray.selector);
        governance.removeIntegrations(inst, new bytes32[](0));
    }

    function test_removeIntegrations_unsetId_reverts() external {
        PAUInstance memory inst = _deployStack(address(governance));

        bytes32[] memory ids = new bytes32[](1);
        ids[0] = "INTEGRATION_1";

        // Never synced to the Controller, so removal reverts.
        vm.expectRevert(
            abi.encodeWithSelector(IEnumerableIntegrations.IntegrationNotFound.selector, ids[0])
        );
        governance.removeIntegrations(inst, ids);
    }

    function test_removeIntegrations_notAdmin_reverts() external {
        PAUInstance memory inst = _deployStack(makeAddr("otherAdmin"));

        bytes32[] memory ids = new bytes32[](1);
        ids[0] = "INTEGRATION_1";

        vm.expectRevert(
            abi.encodeWithSelector(IController.NotAdmin.selector, address(governance))
        );
        governance.removeIntegrations(inst, ids);
    }

}
