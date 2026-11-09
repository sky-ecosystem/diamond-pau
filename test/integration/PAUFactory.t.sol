// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IPAUFactory } from "../../src/interfaces/IPAUFactory.sol";

import { AccessControls }    from "../../src/AccessControls.sol";
import { ALMProxy }          from "../../src/ALMProxy.sol";
import { ALMProxyFreezable } from "../../src/ALMProxyFreezable.sol";
import { Controller }        from "../../src/Controller.sol";
import { RateLimits }        from "../../src/RateLimits.sol";

import { IAccessControls }    from "../../src/interfaces/IAccessControls.sol";
import { IALMProxy }          from "../../src/interfaces/IALMProxy.sol";
import { IALMProxyFreezable } from "../../src/interfaces/IALMProxyFreezable.sol";
import { IController }        from "../../src/interfaces/IController.sol";
import { IRateLimits }        from "../../src/interfaces/IRateLimits.sol";

import { PAUFactory } from "../../src/PAUFactory.sol";

contract PAUFactory_IntegrationTests is Test {

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    bytes32 internal constant DEPLOYMENT_SALT = keccak256("DEPLOYMENT_SALT");

    bytes32 internal constant ALLOCATOR_ROLE       = keccak256("ALLOCATOR_ROLE");
    bytes32 internal constant ALLOCATOR_ADMIN_ROLE = keccak256("ALLOCATOR_ADMIN_ROLE");
    bytes32 internal constant DEFAULT_ADMIN_ROLE   = 0x00;

    address internal admin          = makeAddr("admin");
    address internal allocator      = makeAddr("allocator");
    address internal allocatorAdmin = makeAddr("allocatorAdmin");
    address internal beacon         = makeAddr("beacon");
    address internal deployer       = makeAddr("deployer");
    address internal unauthorized   = makeAddr("unauthorized");

    PAUFactory internal factory;

    /**********************************************************************************************/
    /*** Setup                                                                                  ***/
    /**********************************************************************************************/

    function setUp() external {
        factory = new PAUFactory(beacon);
    }

    /**********************************************************************************************/
    /*** Initial State Tests                                                                    ***/
    /**********************************************************************************************/

    function test_initialState() external {
        assertEq(factory.beacon(), beacon);
    }

    /**********************************************************************************************/
    /*** deployAccessControls Tests                                                             ***/
    /**********************************************************************************************/

    function test_deployAccessControls() external {
        address expectedAccessControls = _getExpectedAccessControls(deployer, admin);

        vm.expectEmit(address(factory));
        emit IPAUFactory.AccessControlsDeployed(expectedAccessControls);

        vm.prank(deployer);
        address accessControls = factory.deployAccessControls(admin, DEPLOYMENT_SALT);

        assertEq(accessControls, expectedAccessControls);

        assertEq(factory.isAccessControls(accessControls), true);

        assertEq(IAccessControls(accessControls).hasRole(DEFAULT_ADMIN_ROLE, admin), true);
    }

    /**********************************************************************************************/
    /*** deployController Tests                                                                 ***/
    /**********************************************************************************************/

    function test_deployController() external {
        address accessControls = makeAddr("accessControls");
        address almProxy       = makeAddr("almProxy");
        address rateLimits     = makeAddr("rateLimits");

        address expectedController = _getExpectedController(deployer, accessControls, almProxy, rateLimits);

        vm.expectEmit(address(factory));
        emit IPAUFactory.ControllerDeployed(expectedController, accessControls, almProxy, rateLimits);

        vm.prank(deployer);
        address controller = factory.deployController(accessControls, almProxy, rateLimits, DEPLOYMENT_SALT);

        assertEq(controller, expectedController);

        assertEq(factory.isController(controller), true);

        assertEq(IController(controller).accessControls(), accessControls);
        assertEq(IController(controller).beacon(),         beacon);
        assertEq(IController(controller).proxy(),          almProxy);
        assertEq(IController(controller).rateLimits(),     rateLimits);
    }

    /**********************************************************************************************/
    /*** deployALMProxy Tests                                                                   ***/
    /**********************************************************************************************/

    function test_deployALMProxy() external {
        address expectedALMProxy = _getExpectedALMProxy(deployer, admin);

        vm.expectEmit(address(factory));
        emit IPAUFactory.ALMProxyDeployed(expectedALMProxy);

        vm.prank(deployer);
        address almProxy = factory.deployALMProxy(admin, DEPLOYMENT_SALT);

        assertEq(almProxy, expectedALMProxy);

        assertEq(factory.isALMProxy(almProxy), true);

        assertEq(IALMProxy(almProxy).hasRole(DEFAULT_ADMIN_ROLE, admin), true);
    }

    /**********************************************************************************************/
    /*** deployALMProxyFreezable Tests                                                          ***/
    /**********************************************************************************************/

    function test_deployALMProxyFreezable() external {
        address expectedALMProxyFreezable = _getExpectedALMProxyFreezable(deployer, admin);

        vm.expectEmit(address(factory));
        emit IPAUFactory.ALMProxyFreezableDeployed(expectedALMProxyFreezable);

        vm.prank(deployer);
        address almProxyFreezable = factory.deployALMProxyFreezable(admin, DEPLOYMENT_SALT);

        assertEq(almProxyFreezable, expectedALMProxyFreezable);

        assertEq(factory.isALMProxyFreezable(almProxyFreezable), true);

        assertEq(IALMProxyFreezable(almProxyFreezable).hasRole(DEFAULT_ADMIN_ROLE, admin), true);
    }

    /**********************************************************************************************/
    /*** deployRateLimits Tests                                                                 ***/
    /**********************************************************************************************/

    function test_deployRateLimits() external {
        address expectedRateLimits = _getExpectedRateLimits(deployer, admin);

        vm.expectEmit(address(factory));
        emit IPAUFactory.RateLimitsDeployed(expectedRateLimits);

        vm.prank(deployer);
        address rateLimits = factory.deployRateLimits(admin, DEPLOYMENT_SALT);

        assertEq(rateLimits, expectedRateLimits);

        assertEq(factory.isRateLimits(rateLimits), true);

        assertEq(IRateLimits(rateLimits).hasRole(DEFAULT_ADMIN_ROLE, admin), true);
    }

    /**********************************************************************************************/
    /*** deployPAU Tests                                                                        ***/
    /**********************************************************************************************/

    function test_deployPAU() external {
        address expectedAlmProxy       = _getExpectedALMProxy(deployer, admin);
        address expectedRateLimits     = _getExpectedRateLimits(deployer, admin);
        address expectedAccessControls = _getExpectedAccessControls(deployer, admin);
        address expectedController     = _getExpectedController(deployer, expectedAccessControls, expectedAlmProxy, expectedRateLimits);

        vm.expectEmit(address(factory));
        emit IPAUFactory.AccessControlsDeployed(expectedAccessControls);

        vm.expectEmit(address(factory));
        emit IPAUFactory.ALMProxyDeployed(expectedAlmProxy);

        vm.expectEmit(address(factory));
        emit IPAUFactory.RateLimitsDeployed(expectedRateLimits);

        vm.expectEmit(address(factory));
        emit IPAUFactory.ControllerDeployed(expectedController, expectedAccessControls, expectedAlmProxy, expectedRateLimits);

        vm.expectEmit(address(factory));
        emit IPAUFactory.PAUDeployed(expectedController);

        vm.prank(deployer);
        address controller = factory.deployPAU(admin, DEPLOYMENT_SALT);

        IAccessControls accessControls = IAccessControls(IController(controller).accessControls());
        IALMProxy       almProxy       = IALMProxy(IController(controller).proxy());
        IRateLimits     rateLimits     = IRateLimits(IController(controller).rateLimits());

        assertEq(address(accessControls), expectedAccessControls);
        assertEq(address(almProxy),       expectedAlmProxy);
        assertEq(controller,              expectedController);
        assertEq(address(rateLimits),     expectedRateLimits);

        // DEFAULT_ADMIN_ROLE granted to admin on all three.

        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE,       admin), true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE,     admin), true);

        // Only one admin member on IAccessControls (ALMProxy and RateLimits ACL is not enumerable).

        assertEq(accessControls.getRoleMember(DEFAULT_ADMIN_ROLE, 0), admin);

        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);

        // Factory has NO DEFAULT_ADMIN_ROLE on any contract.

        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, address(factory)), false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE,       address(factory)), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE,     address(factory)), false);

        // Factory has NO CONTROLLER role on ALMProxy or RateLimits.

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     address(factory)), false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(factory)), false);

        // Admin can grant roles.

        vm.startPrank(admin);

        almProxy.grantRole(almProxy.CONTROLLER(),     controller);
        rateLimits.grantRole(rateLimits.CONTROLLER(), controller);

        accessControls.grantRole(ALLOCATOR_ROLE,       allocator);
        accessControls.grantRole(ALLOCATOR_ADMIN_ROLE, allocatorAdmin);

        // NOTE: In practice the ALLOCATOR_ADMIN_ROLE will be a wrapper module with custom role
        //       logic that calls into AccessControls to perform grants and revocations.
        accessControls.setRoleAdmin(ALLOCATOR_ROLE, ALLOCATOR_ADMIN_ROLE);

        assertEq(accessControls.hasRole(ALLOCATOR_ROLE,       allocator),      true);
        assertEq(accessControls.hasRole(ALLOCATOR_ADMIN_ROLE, allocatorAdmin), true);

        // Admin can grant CONTROLLER role on ALMProxy and RateLimits.

        address newController = makeAddr("newController");

        almProxy.grantRole(almProxy.CONTROLLER(),     newController);
        rateLimits.grantRole(rateLimits.CONTROLLER(), newController);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     newController), true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), true);

        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _getExpectedALMProxy(address deployer_, address admin_) internal view returns (address) {
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(ALMProxy).creationCode, abi.encode(admin_)));

        return computeCreate2Address(_getSalt(deployer_, DEPLOYMENT_SALT), initCodeHash, address(factory));
    }

    function _getExpectedALMProxyFreezable(address deployer_, address admin_) internal view returns (address) {
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(ALMProxyFreezable).creationCode, abi.encode(admin_)));

        return computeCreate2Address(_getSalt(deployer_, DEPLOYMENT_SALT), initCodeHash, address(factory));
    }

    function _getExpectedController(address deployer_, address accessControls_, address almProxy_, address rateLimits_)
        internal
        view
        returns (address)
    {
        bytes32 initCodeHash =
            keccak256(
                abi.encodePacked(
                    type(Controller).creationCode,
                    abi.encode(accessControls_, beacon, almProxy_, rateLimits_)
                )
            );

        return computeCreate2Address(_getSalt(deployer_, DEPLOYMENT_SALT), initCodeHash, address(factory));
    }

    function _getExpectedRateLimits(address deployer_, address admin_) internal view returns (address) {
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(RateLimits).creationCode, abi.encode(admin_)));

        return computeCreate2Address(_getSalt(deployer_, DEPLOYMENT_SALT), initCodeHash, address(factory));
    }

    function _getExpectedAccessControls(address deployer_, address admin_) internal view returns (address) {
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(AccessControls).creationCode, abi.encode(admin_)));

        return computeCreate2Address(_getSalt(deployer_, DEPLOYMENT_SALT), initCodeHash, address(factory));
    }

    function _getSalt(address account, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, salt));
    }

}
