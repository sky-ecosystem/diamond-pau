// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IBasinFacet } from "../../../src/facets/basin/IBasinFacet.sol";
import { BasinFacet }  from "../../../src/facets/basin/BasinFacet.sol";

import { Controller_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function setDispatch(bytes4 callSelector, address facet, bytes4 delegateSelector) external;

    function basin() external view returns (address);

    function LIMIT_BASIN_DEPOSIT() external pure returns (bytes32);

    function LIMIT_BASIN_WITHDRAW() external pure returns (bytes32);

}

abstract contract BasinFacet_TestBase is Controller_TestBase {

    address internal basinAddress = makeAddr("basin");

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new BasinFacet(basinAddress));

        vm.label(facet, "BasinFacet");

        vm.startPrank(admin);

        controller.setDispatch(
            IControllerLike.basin.selector,
            facet,
            IBasinFacet.basin.selector
        );

        controller.setDispatch(
            IControllerLike.LIMIT_BASIN_DEPOSIT.selector,
            facet,
            IBasinFacet.LIMIT_DEPOSIT.selector
        );

        controller.setDispatch(
            IControllerLike.LIMIT_BASIN_WITHDRAW.selector,
            facet,
            IBasinFacet.LIMIT_WITHDRAW.selector
        );

        vm.stopPrank();
    }

}

contract Controller_BasinFacet_View_Tests is BasinFacet_TestBase {

    function test_basin() external view {
        assertEq(controller.basin(), basinAddress);
    }

    function test_LIMIT_BASIN_DEPOSIT() external view {
        assertEq(controller.LIMIT_BASIN_DEPOSIT(), keccak256("LIMIT_BASIN_DEPOSIT"));
    }

    function test_LIMIT_BASIN_WITHDRAW() external view {
        assertEq(controller.LIMIT_BASIN_WITHDRAW(), keccak256("LIMIT_BASIN_WITHDRAW"));
    }

}
