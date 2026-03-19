// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ForeignController } from "../../../src/ForeignController.sol";
import { MainnetController } from "../../../src/MainnetController.sol";
import { AccessControls }    from "../../../src/AccessControls.sol";
import { Parameters }        from "../../../src/Parameters.sol";

import { PSMFacet } from "../../../src/libraries/PSMLib.sol";

import { IPSMFacet } from "../../../src/interfaces/facets/IPSMFacet.sol";

import { IMainnetControllerFull } from "../../interfaces/IMainnetControllerFull.sol";

import { MockDaiUsds } from "../mocks/MockDaiUsds.sol";
import { MockPSM }     from "../mocks/MockPSM.sol";
import { MockPSM3 }    from "../mocks/MockPSM3.sol";
import { MockVault }   from "../mocks/MockVault.sol";

import { UnitTestBase } from "../UnitTestBase.t.sol";

contract MainnetController_Constructor_Tests is UnitTestBase {

    AccessControls         accessControls;
    IMainnetControllerFull mainnetController;
    Parameters             parameters;

    function test_constructor() public {
        address almProxy = makeAddr("almProxy");

        MockDaiUsds daiUsds = new MockDaiUsds(makeAddr("dai"));
        MockPSM     psm     = new MockPSM(makeAddr("usdc"));
        MockVault   vault   = new MockVault(makeAddr("buffer"));

        accessControls = new AccessControls(almProxy);
        parameters     = new Parameters(almProxy);


        mainnetController = IMainnetControllerFull(payable(new MainnetController(
            admin,
            almProxy,
            makeAddr("rateLimits"),
            address(accessControls),
            address(parameters),
            address(vault),
            address(psm),
            address(daiUsds),
            makeAddr("cctp")
        )));

        vm.startPrank(almProxy);

        parameters.grantRole(parameters.CONTROLLER_ROLE(), address(mainnetController));

        _wirePSMFacet(address(psm));

        vm.stopPrank();

        assertEq(mainnetController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(mainnetController.proxy()),      almProxy);
        assertEq(address(mainnetController.rateLimits()), makeAddr("rateLimits"));
        assertEq(address(mainnetController.vault()),      address(vault));
        assertEq(address(mainnetController.buffer()),     makeAddr("buffer"));  // Buffer param in MockVault
        assertEq(address(mainnetController.psm()),        address(psm));
        assertEq(address(mainnetController.daiUsds()),    address(daiUsds));
        assertEq(address(mainnetController.cctp()),       makeAddr("cctp"));
        assertEq(address(mainnetController.dai()),        makeAddr("dai"));   // Dai param in MockDaiUsds
        assertEq(address(mainnetController.usdc()),       makeAddr("usdc"));  // Gem param in MockPSM

        assertEq(mainnetController.psmTo18ConversionFactor(), psm.to18ConversionFactor());
        assertEq(mainnetController.psmTo18ConversionFactor(), 1e12);
    }

    // NOTE: Only wires admin-relevant PSMFacet functions for unit tests.
    function _wirePSMFacet(address psm) internal {
        address psmFacet = address(new PSMFacet(
            makeAddr("dai"),
            makeAddr("dai_usds"),
            psm,
            makeAddr("usdc"),
            makeAddr("usds")
        ));

        vm.label(psmFacet, "PSMFacet");

        mainnetController.setFacet(
            IMainnetControllerFull.psmTo18ConversionFactor.selector,
            psmFacet,
            IPSMFacet.to18ConversionFactor.selector
        );
    }

}

contract ForeignController_Constructor_Tests is UnitTestBase {

    address almProxy   = makeAddr("almProxy");
    address rateLimits = makeAddr("rateLimits");
    address cctp       = makeAddr("cctp");
    address psm        = makeAddr("psm");
    address usdc       = makeAddr("usdc");

    function test_constructor() public {
        ForeignController foreignController = new ForeignController(
            admin,
            almProxy,
            rateLimits,
            makeAddr("accessControls"),
            makeAddr("parameters"),
            psm,
            usdc,
            cctp
        );

        assertEq(foreignController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(foreignController.proxy()),      almProxy);
        assertEq(address(foreignController.rateLimits()), rateLimits);
        assertEq(address(foreignController.psm()),        psm);
        assertEq(address(foreignController.usdc()),       usdc);   // asset1 param in MockPSM3
        assertEq(address(foreignController.cctp()),       cctp);
    }

}
