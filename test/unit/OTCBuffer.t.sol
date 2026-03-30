// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IAccessControl }           from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IAccessControlEnumerable } from "../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";
import { IERC165 }                  from "../../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { ERC1967Proxy } from "../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IOTCBuffer } from "../../src/facets/otc/IOTCBuffer.sol";
import { OTCBuffer }  from "../../src/facets/otc/OTCBuffer.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface IERC20Like {

    function approve(address spender, uint256 amount) external returns (bool);

}

contract OTCBuffer_Tests is UnitTestBase {

    address internal almProxy     = makeAddr("almProxy");
    address internal asset        = makeAddr("asset");
    address internal unauthorized = makeAddr("unauthorized");

    OTCBuffer internal implementation;
    OTCBuffer internal proxy;

    function setUp() public {
        implementation = new OTCBuffer();

        proxy = OTCBuffer(
            address(
                new ERC1967Proxy(
                    address(implementation),
                    abi.encodeCall(OTCBuffer.initialize, (admin, almProxy))
                )
            )
        );
    }

    /**********************************************************************************************/
    /*** initialize Tests                                                                       ***/
    /**********************************************************************************************/

    function test_initialize_invalidAdmin() external {
        vm.expectRevert("OTCBuffer/invalid-admin");
        new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(OTCBuffer.initialize, (address(0), almProxy))
        );
    }

    function test_initialize_invalidAlmProxy() external {
        vm.expectRevert("OTCBuffer/invalid-alm-proxy");
        new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(OTCBuffer.initialize, (admin, address(0)))
        );
    }

    function test_initialize_cannotInitializeTwice() external {
        vm.expectRevert("InvalidInitialization()");
        proxy.initialize(admin, almProxy);
    }

    function test_initialize_cannotInitializeImplementation() external {
        vm.expectRevert("InvalidInitialization()");
        implementation.initialize(admin, almProxy);
    }

    function test_initializedState() external {
        assertEq(proxy.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(proxy.almProxy(),                         almProxy);
    }

    /**********************************************************************************************/
    /*** approve Tests                                                                          ***/
    /**********************************************************************************************/

    function test_approve_notAuthorized() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));
        vm.prank(unauthorized);
        proxy.approve(asset, 1_000_000e6);
    }

    function test_approve() external {
        _expectAndMockCall(
            asset,
            abi.encodeWithSelector(IERC20Like.approve.selector, almProxy, 1_000_000e6),
            abi.encode(true)
        );

        vm.prank(admin);
        proxy.approve(asset, 1_000_000e6);
    }

    /**********************************************************************************************/
    /*** supportsInterface Tests                                                                ***/
    /**********************************************************************************************/

    function test_supportsInterface() external view {
        assertEq(proxy.supportsInterface(type(IOTCBuffer).interfaceId),               true);
        assertEq(proxy.supportsInterface(type(IAccessControlEnumerable).interfaceId), true);
        assertEq(proxy.supportsInterface(type(IAccessControl).interfaceId),           true);
        assertEq(proxy.supportsInterface(type(IERC165).interfaceId),                  true);
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _expectAndMockCall(address callee, bytes memory data, bytes memory returnData)
        internal
    {
        vm.expectCall(callee, data);
        vm.mockCall(callee, data, returnData);
    }

}
