// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IFacetBase }    from "../../../src/facets/IFacetBase.sol";
import { IERC4626Facet } from "../../../src/facets/erc4626/IERC4626Facet.sol";
import { ERC4626Facet }  from "../../../src/facets/erc4626/ERC4626Facet.sol";

import { IPAURegistry } from "../../../src/interfaces/IPAURegistry.sol";

import { Controller_TestBase } from "../TestBase.t.sol";

interface IControllerLike {
    function setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets) external;

    function getMaxExchangeRate(address token) external view returns (uint256);

}

contract ERC4626Facet_TestBase is Controller_TestBase {

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        vm.startPrank(registryAdmin);

        address facet = address(new ERC4626Facet());

        vm.label(facet, "ERC4626Facet");

        registry.registerFacet("ERC4626Facet", facet);

        IPAURegistry.Wire[] memory wires = new IPAURegistry.Wire[](2);

        wires[0] = IPAURegistry.Wire(
            IControllerLike.setMaxExchangeRate.selector,
            IERC4626Facet.setMaxExchangeRate.selector
        );

        wires[1] = IPAURegistry.Wire(
            IControllerLike.getMaxExchangeRate.selector,
            IERC4626Facet.getMaxExchangeRate.selector
        );

        _addWirings(wires, "ERC4626Facet");

        vm.stopPrank();
    }

}

contract Controller_ERC4626Facet_Admin_Tests is ERC4626Facet_TestBase {

    /**********************************************************************************************/
    /*** setMaxExchangeRate Tests                                                               ***/
    /**********************************************************************************************/

    function test_setMaxExchangeRate_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setMaxExchangeRate(makeAddr("token"), 1e18, 1e18);
    }

    function test_setMaxExchangeRate_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(
            IFacetBase.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));

        vm.prank(unauthorized);
        controller.setMaxExchangeRate(makeAddr("token"), 1e18, 1e18);

        vm.expectRevert(abi.encodeWithSelector(
            IFacetBase.AccessControlUnauthorizedAccount.selector,
            relayer,
            DEFAULT_ADMIN_ROLE
        ));

        vm.prank(relayer);
        controller.setMaxExchangeRate(makeAddr("token"), 1e18, 1e18);
    }

    function test_setMaxExchangeRate_tokenZeroAddress() external {
        vm.expectRevert("ERC4626Facet/token-zero-address");
        vm.prank(admin);
        controller.setMaxExchangeRate(address(0), 1e18, 1e18);
    }

    function test_setMaxExchangeRate() external {
        address token = makeAddr("token");

        assertEq(controller.getMaxExchangeRate(token), 0);

        vm.record();

        vm.expectEmit(address(controller));
        emit IERC4626Facet.ERC4626MaxExchangeRateSet(token, 1e36);

        vm.prank(admin);
        controller.setMaxExchangeRate(token, 1e18, 1e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));

        assertEq(controller.getMaxExchangeRate(token), 1e36);

        vm.expectEmit(address(controller));
        emit IERC4626Facet.ERC4626MaxExchangeRateSet(token, 1e24);

        vm.prank(admin);
        controller.setMaxExchangeRate(token, 1e18, 1e6);

        assertEq(controller.getMaxExchangeRate(token), 1e24);

        vm.expectEmit(address(controller));
        emit IERC4626Facet.ERC4626MaxExchangeRateSet(token, 1e48);

        vm.prank(admin);
        controller.setMaxExchangeRate(token, 1e6, 1e18);

        assertEq(controller.getMaxExchangeRate(token), 1e48);
    }

}
