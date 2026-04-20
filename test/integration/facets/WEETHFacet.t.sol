// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Ethereum } from "../../../lib/spark-address-registry/src/Ethereum.sol";

import { WEETHFacet } from "../../../src/facets/weeth/WEETHFacet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

contract Controller_WEETHFacet_Tests is Integration_TestBase {

    function setUp() external {
        vm.createSelectFork(getChain("mainnet").rpcUrl, _getBlock());
    }

    function _getBlock() internal pure returns (uint256) {
        return 24919737; //  April 20, 2026
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor_zeroWEETH() external {
        vm.expectRevert("WEETHFacet/zero-weeth");
        new WEETHFacet(address(0), address(0));
    }

    function test_constructor_zeroWETH() external {
        vm.expectRevert("WEETHFacet/zero-weth");
        new WEETHFacet(makeAddr("weeth"), address(0));
    }

    function test_constructor() external {
        address weeth = Ethereum.WEETH;
        address weth  = makeAddr("weth");

        WEETHFacet facet = new WEETHFacet(weeth, weth);

        assertEq(facet.weeth(), weeth);
        assertEq(facet.weth(),  weth);
    }

}
