// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { LayerZeroLib } from "../../../src/libraries/LayerZeroLib.sol";
import { OTCLib }       from "../../../src/libraries/OTCLib.sol";

import { ForeignController } from "../../../src/ForeignController.sol";
import { MainnetController } from "../../../src/MainnetController.sol";

import { UnitTestBase } from "../UnitTestBase.t.sol";

abstract contract MainnetController_Admin_TestBase is UnitTestBase {

    bytes32 internal layerZeroRecipient1 = bytes32(uint256(uint160(makeAddr("layerZeroRecipient1"))));
    bytes32 internal layerZeroRecipient2 = bytes32(uint256(uint160(makeAddr("layerZeroRecipient2"))));

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

contract MainnetController_Admin_SetLayerZeroRecipient_Tests is MainnetController_Admin_TestBase {

    function test_setLayerZeroRecipient_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setLayerZeroRecipient(1, layerZeroRecipient1);
    }

    function test_setLayerZeroRecipient_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.setLayerZeroRecipient(1, layerZeroRecipient1);

        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        vm.prank(freezer);
        mainnetController.setLayerZeroRecipient(1, layerZeroRecipient1);
    }

    function test_setLayerZeroRecipient() external {
        assertEq(mainnetController.layerZeroRecipients(1), bytes32(0));
        assertEq(mainnetController.layerZeroRecipients(2), bytes32(0));

        vm.expectEmit(address(mainnetController));
        emit LayerZeroLib.LayerZeroRecipientSet(1, layerZeroRecipient1);

        vm.prank(admin);
        mainnetController.setLayerZeroRecipient(1, layerZeroRecipient1);

        assertEq(mainnetController.layerZeroRecipients(1), layerZeroRecipient1);

        vm.expectEmit(address(mainnetController));
        emit LayerZeroLib.LayerZeroRecipientSet(2, layerZeroRecipient2);

        vm.prank(admin);
        mainnetController.setLayerZeroRecipient(2, layerZeroRecipient2);

        assertEq(mainnetController.layerZeroRecipients(2), layerZeroRecipient2);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit LayerZeroLib.LayerZeroRecipientSet(1, layerZeroRecipient2);

        vm.prank(admin);
        mainnetController.setLayerZeroRecipient(1, layerZeroRecipient2);

        assertEq(mainnetController.layerZeroRecipients(1), layerZeroRecipient2);

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

contract ForeignController_Admin_Tests is UnitTestBase {

    ForeignController internal foreignController;

    bytes32 layerZeroRecipient1 = bytes32(uint256(uint160(makeAddr("layerZeroRecipient1"))));
    bytes32 layerZeroRecipient2 = bytes32(uint256(uint160(makeAddr("layerZeroRecipient2"))));

    function setUp() public {
        foreignController = new ForeignController(
            admin,
            makeAddr("almProxy"),
            makeAddr("rateLimits"),
            makeAddr("accessControls")
        );
    }

    function _setControllerEntered() internal {
        vm.store(address(foreignController), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);
    }

    function _assertReentrancyGuardWrittenToTwice() internal {
        _assertReentrancyGuardWrittenToTwice(address(foreignController));
    }

    function test_setLayerZeroRecipient_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setLayerZeroRecipient(1, layerZeroRecipient1);
    }

    function test_setLayerZeroRecipient_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        foreignController.setLayerZeroRecipient(1, layerZeroRecipient1);

        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        vm.prank(freezer);
        foreignController.setLayerZeroRecipient(1, layerZeroRecipient1);
    }

    function test_setLayerZeroRecipient() external {
        assertEq(foreignController.layerZeroRecipients(1), bytes32(0));
        assertEq(foreignController.layerZeroRecipients(2), bytes32(0));

        vm.expectEmit(address(foreignController));
        emit LayerZeroLib.LayerZeroRecipientSet(1, layerZeroRecipient1);

        vm.prank(admin);
        foreignController.setLayerZeroRecipient(1, layerZeroRecipient1);

        assertEq(foreignController.layerZeroRecipients(1), layerZeroRecipient1);

        vm.expectEmit(address(foreignController));
        emit LayerZeroLib.LayerZeroRecipientSet(2, layerZeroRecipient2);

        vm.prank(admin);
        foreignController.setLayerZeroRecipient(2, layerZeroRecipient2);

        assertEq(foreignController.layerZeroRecipients(2), layerZeroRecipient2);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit LayerZeroLib.LayerZeroRecipientSet(1, layerZeroRecipient2);

        vm.prank(admin);
        foreignController.setLayerZeroRecipient(1, layerZeroRecipient2);

        assertEq(foreignController.layerZeroRecipients(1), layerZeroRecipient2);

        _assertReentrancyGuardWrittenToTwice();
    }

}
