// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IAccessControl } from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IEnumerableIntegrations } from "../../src/interfaces/IEnumerableIntegrations.sol";

import { BeaconConfig } from "../../src/libraries/BeaconConfig.sol";

import { AaveFacet }    from "../../src/facets/aave/AaveFacet.sol";
import { ERC4626Facet } from "../../src/facets/erc4626/ERC4626Facet.sol";

import { Beacon } from "../../src/Beacon.sol";

import { L2BeaconSpell } from "../../deploy/L2BeaconSpell.sol";

// Mirrors L2GovernanceRelay.relay: delegatecalls the spell with the given calldata.
contract MockL2GovernanceRelay {

    function relay(address target, bytes calldata targetData) external {
        (bool success, bytes memory result) = target.delegatecall(targetData);

        if (!success) {
            assembly { revert(add(result, 32), mload(result)) }
        }
    }

}

contract MockFacet {

    function foo() external pure returns (uint256) { return 1; }

}

contract L2BeaconSpell_UnitTests is Test {

    bytes32 constant ID_1 = "INTEGRATION_1";
    bytes32 constant ID_2 = "INTEGRATION_2";
    bytes32 constant ID_3 = "INTEGRATION_3";

    bytes4 constant CALL_SELECTOR_1 = bytes4(keccak256("integration1_foo()"));
    bytes4 constant CALL_SELECTOR_2 = bytes4(keccak256("integration2_foo()"));

    Beacon                beacon;
    L2BeaconSpell         spell;
    MockL2GovernanceRelay relay;

    address facet1;
    address facet2;

    function setUp() external {
        relay  = new MockL2GovernanceRelay();
        beacon = new Beacon(address(relay));
        spell  = new L2BeaconSpell(address(beacon));

        facet1 = address(new MockFacet());
        facet2 = address(new MockFacet());
    }

    function test_constructor() external view {
        assertEq(spell.beacon(), address(beacon));
    }

    /**********************************************************************************************/
    /*** removeAndSetIntegrations Tests                                                         ***/
    /**********************************************************************************************/

    function test_removeAndSetIntegrations_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(spell),
                bytes32(0)
            )
        );
        spell.removeAndSetIntegrations(new bytes32[](0), _integrations(facet1, facet2));
    }

    function test_removeAndSetIntegrations_notAdmin_removeOnly() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(spell),
                bytes32(0)
            )
        );
        spell.removeAndSetIntegrations(_ids(), new IEnumerableIntegrations.Integration[](0));
    }

    function test_removeAndSetIntegrations_empty() external {
        _removeAndSetIntegrations(new bytes32[](0), new IEnumerableIntegrations.Integration[](0));

        assertEq(beacon.integrations().length, 0);
    }

    function test_removeAndSetIntegrations_setOnly() external {
        _setIntegrations(_integrations(facet1, facet2));

        assertEq(beacon.integrations().length, 2);

        _assertIntegration(ID_1, CALL_SELECTOR_1, facet1);
        _assertIntegration(ID_2, CALL_SELECTOR_2, facet2);
    }

    function test_removeAndSetIntegrations_setOnly_upgradesExisting() external {
        _setIntegrations(_integrations(facet1, facet2));

        address newFacet1 = address(new MockFacet());
        address newFacet2 = address(new MockFacet());

        _setIntegrations(_integrations(newFacet1, newFacet2));

        assertEq(beacon.integrations().length, 2);

        _assertIntegration(ID_1, CALL_SELECTOR_1, newFacet1);
        _assertIntegration(ID_2, CALL_SELECTOR_2, newFacet2);
    }

    function test_removeAndSetIntegrations_setOnly_revertsAtomically() external {
        IEnumerableIntegrations.Integration[] memory integrations = _integrations(facet1, facet2);

        // Second integration reuses the first one's call selector.
        integrations[1].config.wires[0].callSelector = CALL_SELECTOR_1;

        vm.expectRevert(
            abi.encodeWithSignature("CallSelectorAlreadyWired(bytes4)", CALL_SELECTOR_1)
        );
        _setIntegrations(integrations);

        assertEq(beacon.integrations().length, 0);
    }

    function test_removeAndSetIntegrations_setOnly_beaconConfigBuilders() external {
        IEnumerableIntegrations.Integration[] memory integrations
            = new IEnumerableIntegrations.Integration[](2);

        integrations[0] = BeaconConfig.buildAaveIntegration(address(new AaveFacet()));
        integrations[1] = BeaconConfig.buildERC4626Integration(address(new ERC4626Facet()));

        _setIntegrations(integrations);

        assertEq(beacon.integrations().length, 2);

        _assertIntegration(integrations[0]);
        _assertIntegration(integrations[1]);

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = BeaconConfig.AAVE_INTEGRATION;
        ids[1] = BeaconConfig.ERC4626_INTEGRATION;

        _removeIntegrations(ids);

        assertEq(beacon.integrations().length, 0);
    }

    function test_removeAndSetIntegrations_removeOnly() external {
        _setIntegrations(_integrations(facet1, facet2));

        _removeIntegrations(_ids());

        assertEq(beacon.integrations().length, 0);

        _assertIntegration(ID_1, CALL_SELECTOR_1, address(0));
        _assertIntegration(ID_2, CALL_SELECTOR_2, address(0));
    }

    function test_removeAndSetIntegrations_removeOnly_notFound() external {
        _setIntegrations(_integrations(facet1, facet2));

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = ID_1;
        ids[1] = "UNKNOWN";

        vm.expectRevert(abi.encodeWithSignature("IntegrationNotFound(bytes32)", bytes32("UNKNOWN")));
        _removeIntegrations(ids);

        // Reverts atomically, so the first removal is rolled back too.
        assertEq(beacon.integrations().length, 2);
    }

    function test_removeAndSetIntegrations_selectorMovesToNewId_withoutRemovalReverts() external {
        _setIntegrations(_single(_integration(ID_1, CALL_SELECTOR_1, facet1)));

        vm.expectRevert(
            abi.encodeWithSignature("CallSelectorAlreadyWired(bytes4)", CALL_SELECTOR_1)
        );
        _setIntegrations(_single(_integration(ID_3, CALL_SELECTOR_1, facet2)));
    }

    function test_removeAndSetIntegrations_selectorMovesToNewId() external {
        _setIntegrations(_single(_integration(ID_1, CALL_SELECTOR_1, facet1)));

        // Removals run before sets, so ID_3 can take over the selector released by ID_1.
        _removeAndSetIntegrations(_single(ID_1), _single(_integration(ID_3, CALL_SELECTOR_1, facet2)));

        assertEq(beacon.integrations().length, 1);

        assertEq(beacon.getConfig(ID_1).facet, address(0));
        _assertIntegration(ID_3, CALL_SELECTOR_1, facet2);
    }

    function test_removeAndSetIntegrations_failingSetRollsBackRemoval() external {
        _setIntegrations(_integrations(facet1, facet2));

        // ID_3 reuses ID_2's selector, which is not being removed.
        vm.expectRevert(
            abi.encodeWithSignature("CallSelectorAlreadyWired(bytes4)", CALL_SELECTOR_2)
        );
        _removeAndSetIntegrations(_single(ID_1), _single(_integration(ID_3, CALL_SELECTOR_2, facet1)));

        assertEq(beacon.integrations().length, 2);

        _assertIntegration(ID_1, CALL_SELECTOR_1, facet1);
        _assertIntegration(ID_2, CALL_SELECTOR_2, facet2);
    }

    function test_removeAndSetIntegrations_failingRemovalRollsBackSet() external {
        _setIntegrations(_single(_integration(ID_1, CALL_SELECTOR_1, facet1)));

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = ID_1;
        ids[1] = "UNKNOWN";

        vm.expectRevert(abi.encodeWithSignature("IntegrationNotFound(bytes32)", bytes32("UNKNOWN")));
        _removeAndSetIntegrations(ids, _single(_integration(ID_2, CALL_SELECTOR_2, facet2)));

        assertEq(beacon.integrations().length, 1);

        _assertIntegration(ID_1, CALL_SELECTOR_1, facet1);
        _assertIntegration(ID_2, CALL_SELECTOR_2, address(0));
    }

    function test_removeAndSetIntegrations_sameIdInBoth() external {
        _setIntegrations(_integrations(facet1, facet2));

        address newFacet1 = address(new MockFacet());

        _removeAndSetIntegrations(_single(ID_1), _single(_integration(ID_1, CALL_SELECTOR_1, newFacet1)));

        assertEq(beacon.integrations().length, 2);

        _assertIntegration(ID_1, CALL_SELECTOR_1, newFacet1);
        _assertIntegration(ID_2, CALL_SELECTOR_2, facet2);
    }

    /**********************************************************************************************/
    /*** Helpers                                                                                ***/
    /**********************************************************************************************/

    function _removeAndSetIntegrations(
        bytes32[]                             memory ids,
        IEnumerableIntegrations.Integration[] memory integrations
    )
        internal
    {
        relay.relay(
            address(spell),
            abi.encodeCall(L2BeaconSpell.removeAndSetIntegrations, (ids, integrations))
        );
    }

    function _setIntegrations(IEnumerableIntegrations.Integration[] memory integrations) internal {
        _removeAndSetIntegrations(new bytes32[](0), integrations);
    }

    function _removeIntegrations(bytes32[] memory ids) internal {
        _removeAndSetIntegrations(ids, new IEnumerableIntegrations.Integration[](0));
    }

    function _integrations(address facet1_, address facet2_)
        internal
        pure
        returns (IEnumerableIntegrations.Integration[] memory integrations)
    {
        integrations = new IEnumerableIntegrations.Integration[](2);

        integrations[0] = _integration(ID_1, CALL_SELECTOR_1, facet1_);
        integrations[1] = _integration(ID_2, CALL_SELECTOR_2, facet2_);
    }

    function _integration(bytes32 id, bytes4 callSelector, address facet)
        internal
        pure
        returns (IEnumerableIntegrations.Integration memory)
    {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](1);

        wires[0] = IEnumerableIntegrations.Wire(callSelector, MockFacet.foo.selector);

        return IEnumerableIntegrations.Integration(
            id,
            IEnumerableIntegrations.Config({ facet : facet, wires : wires })
        );
    }

    function _single(IEnumerableIntegrations.Integration memory integration)
        internal
        pure
        returns (IEnumerableIntegrations.Integration[] memory integrations)
    {
        integrations = new IEnumerableIntegrations.Integration[](1);
        integrations[0] = integration;
    }

    function _single(bytes32 id) internal pure returns (bytes32[] memory ids) {
        ids = new bytes32[](1);
        ids[0] = id;
    }

    function _ids() internal pure returns (bytes32[] memory ids) {
        ids = new bytes32[](2);
        ids[0] = ID_1;
        ids[1] = ID_2;
    }

    function _assertIntegration(bytes32 id, bytes4 callSelector, address facet) internal view {
        assertEq(beacon.getConfig(id).facet,             facet);
        assertEq(beacon.getDispatch(callSelector).facet, facet);
    }

    function _assertIntegration(IEnumerableIntegrations.Integration memory integration)
        internal
        view
    {
        IEnumerableIntegrations.Config memory config = beacon.getConfig(integration.id);

        assertEq(config.facet,        integration.config.facet);
        assertEq(config.wires.length, integration.config.wires.length);

        for (uint256 i = 0; i < integration.config.wires.length; ++i) {
            IEnumerableIntegrations.Wire memory wire = integration.config.wires[i];

            IEnumerableIntegrations.Dispatch memory dispatch
                = beacon.getDispatch(wire.callSelector);

            assertEq(config.wires[i].callSelector,     wire.callSelector);
            assertEq(config.wires[i].delegateSelector, wire.delegateSelector);
            assertEq(dispatch.facet,                   integration.config.facet);
            assertEq(dispatch.delegateSelector,        wire.delegateSelector);
        }
    }

}
