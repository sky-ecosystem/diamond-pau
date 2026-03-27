// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IAccessControl }  from "../../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { OTCLib } from "../../../src/libraries/OTCLib.sol";

import { MainnetController } from "../../../src/MainnetController.sol";

import { UnitTestBase } from "../UnitTestBase.t.sol";

abstract contract MainnetController_Admin_TestBase is UnitTestBase {

    MainnetController internal mainnetController;

    function setUp() public virtual {
        mainnetController = new MainnetController(
            admin,
            makeAddr("almProxy"),
            makeAddr("rateLimits"),
            makeAddr("accessControls")
        );
    }

    function _setControllerEntered() internal {
        vm.store(address(mainnetController), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);
    }

    function _assertReentrancyGuardWrittenToTwice() internal {
        _assertReentrancyGuardWrittenToTwice(address(mainnetController));
    }

}

contract MainnetController_Admin_SetMaxSlippage_Tests is MainnetController_Admin_TestBase {

    function test_setMaxSlippage_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setMaxSlippage(makeAddr("pool"), 0.98e18);
    }

    function test_setMaxSlippage_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.setMaxSlippage(makeAddr("pool"), 0.98e18);

        vm.prank(freezer);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.setMaxSlippage(makeAddr("pool"), 0.98e18);
    }

    function test_setMaxSlippage_poolZeroAddress() external {
        vm.prank(admin);
        vm.expectRevert("MC/pool-zero-address");
        mainnetController.setMaxSlippage(address(0), 0.98e18);
    }

    function test_setMaxSlippage() external {
        address pool = makeAddr("pool");

        assertEq(mainnetController.maxSlippages(pool), 0);

        vm.prank(admin);
        vm.expectEmit(address(mainnetController));
        emit MainnetController.MaxSlippageSet(pool, 0.98e18);
        mainnetController.setMaxSlippage(pool, 0.98e18);

        assertEq(mainnetController.maxSlippages(pool), 0.98e18);

        vm.record();

        vm.prank(admin);
        vm.expectEmit(address(mainnetController));
        emit MainnetController.MaxSlippageSet(pool, 0.99e18);
        mainnetController.setMaxSlippage(pool, 0.99e18);

        assertEq(mainnetController.maxSlippages(pool), 0.99e18);

        _assertReentrancyGuardWrittenToTwice();
    }

}

contract MainnetController_Admin_SetOTCBuffer_Tests is MainnetController_Admin_TestBase {

    address exchange  = makeAddr("exchange");
    address otcBuffer = makeAddr("otcBuffer");

    function test_setOTCBuffer_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setOTCBuffer(exchange, address(otcBuffer));
    }

    function test_setOTCBuffer_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.setOTCBuffer(exchange, address(otcBuffer));
    }

    function test_setOTCBuffer_exchangeZero() external {
        vm.expectRevert("OTCLib/exchange-zero-address");
        vm.prank(admin);
        mainnetController.setOTCBuffer(address(0), address(otcBuffer));
    }

    function test_setOTCBuffer_otcBufferZero() external {
        vm.expectRevert("OTCLib/otcBuffer-zero-address");
        vm.prank(admin);
        mainnetController.setOTCBuffer(exchange, address(0));
    }

    function test_setOTCBuffer_exchangeEqualsOTCBuffer() external {
        vm.expectRevert("OTCLib/exchange-equals-otcBuffer");
        vm.prank(admin);
        mainnetController.setOTCBuffer(address(otcBuffer), address(otcBuffer));
    }

    function test_setOTCBuffer() external {
        ( address otcBuffer_, , , , ) = mainnetController.otcs(exchange);

        assertEq(otcBuffer_, address(0));

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit OTCLib.OTCBufferSet(exchange, address(otcBuffer));

        vm.prank(admin);
        mainnetController.setOTCBuffer(exchange, address(otcBuffer));

        _assertReentrancyGuardWrittenToTwice();

        ( otcBuffer_, , , , ) = mainnetController.otcs(exchange);

        assertEq(otcBuffer_, address(otcBuffer));
    }

}

contract MainnetController_Admin_SetOTCRechargeRate_Tests is MainnetController_Admin_TestBase {

    address exchange = makeAddr("exchange");

    function test_setOTCRechargeRate_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setOTCRechargeRate(exchange, uint256(1_000_000e18) / 1 days);
    }

    function test_setOTCRechargeRate_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.setOTCRechargeRate(exchange, uint256(1_000_000e18) / 1 days);
    }

    function test_setOTCRechargeRate_exchangeZero() external {
        vm.expectRevert("OTCLib/exchange-zero-address");
        vm.prank(admin);
        mainnetController.setOTCRechargeRate(address(0), uint256(1_000_000e18) / 1 days);
    }

    function test_setOTCRechargeRate() external {
        ( , uint256 rate18, , , ) = mainnetController.otcs(exchange);
        assertEq(rate18, 0);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit OTCLib.OTCRechargeRateSet(exchange, uint256(1_000_000e18) / 1 days);

        vm.prank(admin);
        mainnetController.setOTCRechargeRate(exchange, uint256(1_000_000e18) / 1 days);

        _assertReentrancyGuardWrittenToTwice();

        ( , rate18, , , ) = mainnetController.otcs(exchange);
        assertEq(rate18, uint256(1_000_000e18) / 1 days);
    }

}

contract MainnetController_Admin_SetOTCWhitelistedAsset_Tests is MainnetController_Admin_TestBase {

    address asset    = makeAddr("asset");
    address exchange = makeAddr("exchange");

    function test_setOTCWhitelistedAsset_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setOTCWhitelistedAsset(exchange, asset, true);
    }

    function test_setOTCWhitelistedAsset_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.setOTCWhitelistedAsset(exchange, asset, true);
    }

    function test_setOTCWhitelistedAsset_exchangeZero() external {
        vm.expectRevert("OTCLib/exchange-zero-address");
        vm.prank(admin);
        mainnetController.setOTCWhitelistedAsset(address(0), asset, true);
    }

    function test_setOTCWhitelistedAsset_assetZero() external {
        vm.expectRevert("OTCLib/asset-zero-address");
        vm.prank(admin);
        mainnetController.setOTCWhitelistedAsset(exchange, address(0), true);
    }

    function test_setOTCWhitelistedAsset_otcBufferNotSet() external {
        vm.expectRevert("OTCLib/otc-buffer-not-set");
        vm.prank(admin);
        mainnetController.setOTCWhitelistedAsset(makeAddr("fake-exchange"), asset, true);
    }

    function test_setOTCWhitelistedAsset() external {
        vm.startPrank(admin);

        mainnetController.setOTCBuffer(exchange, asset);

        vm.expectEmit(address(mainnetController));
        emit OTCLib.OTCWhitelistedAssetSet(exchange, asset, true);

        mainnetController.setOTCWhitelistedAsset(exchange, asset, true);

        vm.stopPrank();

        assertEq(mainnetController.otcWhitelistedAssets(exchange, asset), true);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit OTCLib.OTCWhitelistedAssetSet(exchange, asset, false);

        vm.prank(admin);
        mainnetController.setOTCWhitelistedAsset(exchange, asset, false);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.otcWhitelistedAssets(exchange, asset), false);
    }

}
