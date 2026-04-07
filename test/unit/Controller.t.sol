// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IAccessControl }   from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { ReentrancyGuard }  from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IController }  from "../../src/interfaces/IController.sol";
import { IPAURegistry } from "../../src/interfaces/IPAURegistry.sol";

import { Controller } from "../../src/Controller.sol";

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

contract Controller_Tests is Test {

    bytes32 internal constant _REENTRANCY_GUARD_SLOT        = bytes32(uint256(0));
    bytes32 internal constant _REENTRANCY_GUARD_NOT_ENTERED = bytes32(uint256(1));
    bytes32 internal constant _REENTRANCY_GUARD_ENTERED     = bytes32(uint256(2));

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    address internal accessControls = makeAddr("accessControls");
    address internal registry       = makeAddr("registry");
    address internal proxy          = makeAddr("proxy");
    address internal rateLimits     = makeAddr("rateLimits");

    address internal admin        = makeAddr("admin");
    address internal unauthorized = makeAddr("unauthorized");

    Controller internal controller;

    function setUp() external {
        controller = new Controller(accessControls, proxy, rateLimits, registry);
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor() external view {
        assertEq(controller.accessControls(), accessControls);
        assertEq(controller.registry(),       registry);
        assertEq(controller.proxy(),          proxy);
        assertEq(controller.rateLimits(),     rateLimits);
        assertEq(controller.allowAllFacets(), true);
    }

    /**********************************************************************************************/
    /*** optInToFacet Tests                                                                     ***/
    /**********************************************************************************************/

    function test_optInToFacet_reentrancy() external {
        vm.store(address(controller), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.optInToFacet("TestFacet");
    }

    function test_optInToFacet_notAdmin() external {
        _expectAndMockAccessControlCall(unauthorized, false);

        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.optInToFacet("TestFacet");
    }

    function test_optInToFacet_emptyIdentifier() external {
        _expectAndMockAccessControlCall(admin, true);

        vm.expectRevert(IController.EmptyIdentifier.selector);
        vm.prank(admin);
        controller.optInToFacet("");
    }

    function test_optInToFacet() external {
        assertEq(controller.isFacetWhitelisted("TestFacet"), false);

        _expectAndMockAccessControlCall(admin, true);

        vm.expectEmit(address(controller));
        emit IController.FacetOptedIn("TestFacet");

        vm.prank(admin);
        controller.optInToFacet("TestFacet");

        assertEq(controller.isFacetWhitelisted("TestFacet"), true);
    }

    /**********************************************************************************************/
    /*** optInToFacets Tests                                                                    ***/
    /**********************************************************************************************/

    function test_optInToFacets_reentrancy() external {
        vm.store(address(controller), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.optInToFacets(new string[](1));
    }

    function test_optInToFacets_notAdmin() external {
        _expectAndMockAccessControlCall(unauthorized, false);

        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.optInToFacets(new string[](1));
    }

    function test_optInToFacets_emptyArray() external {
        _expectAndMockAccessControlCall(admin, true);

        vm.expectRevert(IController.EmptyArray.selector);
        vm.prank(admin);
        controller.optInToFacets(new string[](0));
    }

    function test_optInToFacets() external {
        string[] memory identifiers = new string[](2);
        identifiers[0] = "FacetA";
        identifiers[1] = "FacetB";

        assertEq(controller.isFacetWhitelisted("FacetA"), false);
        assertEq(controller.isFacetWhitelisted("FacetB"), false);

        _expectAndMockAccessControlCall(admin, true);

        vm.prank(admin);
        controller.optInToFacets(identifiers);

        assertEq(controller.isFacetWhitelisted("FacetA"), true);
        assertEq(controller.isFacetWhitelisted("FacetB"), true);
    }

    /**********************************************************************************************/
    /*** optOutOfFacet Tests                                                                    ***/
    /**********************************************************************************************/

    function test_optOutOfFacet_reentrancy() external {
        vm.store(address(controller), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.optOutOfFacet("TestFacet");
    }

    function test_optOutOfFacet_notAdmin() external {
        _expectAndMockAccessControlCall(unauthorized, false);

        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.optOutOfFacet("TestFacet");
    }

    function test_optOutOfFacet_emptyIdentifier() external {
        _expectAndMockAccessControlCall(admin, true);

        vm.expectRevert(IController.EmptyIdentifier.selector);
        vm.prank(admin);
        controller.optOutOfFacet("");
    }

    function test_optOutOfFacet() external {
        // First opt in
        _expectAndMockAccessControlCall(admin, true);
        vm.prank(admin);
        controller.optInToFacet("TestFacet");

        assertEq(controller.isFacetWhitelisted("TestFacet"), true);

        // Then opt out
        _expectAndMockAccessControlCall(admin, true);

        vm.expectEmit(address(controller));
        emit IController.FacetOptedOut("TestFacet");

        vm.prank(admin);
        controller.optOutOfFacet("TestFacet");

        assertEq(controller.isFacetWhitelisted("TestFacet"), false);
    }

    /**********************************************************************************************/
    /*** optOutOfFacets Tests                                                                   ***/
    /**********************************************************************************************/

    function test_optOutOfFacets_reentrancy() external {
        vm.store(address(controller), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.optOutOfFacets(new string[](1));
    }

    function test_optOutOfFacets_notAdmin() external {
        _expectAndMockAccessControlCall(unauthorized, false);

        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.optOutOfFacets(new string[](1));
    }

    function test_optOutOfFacets_emptyArray() external {
        _expectAndMockAccessControlCall(admin, true);

        vm.expectRevert(IController.EmptyArray.selector);
        vm.prank(admin);
        controller.optOutOfFacets(new string[](0));
    }

    function test_optOutOfFacets() external {
        string[] memory identifiers = new string[](2);
        identifiers[0] = "FacetA";
        identifiers[1] = "FacetB";

        // Opt in first
        _expectAndMockAccessControlCall(admin, true);
        vm.prank(admin);
        controller.optInToFacets(identifiers);

        assertEq(controller.isFacetWhitelisted("FacetA"), true);
        assertEq(controller.isFacetWhitelisted("FacetB"), true);

        // Opt out
        _expectAndMockAccessControlCall(admin, true);
        vm.prank(admin);
        controller.optOutOfFacets(identifiers);

        assertEq(controller.isFacetWhitelisted("FacetA"), false);
        assertEq(controller.isFacetWhitelisted("FacetB"), false);
    }

    /**********************************************************************************************/
    /*** setAllowAllFacets Tests                                                                ***/
    /**********************************************************************************************/

    function test_setAllowAllFacets_reentrancy() external {
        vm.store(address(controller), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setAllowAllFacets(false);
    }

    function test_setAllowAllFacets_notAdmin() external {
        _expectAndMockAccessControlCall(unauthorized, false);

        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.setAllowAllFacets(false);
    }

    function test_setAllowAllFacets() external {
        assertEq(controller.allowAllFacets(), true);

        _expectAndMockAccessControlCall(admin, true);

        vm.expectEmit(address(controller));
        emit IController.AllowAllFacetsSet(false);

        vm.prank(admin);
        controller.setAllowAllFacets(false);

        assertEq(controller.allowAllFacets(), false);
    }

    /**********************************************************************************************/
    /*** getDispatch Tests                                                                      ***/
    /**********************************************************************************************/

    function test_getDispatch() external {
        bytes4  callSelector     = 0x12345678;
        address facet            = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;
        bytes4  delegateSelector = 0x87654321;

        // Mock the registry's getDispatch response
        vm.mockCall(
            registry,
            abi.encodeWithSelector(IPAURegistry.getDispatch.selector, callSelector),
            abi.encode(IPAURegistry.Dispatch(facet, delegateSelector))
        );

        IController.Dispatch memory dispatch = controller.getDispatch(callSelector);

        assertEq(dispatch.facet,            facet);
        assertEq(dispatch.delegateSelector, delegateSelector);
    }

    /**********************************************************************************************/
    /*** Fallback Tests                                                                         ***/
    /**********************************************************************************************/

    function test_fallback_callSelectorNotFound() external {
        // Mock registry returning zero dispatch
        vm.mockCall(
            registry,
            abi.encodeWithSelector(IPAURegistry.getDispatch.selector, IMockController.facetFoo.selector),
            abi.encode(IPAURegistry.Dispatch(address(0), bytes4(0)))
        );

        vm.expectRevert(
            abi.encodeWithSelector(IController.CallSelectorNotWired.selector, IMockController.facetFoo.selector)
        );

        IMockController(address(controller)).facetFoo();
    }

    function test_fallback_facetRevert() external {
        address facet = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;

        vm.mockCall(
            registry,
            abi.encodeWithSelector(IPAURegistry.getDispatch.selector, IMockController.facetFoo.selector),
            abi.encode(IPAURegistry.Dispatch(facet, IMockFacet.foo.selector))
        );

        bytes memory revertData = abi.encodeWithSelector(IMockFacet.MockError.selector, 111222);

        vm.mockCallRevert(
            facet,
            abi.encodeWithSelector(IMockFacet.foo.selector),
            revertData
        );

        vm.expectRevert(revertData);

        IMockController(address(controller)).facetFoo();
    }

    function test_fallback_whitelistEnforced() external {
        address facet = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;

        vm.mockCall(
            registry,
            abi.encodeWithSelector(IPAURegistry.getDispatch.selector, IMockController.facetFoo.selector),
            abi.encode(IPAURegistry.Dispatch(facet, IMockFacet.foo.selector))
        );

        vm.mockCall(
            registry,
            abi.encodeWithSelector(IPAURegistry.getFacetIdentifier.selector, facet),
            abi.encode("TestFacet")
        );

        // Disable allowAllFacets
        _expectAndMockAccessControlCall(admin, true);
        vm.prank(admin);
        controller.setAllowAllFacets(false);

        // Should revert because TestFacet is not whitelisted
        vm.expectRevert(
            abi.encodeWithSelector(
                IController.FacetNotWhitelisted.selector,
                IMockController.facetFoo.selector,
                "TestFacet"
            )
        );

        IMockController(address(controller)).facetFoo();

        // Opt in to TestFacet
        _expectAndMockAccessControlCall(admin, true);
        vm.prank(admin);
        controller.optInToFacet("TestFacet");

        // Mock the delegatecall — now it should succeed
        vm.mockCall(
            facet,
            abi.encodeWithSelector(IMockFacet.foo.selector),
            abi.encode()
        );

        IMockController(address(controller)).facetFoo();
    }

    function test_fallback() external {
        address facet = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;

        // Mock registry response
        vm.mockCall(
            registry,
            abi.encodeWithSelector(IPAURegistry.getDispatch.selector, IMockController.facetBar.selector),
            abi.encode(IPAURegistry.Dispatch(facet, IMockFacet.bar.selector))
        );

        // Prepare inputs and expected outputs
        (bytes memory inputData, bytes memory outputData) = _buildFallbackTestData();

        _expectAndMockCall(facet, inputData, outputData);

        _callAndAssertFallback();
    }

    function _buildFallbackTestData() internal returns (bytes memory inputData, bytes memory outputData) {
        address arg0 = makeAddr("arg0");

        bool[] memory arg1 = new bool[](3);
        arg1[0] = true;
        arg1[1] = false;
        arg1[2] = true;

        bytes32 arg2 = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);

        int256[][] memory arg3 = new int256[][](2);
        arg3[0] = new int256[](3);
        arg3[0][0] = 1;
        arg3[0][1] = -2;
        arg3[0][2] = 3;
        arg3[1] = new int256[](2);
        arg3[1][0] = -4;
        arg3[1][1] = 5;

        uint256 arg4 = 100;
        bytes memory arg5 = abi.encode("hello", "world");

        string[] memory arg6 = new string[](3);
        arg6[0] = "hello";
        arg6[1] = "world";
        arg6[2] = "foobar";

        inputData  = abi.encodeWithSelector(IMockFacet.bar.selector, arg0, arg1, arg2, arg3, arg4, arg5, arg6);
        outputData = abi.encode(arg6, arg5, arg4, arg3, arg2, arg1, arg0);
    }

    function _callAndAssertFallback() internal {
        address arg0 = makeAddr("arg0");

        bool[] memory arg1 = new bool[](3);
        arg1[0] = true;
        arg1[1] = false;
        arg1[2] = true;

        bytes32 arg2 = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);

        int256[][] memory arg3 = new int256[][](2);
        arg3[0] = new int256[](3);
        arg3[0][0] = 1;
        arg3[0][1] = -2;
        arg3[0][2] = 3;
        arg3[1] = new int256[](2);
        arg3[1][0] = -4;
        arg3[1][1] = 5;

        uint256 arg4 = 100;
        bytes memory arg5 = abi.encode("hello", "world");

        string[] memory arg6 = new string[](3);
        arg6[0] = "hello";
        arg6[1] = "world";
        arg6[2] = "foobar";

        (
            string[]   memory resultA,
            bytes      memory resultB,
            uint256           resultC,
            int256[][] memory resultD,
            bytes32           resultE,
            bool[]     memory resultF,
            address           resultG
        ) = IMockController(address(controller)).facetBar(arg0, arg1, arg2, arg3, arg4, arg5, arg6);

        assertEq(resultA.length, arg6.length);
        for (uint256 i; i < arg6.length; ++i) assertEq(resultA[i], arg6[i]);

        assertEq(keccak256(resultB), keccak256(arg5));
        assertEq(resultC, arg4);

        assertEq(resultD.length, arg3.length);
        for (uint256 i; i < arg3.length; ++i) {
            assertEq(resultD[i].length, arg3[i].length);
            for (uint256 j; j < arg3[i].length; ++j) assertEq(resultD[i][j], arg3[i][j]);
        }

        assertEq(resultE, arg2);

        assertEq(resultF.length, arg1.length);
        for (uint256 i; i < arg1.length; ++i) assertEq(resultF[i], arg1[i]);

        assertEq(resultG, arg0);
    }

    /**********************************************************************************************/
    /*** whitelistedFacets Tests                                                                ***/
    /**********************************************************************************************/

    function test_whitelistedFacets_empty() external view {
        string[] memory facets = controller.whitelistedFacets();
        assertEq(facets.length, 0);
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _expectAndMockCall(address callee, bytes memory data, bytes memory returnData) internal {
        vm.expectCall(callee, data);
        vm.mockCall(callee, data, returnData);
    }

    function _expectAndMockAccessControlCall(address account, bool hasAdminRole) internal {
        _expectAndMockCall(
            accessControls,
            abi.encodeWithSelector(
                IAccessControl.hasRole.selector,
                DEFAULT_ADMIN_ROLE,
                account
            ),
            abi.encode(hasAdminRole)
        );
    }

}
