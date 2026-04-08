// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IAccessControl } from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { EnumerableSet }   from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Dispatch, Integration, IntegrationConfig, Wire } from "../../src/interfaces/IntegrationStructs.sol";

import { IBeacon }     from "../../src/interfaces/IBeacon.sol";
import { IController } from "../../src/interfaces/IController.sol";

import { Beacon } from "../../src/Beacon.sol";

interface IMockFacet {

    error MockError(uint256 arg);

    function foo() external;

    function bar(
        address           arg0,
        bool[]     memory arg1,
        bytes32           arg2,
        int256[][] memory arg3,
        uint256           arg4,
        bytes      memory arg5,
        string[]   memory arg6
    )
        external
        returns (
            string[]   memory,
            bytes      memory,
            uint256,
            int256[][] memory,
            bytes32,
            bool[]     memory,
            address
        );

}

interface IMockController {

    function facetFoo() external;

    function facetBar(
        address           arg0,
        bool[]     memory arg1,
        bytes32           arg2,
        int256[][] memory arg3,
        uint256           arg4,
        bytes      memory arg5,
        string[]   memory arg6
    )
        external
        returns (
            string[]   memory,
            bytes      memory,
            uint256,
            int256[][] memory,
            bytes32,
            bool[]     memory,
            address
        );

}

contract BeaconHarness is Beacon {

    using EnumerableSet for EnumerableSet.Bytes32Set;

    constructor(address admin) Beacon(admin) {}

    function __addIntegrationId(bytes32 id) external {
        _integrationIds.add(id);
    }

    function __removeIntegrationId(bytes32 integrationId) external {
        _integrationIds.remove(integrationId);
    }

    function __setIntegrationConfig(bytes32 integrationId, IntegrationConfig memory integrationConfig) external {
        delete _integrationConfigs[integrationId];
        _integrationConfigs[integrationId].facet = integrationConfig.facet;
        uint256 wireCount = integrationConfig.wires.length;
        for (uint256 i = 0; i < wireCount; ++i) {
            _integrationConfigs[integrationId].wires.push(integrationConfig.wires[i]);
        }
    }

    function __removeIntegrationConfig(bytes32 integrationId) external {
        delete _integrationConfigs[integrationId];
    }

    function __setDispatch(bytes4 callSelector, Dispatch memory dispatch) external {
        _dispatches[callSelector] = dispatch;
    }

    function __removeDispatch(bytes4 callSelector) external {
        delete _dispatches[callSelector];
    }

    function __getHasIntegrationId(bytes32 integrationId) external view returns (bool) {
        return _integrationIds.contains(integrationId);
    }

    function __getIntegrationConfig(bytes32 integrationId) external view returns (IntegrationConfig memory) {
        return _integrationConfigs[integrationId];
    }

    function __getDispatch(bytes4 callSelector) external view returns (Dispatch memory) {
        return _dispatches[callSelector];
    }

}

contract Beacon_Tests is Test {

    bytes32 internal constant _REENTRANCY_GUARD_SLOT        = bytes32(uint256(0));
    bytes32 internal constant _REENTRANCY_GUARD_NOT_ENTERED = bytes32(uint256(1));
    bytes32 internal constant _REENTRANCY_GUARD_ENTERED     = bytes32(uint256(2));

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    address internal admin        = makeAddr("admin");
    address internal unauthorized = makeAddr("unauthorized");

    BeaconHarness internal beacon;

    function setUp() external {
        beacon = new BeaconHarness(admin);
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor_zeroAdmin() external {
        vm.expectRevert(IBeacon.ZeroAdmin.selector);
        new BeaconHarness(address(0));
    }

    function test_constructor() external {
        assertEq(beacon.hasRole(DEFAULT_ADMIN_ROLE, admin),     true);
        assertEq(beacon.getRoleMember(DEFAULT_ADMIN_ROLE, 0),   admin);
        assertEq(beacon.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
    }

    /**********************************************************************************************/
    /*** setIntegration Tests                                                                   ***/
    /**********************************************************************************************/

    function test_setIntegration_reentrancy() external {
        vm.store(address(beacon), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        IntegrationConfig memory integrationConfig = IntegrationConfig({
            facet : address(0),
            wires : new Wire[](0)
        });

        beacon.setIntegration("SOME_INTEGRATION", integrationConfig);
    }

    function test_setIntegration_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        IntegrationConfig memory integrationConfig = IntegrationConfig({
            facet : address(0),
            wires : new Wire[](0)
        });

        beacon.setIntegration("SOME_INTEGRATION", integrationConfig);
    }

    function test_setIntegration_zeroFacet() external {
        vm.expectRevert(IBeacon.ZeroFacet.selector);
        vm.prank(admin);
        IntegrationConfig memory integrationConfig = IntegrationConfig({
            facet : address(0),
            wires : new Wire[](0)
        });

        beacon.setIntegration("SOME_INTEGRATION", integrationConfig);
    }

    function test_setIntegration_emptyArray() external {
        vm.expectRevert(IBeacon.EmptyArray.selector);
        vm.prank(admin);
        IntegrationConfig memory integrationConfig = IntegrationConfig({
            facet : makeAddr("facet"),
            wires : new Wire[](0)
        });

        beacon.setIntegration("SOME_INTEGRATION", integrationConfig);
    }

    function test_setIntegration_callSelectorHardcoded() external {
        bytes4[] memory hardcodedCallSelectors = new bytes4[](11);
        hardcodedCallSelectors[0] = IController.updateIntegrations.selector;
        hardcodedCallSelectors[1] = IController.removeIntegrations.selector;
        hardcodedCallSelectors[2] = IController.accessControls.selector;
        hardcodedCallSelectors[3] = IController.beacon.selector;
        hardcodedCallSelectors[4] = IController.integrations.selector;
        hardcodedCallSelectors[5] = IController.proxy.selector;
        hardcodedCallSelectors[6] = IController.rateLimits.selector;
        hardcodedCallSelectors[7] = IBeacon.getIntegrationConfig.selector;
        hardcodedCallSelectors[8] = IBeacon.getIntegrationConfigs.selector;
        hardcodedCallSelectors[9] = IBeacon.getDispatch.selector;
        hardcodedCallSelectors[10] = IBeacon.getDispatches.selector;

        address facet = makeAddr("facet");

        Wire[] memory wires = new Wire[](2);
        wires[0] = Wire(0x12456789, bytes4(0));

        for (uint256 i = 0; i < hardcodedCallSelectors.length; ++i) {
            wires[1] = Wire(hardcodedCallSelectors[i], bytes4(0));

            vm.expectRevert(
                abi.encodeWithSelector(
                    IBeacon.CallSelectorHardcoded.selector,
                    wires[1]
                )
            );

            vm.prank(admin);
            IntegrationConfig memory integrationConfig = IntegrationConfig({
                facet : facet,
                wires : wires
            });

            beacon.setIntegration("SOME_INTEGRATION", integrationConfig);
        }
    }

    function test_setIntegration_callSelectorAlreadyWired() external {
        address facet        = makeAddr("facet");
        bytes4  callSelector = 0x12345678;

        beacon.__setDispatch(callSelector, Dispatch(facet, bytes4(0)));

        Wire[] memory wires = new Wire[](2);
        wires[0] = Wire(callSelector, bytes4(0));
        wires[1] = Wire(0x87654321,   bytes4(0));

        vm.expectRevert(abi.encodeWithSelector(IBeacon.CallSelectorAlreadyWired.selector, callSelector));
        vm.prank(admin);
        IntegrationConfig memory integrationConfig = IntegrationConfig({
            facet : facet,
            wires : wires
        });

        beacon.setIntegration("SOME_INTEGRATION", integrationConfig);

        wires[0] = Wire(0x87654321,   bytes4(0));
        wires[1] = Wire(callSelector, bytes4(0));

        vm.expectRevert(abi.encodeWithSelector(IBeacon.CallSelectorAlreadyWired.selector, callSelector));
        vm.prank(admin);
        integrationConfig = IntegrationConfig({
            facet : facet,
            wires : wires
        });

        beacon.setIntegration("SOME_INTEGRATION", integrationConfig);
    }

    function test_setIntegration() external {
        bytes32 integrationId = "SOME_INTEGRATION";

        beacon.__addIntegrationId(integrationId);

        address oldFacet = makeAddr("oldFacet");

        Wire[] memory oldWires = new Wire[](3);
        oldWires[0] = Wire(0x12345678, 0x11111111);
        oldWires[1] = Wire(0xAAAAAAAA, 0x89ABCDEF);
        oldWires[2] = Wire(0xBBBBBBBB, 0xCCCCCCCC);

        beacon.__setIntegrationConfig(integrationId, IntegrationConfig({
            facet : oldFacet,
            wires : oldWires
        }));

        address facet = makeAddr("facet");

        Wire[] memory wires = new Wire[](2);
        wires[0] = Wire(0x12345678, 0x87654321);
        wires[1] = Wire(0xFEDCBA98, 0x89ABCDEF);

        assertEq(beacon.__getHasIntegrationId(integrationId), true);

        assertEq(beacon.__getIntegrationConfig(integrationId).facet,        oldFacet);
        assertEq(beacon.__getIntegrationConfig(integrationId).wires.length, oldWires.length);

        assertEq(beacon.__getDispatch(oldWires[0].callSelector).facet,            oldFacet);
        assertEq(beacon.__getDispatch(oldWires[0].callSelector).delegateSelector, oldWires[0].delegateSelector);

        assertEq(beacon.__getDispatch(oldWires[1].callSelector).facet,            oldFacet);
        assertEq(beacon.__getDispatch(oldWires[1].callSelector).delegateSelector, oldWires[1].delegateSelector);

        assertEq(beacon.__getDispatch(oldWires[2].callSelector).facet,            oldFacet);
        assertEq(beacon.__getDispatch(oldWires[2].callSelector).delegateSelector, oldWires[2].delegateSelector);

        IntegrationConfig memory newIntegrationConfig = IntegrationConfig({
            facet : facet,
            wires : wires
        });

        vm.expectEmit(address(beacon));
        emit IBeacon.IntegrationSet(integrationId, newIntegrationConfig);

        vm.prank(admin);
        beacon.setIntegration(integrationId, newIntegrationConfig);

        assertEq(beacon.__getHasIntegrationId(integrationId), true);

        assertEq(beacon.__getIntegrationConfig(integrationId).facet,        facet);
        assertEq(beacon.__getIntegrationConfig(integrationId).wires.length, wires.length);

        assertEq(beacon.__getDispatch(wires[0].callSelector).facet,            facet);
        assertEq(beacon.__getDispatch(wires[0].callSelector).delegateSelector, wires[0].delegateSelector);

        assertEq(beacon.__getDispatch(wires[1].callSelector).facet,            facet);
        assertEq(beacon.__getDispatch(wires[1].callSelector).delegateSelector, wires[1].delegateSelector);
    }

    /**********************************************************************************************/
    /*** removeIntegration Tests                                                                ***/
    /**********************************************************************************************/

    function test_removeIntegration_reentrancy() external {
        vm.store(address(beacon), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        beacon.removeIntegration("SOME_INTEGRATION");
    }

    function test_removeIntegration_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.removeIntegration("SOME_INTEGRATION");
    }

    function test_removeIntegration_integrationNotFound() external {
        bytes32 integrationId = "SOME_INTEGRATION";

        vm.expectRevert(abi.encodeWithSelector(IBeacon.IntegrationNotFound.selector, integrationId));
        vm.prank(admin);
        beacon.removeIntegration(integrationId);
    }

    function test_removeIntegration() external {
        bytes32 integrationId = "SOME_INTEGRATION";

        address facet = makeAddr("facet");

        bytes4[] memory callSelectors = new bytes4[](2);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;

        bytes4[] memory delegateSelectors = new bytes4[](2);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;

        Wire[] memory wires = new Wire[](2);
        wires[0] = Wire(callSelectors[0], delegateSelectors[0]);
        wires[1] = Wire(callSelectors[1], delegateSelectors[1]);

        beacon.__addIntegrationId(integrationId);

        beacon.__setIntegrationConfig(integrationId, IntegrationConfig({
            facet : facet,
            wires : wires
        }));

        beacon.__setDispatch(callSelectors[0], Dispatch(facet, delegateSelectors[0]));
        beacon.__setDispatch(callSelectors[1], Dispatch(facet, delegateSelectors[1]));

        assertEq(beacon.__getHasIntegrationId(integrationId), true);

        assertEq(beacon.__getIntegrationConfig(integrationId).facet,        facet);
        assertEq(beacon.__getIntegrationConfig(integrationId).wires.length, wires.length);

        assertEq(beacon.__getDispatch(wires[0].callSelector).facet,            facet);
        assertEq(beacon.__getDispatch(wires[0].callSelector).delegateSelector, wires[0].delegateSelector);

        assertEq(beacon.__getDispatch(wires[1].callSelector).facet,            facet);
        assertEq(beacon.__getDispatch(wires[1].callSelector).delegateSelector, wires[1].delegateSelector);

        vm.expectEmit(address(beacon));
        emit IBeacon.IntegrationRemoved(integrationId);

        vm.prank(admin);
        beacon.removeIntegration(integrationId);

        assertEq(beacon.__getHasIntegrationId(integrationId), false);

        assertEq(beacon.__getIntegrationConfig(integrationId).facet,        address(0));
        assertEq(beacon.__getIntegrationConfig(integrationId).wires.length, 0);

        assertEq(beacon.__getDispatch(wires[0].callSelector).facet,            address(0));
        assertEq(beacon.__getDispatch(wires[0].callSelector).delegateSelector, bytes4(0));

        assertEq(beacon.__getDispatch(wires[1].callSelector).facet,            address(0));
        assertEq(beacon.__getDispatch(wires[1].callSelector).delegateSelector, bytes4(0));
    }

    /**********************************************************************************************/
    /*** integrations Tests                                                                     ***/
    /**********************************************************************************************/

    function test_integrations() external {
        bytes32 integrationId1 = "INTEGRATION_1";
        bytes32 integrationId2 = "INTEGRATION_2";

        address facet1 = makeAddr("facet1");
        address facet2 = makeAddr("facet2");

        Wire[] memory wires1 = new Wire[](1);
        wires1[0] = Wire(0x12345678, 0x87654321);

        Wire[] memory wires2 = new Wire[](2);
        wires2[0] = Wire(0x89ABCDEF, 0xFECDAB98);
        wires2[1] = Wire(0x11111111, 0x33333333);

        beacon.__addIntegrationId(integrationId1);
        beacon.__addIntegrationId(integrationId2);

        beacon.__setIntegrationConfig(integrationId1, IntegrationConfig({
            facet : facet1,
            wires : wires1
        }));
        beacon.__setIntegrationConfig(integrationId2, IntegrationConfig({
            facet : facet2,
            wires : wires2
        }));

        Integration[] memory integrations = beacon.integrations();

        assertEq(integrations.length, 2);

        assertEq(integrations[0].id,                   integrationId1);
        assertEq(integrations[0].config.facet,        facet1);
        assertEq(integrations[0].config.wires.length, wires1.length);

        assertEq(integrations[1].id,                   integrationId2);
        assertEq(integrations[1].config.facet,        facet2);
        assertEq(integrations[1].config.wires.length, wires2.length);

        assertEq(integrations[0].config.wires[0].callSelector,     wires1[0].callSelector);
        assertEq(integrations[0].config.wires[0].delegateSelector, wires1[0].delegateSelector);

        assertEq(integrations[1].config.wires[0].callSelector,     wires2[0].callSelector);
        assertEq(integrations[1].config.wires[0].delegateSelector, wires2[0].delegateSelector);

        assertEq(integrations[1].config.wires[1].callSelector,     wires2[1].callSelector);
        assertEq(integrations[1].config.wires[1].delegateSelector, wires2[1].delegateSelector);
    }

    /**********************************************************************************************/
    /*** getIntegration Tests                                                                   ***/
    /**********************************************************************************************/

    function test_getIntegration() external {
        bytes32 integrationId = "SOME_INTEGRATION";

        address facet = makeAddr("facet");

        bytes4[] memory callSelectors = new bytes4[](3);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;
        callSelectors[2] = 0x11111111;

        bytes4[] memory delegateSelectors = new bytes4[](3);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;
        delegateSelectors[2] = 0x33333333;

        Wire[] memory wires = new Wire[](3);
        wires[0] = Wire(callSelectors[0], delegateSelectors[0]);
        wires[1] = Wire(callSelectors[1], delegateSelectors[1]);
        wires[2] = Wire(callSelectors[2], delegateSelectors[2]);

        beacon.__setIntegrationConfig(integrationId, IntegrationConfig({
            facet : facet,
            wires : wires
        }));

        IntegrationConfig memory integrationConfig = beacon.getIntegrationConfig(integrationId);

        assertEq(integrationConfig.facet,        facet);
        assertEq(integrationConfig.wires.length, wires.length);

        assertEq(integrationConfig.wires[0].callSelector,     callSelectors[0]);
        assertEq(integrationConfig.wires[0].delegateSelector, delegateSelectors[0]);

        assertEq(integrationConfig.wires[1].callSelector,     callSelectors[1]);
        assertEq(integrationConfig.wires[1].delegateSelector, delegateSelectors[1]);

        assertEq(integrationConfig.wires[2].callSelector,     callSelectors[2]);
        assertEq(integrationConfig.wires[2].delegateSelector, delegateSelectors[2]);
    }

    /**********************************************************************************************/
    /*** getIntegrations Tests                                                                  ***/
    /**********************************************************************************************/

    function test_getIntegrations() external {
        bytes32 integrationId1 = "INTEGRATION_1";
        bytes32 integrationId2 = "INTEGRATION_2";

        address facet1 = makeAddr("facet1");
        address facet2 = makeAddr("facet2");

        Wire[] memory wires1 = new Wire[](1);
        wires1[0] = Wire(0x12345678, 0x87654321);

        Wire[] memory wires2 = new Wire[](2);
        wires2[0] = Wire(0x89ABCDEF, 0xFECDAB98);
        wires2[1] = Wire(0x11111111, 0x33333333);

        beacon.__setIntegrationConfig(integrationId1, IntegrationConfig({
            facet : facet1,
            wires : wires1
        }));
        beacon.__setIntegrationConfig(integrationId2, IntegrationConfig({
            facet : facet2,
            wires : wires2
        }));

        bytes32[] memory integrationIds = new bytes32[](2);
        integrationIds[0] = integrationId1;
        integrationIds[1] = integrationId2;

        IntegrationConfig[] memory integrationsConfig = beacon.getIntegrationConfigs(integrationIds);

        assertEq(integrationsConfig.length, 2);

        assertEq(integrationsConfig[0].facet,        facet1);
        assertEq(integrationsConfig[0].wires.length, wires1.length);

        assertEq(integrationsConfig[0].wires[0].callSelector,     wires1[0].callSelector);
        assertEq(integrationsConfig[0].wires[0].delegateSelector, wires1[0].delegateSelector);

        assertEq(integrationsConfig[1].facet,        facet2);
        assertEq(integrationsConfig[1].wires.length, wires2.length);

        assertEq(integrationsConfig[1].wires[0].callSelector,     wires2[0].callSelector);
        assertEq(integrationsConfig[1].wires[0].delegateSelector, wires2[0].delegateSelector);

        assertEq(integrationsConfig[1].wires[1].callSelector,     wires2[1].callSelector);
        assertEq(integrationsConfig[1].wires[1].delegateSelector, wires2[1].delegateSelector);
    }

    /**********************************************************************************************/
    /*** getDispatch Tests                                                                      ***/
    /**********************************************************************************************/

    function test_getDispatch() external {
        bytes4  callSelector     = 0x12345678;
        address facet            = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;
        bytes4  delegateSelector = 0x87654321;

        beacon.__setDispatch(callSelector, Dispatch(facet, delegateSelector));

        Dispatch memory returnedDispatch = beacon.getDispatch(callSelector);

        assertEq(returnedDispatch.facet,            facet);
        assertEq(returnedDispatch.delegateSelector, delegateSelector);
    }

    /**********************************************************************************************/
    /*** getDispatches Tests                                                                    ***/
    /**********************************************************************************************/

    function test_getDispatches() external {
        address[] memory facets = new address[](2);
        facets[0] = makeAddr("facet1");
        facets[1] = makeAddr("facet2");

        bytes4[] memory callSelectors = new bytes4[](3);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;
        callSelectors[2] = 0x11111111;

        bytes4[] memory delegateSelectors = new bytes4[](3);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;
        delegateSelectors[2] = 0x33333333;

        beacon.__setDispatch(callSelectors[0], Dispatch(facets[0], delegateSelectors[0]));
        beacon.__setDispatch(callSelectors[1], Dispatch(facets[1], delegateSelectors[1]));
        beacon.__setDispatch(callSelectors[2], Dispatch(facets[1], delegateSelectors[2]));

        Dispatch[] memory dispatches = beacon.getDispatches(callSelectors);

        assertEq(dispatches.length, 3);

        assertEq(dispatches[0].facet,            facets[0]);
        assertEq(dispatches[0].delegateSelector, delegateSelectors[0]);
        assertEq(dispatches[1].facet,            facets[1]);
        assertEq(dispatches[1].delegateSelector, delegateSelectors[1]);
        assertEq(dispatches[2].facet,            facets[1]);
        assertEq(dispatches[2].delegateSelector, delegateSelectors[2]);
    }

}
