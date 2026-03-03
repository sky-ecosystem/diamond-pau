// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IAccessControl }  from "../../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { CCTPLib }       from "../../../src/libraries/CCTPLib.sol";
import { CentrifugeLib } from "../../../src/libraries/CentrifugeLib.sol";
import { ERC4626Lib }    from "../../../src/libraries/ERC4626Lib.sol";
import { LayerZeroLib }  from "../../../src/libraries/LayerZeroLib.sol";
import { OTCLib }        from "../../../src/libraries/OTCLib.sol";
import { UniswapV3Lib }  from "../../../src/libraries/UniswapV3Lib.sol";
import { UniswapV4Lib }  from "../../../src/libraries/UniswapV4Lib.sol";

import { ForeignController } from "../../../src/ForeignController.sol";
import { MainnetController } from "../../../src/MainnetController.sol";

import { UnitTestBase } from "../UnitTestBase.t.sol";

abstract contract MainnetController_Admin_TestBase is UnitTestBase {

    MainnetController internal mainnetController;

    function setUp() public {
        mainnetController = new MainnetController(admin, makeAddr("almProxy"), makeAddr("rateLimits"));
    }

    function _setControllerEntered() internal {
        vm.store(address(mainnetController), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);
    }

    function _assertReentrancyGuardWrittenToTwice() internal {
        _assertReentrancyGuardWrittenToTwice(address(mainnetController));
    }

}

contract MainnetController_Admin_SetMintRecipient_Tests is MainnetController_Admin_TestBase {

    bytes32 internal immutable mintRecipient1 = bytes32(uint256(uint160(makeAddr("mintRecipient1"))));
    bytes32 internal immutable mintRecipient2 = bytes32(uint256(uint160(makeAddr("mintRecipient2"))));
    address internal immutable _unauthorized  = makeAddr("unauthorized");

    function test_setMintRecipient_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setMintRecipient(1, mintRecipient1);
    }

    function test_setMintRecipient_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setMintRecipient(1, mintRecipient1);
    }

    function test_setMintRecipient() external {
        assertEq(mainnetController.mintRecipients(1), bytes32(0));
        assertEq(mainnetController.mintRecipients(2), bytes32(0));

        vm.expectEmit(address(mainnetController));
        emit CCTPLib.MintRecipientSet(1, mintRecipient1);

        vm.prank(admin);
        mainnetController.setMintRecipient(1, mintRecipient1);

        assertEq(mainnetController.mintRecipients(1), mintRecipient1);

        vm.expectEmit(address(mainnetController));
        emit CCTPLib.MintRecipientSet(2, mintRecipient2);

        vm.prank(admin);
        mainnetController.setMintRecipient(2, mintRecipient2);

        assertEq(mainnetController.mintRecipients(2), mintRecipient2);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit CCTPLib.MintRecipientSet(1, mintRecipient2);

        vm.prank(admin);
        mainnetController.setMintRecipient(1, mintRecipient2);

        assertEq(mainnetController.mintRecipients(1), mintRecipient2);

        _assertReentrancyGuardWrittenToTwice();
    }

}

contract MainnetController_Admin_SetLayerZeroRecipient_Tests is MainnetController_Admin_TestBase {

    bytes32 internal immutable layerZeroRecipient1 = bytes32(uint256(uint160(makeAddr("layerZeroRecipient1"))));
    bytes32 internal immutable layerZeroRecipient2 = bytes32(uint256(uint160(makeAddr("layerZeroRecipient2"))));
    address internal immutable _unauthorized       = makeAddr("unauthorized");

    function test_setLayerZeroRecipient_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setLayerZeroRecipient(1, layerZeroRecipient1);
    }

    function test_setLayerZeroRecipient_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
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

contract MainnetController_Admin_SetMerklDistributor_Tests is MainnetController_Admin_TestBase {

    address internal immutable _unauthorized     = makeAddr("unauthorized");
    address internal immutable _merklDistributor = makeAddr("merklDistributor");

    function test_setMerklDistributor_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setMerklDistributor(_merklDistributor);
    }

    function test_setMerklDistributor_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setMerklDistributor(_merklDistributor);
    }

    function test_setMerklDistributor() external {
        assertEq(mainnetController.merklDistributor(), address(0));

        vm.expectEmit(address(mainnetController));
        emit MainnetController.MerklDistributorSet(_merklDistributor);

        vm.prank(admin);
        mainnetController.setMerklDistributor(_merklDistributor);

        assertEq(mainnetController.merklDistributor(), _merklDistributor);
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

        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        vm.prank(freezer);
        mainnetController.setMaxSlippage(makeAddr("pool"), 0.98e18);
    }

    function test_setMaxSlippage_poolZeroAddress() external {
        vm.expectRevert("MC/pool-zero-address");
        vm.prank(admin);
        mainnetController.setMaxSlippage(address(0), 0.98e18);
    }

    function test_setMaxSlippage() external {
        address pool = makeAddr("pool");

        assertEq(mainnetController.maxSlippages(pool), 0);

        vm.expectEmit(address(mainnetController));
        emit MainnetController.MaxSlippageSet(pool, 0.98e18);

        vm.prank(admin);
        mainnetController.setMaxSlippage(pool, 0.98e18);

        assertEq(mainnetController.maxSlippages(pool), 0.98e18);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit MainnetController.MaxSlippageSet(pool, 0.99e18);

        vm.prank(admin);
        mainnetController.setMaxSlippage(pool, 0.99e18);

        assertEq(mainnetController.maxSlippages(pool), 0.99e18);

        _assertReentrancyGuardWrittenToTwice();
    }

}

contract MainnetController_Admin_SetPendleRouter_Tests is MainnetController_Admin_TestBase {

    address internal immutable _pendleRouter = makeAddr("pendleRouter");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setPendleRouter_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setPendleRouter(_pendleRouter);
    }

    function test_setPendleRouter_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setPendleRouter(_pendleRouter);
    }

    function test_setPendleRouter() external {
        assertEq(mainnetController.pendleRouter(), address(0));

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit MainnetController.PendleRouterSet(_pendleRouter);

        vm.prank(admin);
        mainnetController.setPendleRouter(_pendleRouter);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.pendleRouter(), _pendleRouter);
    }

}

contract MainnetController_Admin_SetOTCBuffer_Tests is MainnetController_Admin_TestBase {

    address internal immutable _exchange     = makeAddr("exchange");
    address internal immutable _otcBuffer    = makeAddr("otcBuffer");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setOTCBuffer_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setOTCBuffer(_exchange, _otcBuffer);
    }

    function test_setOTCBuffer_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setOTCBuffer(_exchange, _otcBuffer);
    }

    function test_setOTCBuffer_exchangeZero() external {
        vm.expectRevert("OTCLib/exchange-zero-address");
        vm.prank(admin);
        mainnetController.setOTCBuffer(address(0), _otcBuffer);
    }

    function test_setOTCBuffer_otcBufferZero() external {
        vm.expectRevert("OTCLib/otcBuffer-zero-address");
        vm.prank(admin);
        mainnetController.setOTCBuffer(_exchange, address(0));
    }

    function test_setOTCBuffer_exchangeEqualsOTCBuffer() external {
        vm.expectRevert("OTCLib/exchange-equals-otcBuffer");
        vm.prank(admin);
        mainnetController.setOTCBuffer(_otcBuffer, _otcBuffer);
    }

    function test_setOTCBuffer() external {
        ( address otcBuffer_, , , , ) = mainnetController.otcs(_exchange);

        assertEq(otcBuffer_, address(0));

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit OTCLib.OTCBufferSet(_exchange, _otcBuffer);

        vm.prank(admin);
        mainnetController.setOTCBuffer(_exchange, _otcBuffer);

        _assertReentrancyGuardWrittenToTwice();

        ( otcBuffer_, , , , ) = mainnetController.otcs(_exchange);

        assertEq(otcBuffer_, _otcBuffer);
    }

}

contract MainnetController_Admin_SetOTCRechargeRate_Tests is MainnetController_Admin_TestBase {

    address internal immutable _exchange     = makeAddr("exchange");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setOTCRechargeRate_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setOTCRechargeRate(_exchange, uint256(1_000_000e18) / 1 days);
    }

    function test_setOTCRechargeRate_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setOTCRechargeRate(_exchange, uint256(1_000_000e18) / 1 days);
    }

    function test_setOTCRechargeRate_exchangeZero() external {
        vm.expectRevert("OTCLib/exchange-zero-address");
        vm.prank(admin);
        mainnetController.setOTCRechargeRate(address(0), uint256(1_000_000e18) / 1 days);
    }

    function test_setOTCRechargeRate() external {
        ( , uint256 rate18, , , ) = mainnetController.otcs(_exchange);
        assertEq(rate18, 0);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit OTCLib.OTCRechargeRateSet(_exchange, uint256(1_000_000e18) / 1 days);

        vm.prank(admin);
        mainnetController.setOTCRechargeRate(_exchange, uint256(1_000_000e18) / 1 days);

        _assertReentrancyGuardWrittenToTwice();

        ( , rate18, , , ) = mainnetController.otcs(_exchange);
        assertEq(rate18, uint256(1_000_000e18) / 1 days);
    }

}

contract MainnetController_Admin_SetOTCWhitelistedAsset_Tests is MainnetController_Admin_TestBase {

    address internal immutable _asset        = makeAddr("asset");
    address internal immutable _exchange     = makeAddr("exchange");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setOTCWhitelistedAsset_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setOTCWhitelistedAsset(_exchange, _asset, true);
    }

    function test_setOTCWhitelistedAsset_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setOTCWhitelistedAsset(_exchange, _asset, true);
    }

    function test_setOTCWhitelistedAsset_exchangeZero() external {
        vm.expectRevert("OTCLib/exchange-zero-address");
        vm.prank(admin);
        mainnetController.setOTCWhitelistedAsset(address(0), _asset, true);
    }

    function test_setOTCWhitelistedAsset_assetZero() external {
        vm.expectRevert("OTCLib/asset-zero-address");
        vm.prank(admin);
        mainnetController.setOTCWhitelistedAsset(_exchange, address(0), true);
    }

    function test_setOTCWhitelistedAsset_otcBufferNotSet() external {
        vm.expectRevert("OTCLib/otc-buffer-not-set");
        vm.prank(admin);
        mainnetController.setOTCWhitelistedAsset(makeAddr("fake-exchange"), _asset, true);
    }

    function test_setOTCWhitelistedAsset() external {
        vm.startPrank(admin);

        mainnetController.setOTCBuffer(_exchange, _asset);

        vm.expectEmit(address(mainnetController));
        emit OTCLib.OTCWhitelistedAssetSet(_exchange, _asset, true);

        mainnetController.setOTCWhitelistedAsset(_exchange, _asset, true);

        assertEq(mainnetController.otcWhitelistedAssets(_exchange, _asset), true);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit OTCLib.OTCWhitelistedAssetSet(_exchange, _asset, false);

        mainnetController.setOTCWhitelistedAsset(_exchange, _asset, false);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.otcWhitelistedAssets(_exchange, _asset), false);

        vm.stopPrank();
    }

}

contract MainnetController_Admin_SetMaxExchangeRate_Tests is MainnetController_Admin_TestBase {

    address internal immutable _unauthorized = makeAddr("unauthorized");
    address internal immutable _token        = makeAddr("token");

    function test_setMaxExchangeRate_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setMaxExchangeRate(_token, 1e18, 1e18);
    }

    function test_setMaxExchangeRate_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setMaxExchangeRate(_token, 1e18, 1e18);
    }

    function test_setMaxExchangeRate_tokenZeroAddress() external {
        vm.expectRevert("ERC4626Lib/token-zero-address");
        vm.prank(admin);
        mainnetController.setMaxExchangeRate(address(0), 1e18, 1e18);
    }

    function test_setMaxExchangeRate() external {
        assertEq(mainnetController.maxExchangeRates(_token), 0);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit ERC4626Lib.MaxExchangeRateSet(_token, 1e36);

        vm.prank(admin);
        mainnetController.setMaxExchangeRate(_token, 1e18, 1e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.maxExchangeRates(_token), 1e36);

        vm.expectEmit(address(mainnetController));
        emit ERC4626Lib.MaxExchangeRateSet(_token, 1e24);

        vm.prank(admin);
        mainnetController.setMaxExchangeRate(_token, 1e18, 1e6);

        assertEq(mainnetController.maxExchangeRates(_token), 1e24);

        vm.expectEmit(address(mainnetController));
        emit ERC4626Lib.MaxExchangeRateSet(_token, 1e48);

        vm.prank(admin);
        mainnetController.setMaxExchangeRate(_token, 1e6, 1e18);

        assertEq(mainnetController.maxExchangeRates(_token), 1e48);
    }

}

contract MainnetController_Admin_SetUniswapV3PositionManager_Tests is MainnetController_Admin_TestBase {

    address internal immutable _positionManager = makeAddr("positionManager");
    address internal immutable _unauthorized    = makeAddr("unauthorized");

    function test_setUniswapV3PositionManager_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setUniswapV3PositionManager(_positionManager);
    }

    function test_setUniswapV3PositionManager_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setUniswapV3PositionManager(_positionManager);
    }

    function test_setUniswapV3PositionManager() external {
        assertEq(mainnetController.uniswapV3PositionManager(), address(0));

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit MainnetController.UniswapV3PositionManagerSet(_positionManager);

        vm.prank(admin);
        mainnetController.setUniswapV3PositionManager(_positionManager);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.uniswapV3PositionManager(), _positionManager);
    }

}

contract MainnetController_Admin_SetUniswapV3SwapRouter_Tests is MainnetController_Admin_TestBase {

    address internal immutable _swapRouter   = makeAddr("swapRouter");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setUniswapV3SwapRouter_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setUniswapV3SwapRouter(_swapRouter);
    }

    function test_setUniswapV3SwapRouter_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setUniswapV3SwapRouter(_swapRouter);
    }

    function test_setUniswapV3SwapRouter() external {
        assertEq(mainnetController.uniswapV3Router(), address(0));

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit MainnetController.UniswapV3SwapRouterSet(_swapRouter);

        vm.prank(admin);
        mainnetController.setUniswapV3SwapRouter(_swapRouter);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.uniswapV3Router(), _swapRouter);
    }

}

contract MainnetController_Admin_SetUniswapV3PoolMaxTickDelta_Tests is MainnetController_Admin_TestBase {

    uint24 internal constant _MAX_TICK_DELTA = 887_272;

    address internal immutable _pool         = makeAddr("pool");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setUniswapV3PoolMaxTickDelta_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setUniswapV3PoolMaxTickDelta(_pool, 10);
    }

    function test_setUniswapV3PoolMaxTickDelta_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setUniswapV3PoolMaxTickDelta(_pool, 1000);
    }

    function test_setUniswapV3PoolMaxTickDelta_outOfBoundsBoundary() external {
        vm.expectRevert("UniswapV3Lib/max-tick-delta-oob");
        vm.prank(admin);
        mainnetController.setUniswapV3PoolMaxTickDelta(_pool, 0);

        vm.expectRevert("UniswapV3Lib/max-tick-delta-oob");
        vm.prank(admin);
        mainnetController.setUniswapV3PoolMaxTickDelta(_pool, _MAX_TICK_DELTA + 1);

        // Can set at boundary

        vm.prank(admin);
        mainnetController.setUniswapV3PoolMaxTickDelta(_pool, 1);

        vm.prank(admin);
        mainnetController.setUniswapV3PoolMaxTickDelta(_pool, _MAX_TICK_DELTA);
    }

    function test_setUniswapV3PoolMaxTickDelta() external {
        ( uint24 maxTickDelta, , ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(maxTickDelta, 0);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit UniswapV3Lib.UniswapV3PoolMaxTickDeltaSet(_pool, 1000);

        vm.prank(admin);
        mainnetController.setUniswapV3PoolMaxTickDelta(_pool, 1000);

        _assertReentrancyGuardWrittenToTwice();

        ( maxTickDelta, , ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(maxTickDelta, 1000);
    }

}

contract MainnetController_Admin_SetUniswapV3AddLiquidityLowerTickBound_Tests is MainnetController_Admin_TestBase {

    int24 internal constant _MIN_UNISWAP_TICK = -887_272;

    address internal immutable _pool         = makeAddr("pool");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setUniswapV3AddLiquidityLowerTickBound_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setUniswapV3AddLiquidityLowerTickBound(_pool, 100);
    }

    function test_setUniswapV3AddLiquidityLowerTickBound_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setUniswapV3AddLiquidityLowerTickBound(_pool, 100);
    }

    function test_setUniswapV3AddLiquidityLowerTickBound_outOfBoundsBoundary() external {
        vm.expectRevert("UniswapV3Lib/lower-tick-oob");
        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityLowerTickBound(_pool, _MIN_UNISWAP_TICK - 1);

        // First set an upper tick bound
        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityUpperTickBound(_pool, 1000);

        // Try to set lower tick at the upper tick
        vm.expectRevert("UniswapV3Lib/lower-tick-oob");
        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityLowerTickBound(_pool, 1000);

        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityLowerTickBound(_pool, _MIN_UNISWAP_TICK);

        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityLowerTickBound(_pool, 999);
    }

    function test_setUniswapV3AddLiquidityLowerTickBound() external {
        // First set an upper tick bound so we have room to set lower
        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityUpperTickBound(_pool, 5000);

        ( , UniswapV3Lib.Ticks memory tickBounds, ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.lower, 0);
        assertEq(tickBounds.upper, 5000);

        vm.expectEmit(address(mainnetController));
        emit UniswapV3Lib.UniswapV3PoolLowerTickUpdated(_pool, -1000);

        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityLowerTickBound(_pool, -1000);

        ( , tickBounds, ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.lower, -1000);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit UniswapV3Lib.UniswapV3PoolLowerTickUpdated(_pool, _MIN_UNISWAP_TICK);

        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityLowerTickBound(_pool, _MIN_UNISWAP_TICK);

        _assertReentrancyGuardWrittenToTwice();

        ( , tickBounds, ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.lower, _MIN_UNISWAP_TICK);
    }

}

contract MainnetController_Admin_SetUniswapV3AddLiquidityUpperTickBound_Tests is MainnetController_Admin_TestBase {

    int24 internal constant _MAX_UNISWAP_TICK = 887_272;

    address internal immutable _pool         = makeAddr("pool");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setUniswapV3AddLiquidityUpperTickBound_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setUniswapV3AddLiquidityUpperTickBound(_pool, 100);
    }

    function test_setUniswapV3AddLiquidityUpperTickBound_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setUniswapV3AddLiquidityUpperTickBound(_pool, 100);
    }

    function test_setUniswapV3AddLiquidityUpperTickBound_outOfBoundsBoundary() external {
        vm.expectRevert("UniswapV3Lib/upper-tick-oob");
        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityUpperTickBound(_pool, _MAX_UNISWAP_TICK + 1);

        vm.expectRevert("UniswapV3Lib/upper-tick-oob");
        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityUpperTickBound(_pool, 0); // Current lower tick is 0

        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityUpperTickBound(_pool, _MAX_UNISWAP_TICK);

        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityUpperTickBound(_pool, 1);
    }

    function test_setUniswapV3AddLiquidityUpperTickBound() external {
        ( , UniswapV3Lib.Ticks memory tickBounds, ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.lower, 0);
        assertEq(tickBounds.upper, 0);

        vm.expectEmit(address(mainnetController));
        emit UniswapV3Lib.UniswapV3PoolUpperTickUpdated(_pool, 1000);

        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityUpperTickBound(_pool, 1000);

        ( , tickBounds, ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.lower, 0);
        assertEq(tickBounds.upper, 1000);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit UniswapV3Lib.UniswapV3PoolUpperTickUpdated(_pool, _MAX_UNISWAP_TICK);

        vm.prank(admin);
        mainnetController.setUniswapV3AddLiquidityUpperTickBound(_pool, _MAX_UNISWAP_TICK);

        _assertReentrancyGuardWrittenToTwice();

        ( , tickBounds, ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.upper, _MAX_UNISWAP_TICK);
    }

}

contract MainnetController_Admin_SetUniswapV3TWAPSecondsAgo_Tests is MainnetController_Admin_TestBase {

    address internal immutable _pool         = makeAddr("pool");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setUniswapV3TWAPSecondsAgo_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setUniswapV3TWAPSecondsAgo(_pool, 100);
    }

    function test_setUniswapV3TWAPSecondsAgo_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setUniswapV3TWAPSecondsAgo(_pool, 300);
    }

    function test_setUniswapV3TWAPSecondsAgo_outOfBoundsBoundary() external {
        vm.expectRevert("UniswapV3Lib/twap-seconds-ago-oob");
        vm.prank(admin);
        mainnetController.setUniswapV3TWAPSecondsAgo(_pool, uint32(type(int32).max));

        vm.prank(admin);
        mainnetController.setUniswapV3TWAPSecondsAgo(_pool, uint32(type(int32).max) - 1);
    }

    function test_setUniswapV3TWAPSecondsAgo() external {
        ( , , uint32 twapSecondsAgo ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(twapSecondsAgo, 0);

        vm.expectEmit(address(mainnetController));
        emit UniswapV3Lib.UniswapV3PoolTWAPSecondsAgoUpdated(_pool, 300);

        vm.prank(admin);
        mainnetController.setUniswapV3TWAPSecondsAgo(_pool, 300);

        ( , , twapSecondsAgo ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(twapSecondsAgo, 300);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit UniswapV3Lib.UniswapV3PoolTWAPSecondsAgoUpdated(_pool, 1800);

        vm.prank(admin);
        mainnetController.setUniswapV3TWAPSecondsAgo(_pool, 1800);

        _assertReentrancyGuardWrittenToTwice();

        ( , , twapSecondsAgo ) = mainnetController.uniswapV3PoolParams(_pool);

        assertEq(twapSecondsAgo, 1800);
    }

}

contract MainnetController_Admin_SetUniswapV4TickLimits_Tests is MainnetController_Admin_TestBase {

    bytes32 internal constant _POOL_ID = 0x8aa4e11cbdf30eedc92100f4c8a31ff748e201d44712cc8c90d189edaa8e4e47;

    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setUniswapV4TickLimits_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setUniswapV4TickLimits(bytes32(0), 0, 0, 0);
    }

    function test_setUniswapV4TickLimits_revertsForNonAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setUniswapV4TickLimits(bytes32(0), 0, 0, 0);
    }

    function test_setUniswapV4TickLimits_revertsWhenInvalidTicks() external {
        vm.expectRevert("UniswapV4Lib/invalid-ticks");
        vm.prank(admin);
        mainnetController.setUniswapV4TickLimits(bytes32(0), 1, 1, 1); // Reverts when lower >= upper

        vm.prank(admin);
        mainnetController.setUniswapV4TickLimits(bytes32(0), 0, 1, 1); // lower must be less than upper

        vm.expectRevert("UniswapV4Lib/invalid-ticks");
        vm.prank(admin);
        mainnetController.setUniswapV4TickLimits(bytes32(0), 0, 1, 0); // Reverts when maxTickSpacing is zero

        vm.prank(admin);
        mainnetController.setUniswapV4TickLimits(bytes32(0), 0, 0, 0); // maxTickSpacing can only be 0 if all 0
    }

    function test_setUniswapV4TickLimits() external {
        vm.expectEmit(address(mainnetController));
        emit UniswapV4Lib.UniswapV4TickLimitsSet(_POOL_ID, -60, 60, 20);

        vm.record();

        vm.prank(admin);
        mainnetController.setUniswapV4TickLimits(_POOL_ID, -60, 60, 20);

        _assertReentrancyGuardWrittenToTwice();

        ( int24 tickLowerMin, int24 tickUpperMax, uint24 maxTickSpacing ) = mainnetController.uniswapV4TickLimits(_POOL_ID);

        assertEq(tickLowerMin,   -60);
        assertEq(tickUpperMax,   60);
        assertEq(maxTickSpacing, 20);
    }

}

contract MainnetController_Admin_SetUSDSVault_Tests is MainnetController_Admin_TestBase {

    address internal immutable _usdVault     = makeAddr("usdVault");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setUSDSVault_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setUSDSVault(_usdVault);
    }

    function test_setUSDSVault_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setUSDSVault(_usdVault);
    }

    function test_setUSDSVault() external {
        assertEq(mainnetController.usdsVault(), address(0));

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit MainnetController.USDSVaultSet(_usdVault);

        vm.prank(admin);
        mainnetController.setUSDSVault(_usdVault);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.usdsVault(), _usdVault);
    }

}

contract MainnetController_Admin_SetEthenaMinter is MainnetController_Admin_TestBase {

    address internal immutable _ethenaMinter = makeAddr("ethenaMinter");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setEthenaMinter_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setEthenaMinter(_ethenaMinter);
    }

    function test_setEthenaMinter_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setEthenaMinter(_ethenaMinter);
    }

    function test_setEthenaMinter() external {
        assertEq(mainnetController.ethenaMinter(), address(0));

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit MainnetController.EthenaMinterSet(_ethenaMinter);

        vm.prank(admin);
        mainnetController.setEthenaMinter(_ethenaMinter);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.ethenaMinter(), _ethenaMinter);
    }

}

contract MainnetController_Admin_SetCCTPTokenMessenger is MainnetController_Admin_TestBase {

    address internal immutable _cctpTokenMessenger = makeAddr("cctpTokenMessenger");
    address internal immutable _unauthorized       = makeAddr("unauthorized");

    function test_setCCTPTokenMessenger_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setCCTPTokenMessenger(_cctpTokenMessenger);
    }

    function test_setCCTPTokenMessenger_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setCCTPTokenMessenger(_cctpTokenMessenger);
    }

    function test_setCCTPTokenMessenger() external {
        assertEq(mainnetController.cctpTokenMessenger(), address(0));

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit MainnetController.CCTPTokenMessengerSet(_cctpTokenMessenger);

        vm.prank(admin);
        mainnetController.setCCTPTokenMessenger(_cctpTokenMessenger);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.cctpTokenMessenger(), _cctpTokenMessenger);
    }

}

contract MainnetController_Admin_SetCCTPUSDC is MainnetController_Admin_TestBase {

    address internal immutable _cctpUSDC     = makeAddr("cctpUSDC");
    address internal immutable _unauthorized = makeAddr("unauthorized");

    function test_setCCTPUSDC_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setCCTPUSDC(_cctpUSDC);
    }

    function test_setCCTPUSDC_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setCCTPUSDC(_cctpUSDC);
    }

    function test_setCCTPUSDC() external {
        assertEq(mainnetController.cctpUSDC(), address(0));

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit MainnetController.CCTPUSDCSet(_cctpUSDC);

        vm.prank(admin);
        mainnetController.setCCTPUSDC(_cctpUSDC);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.cctpUSDC(), _cctpUSDC);
    }

}

contract MainnetController_Admin_SetCentrifugeRecipient is MainnetController_Admin_TestBase {

    bytes32 internal immutable centrifugeRecipient1 = bytes32(uint256(uint160(makeAddr("centrifugeRecipient1"))));
    bytes32 internal immutable centrifugeRecipient2 = bytes32(uint256(uint160(makeAddr("centrifugeRecipient2"))));
    address internal immutable _unauthorized        = makeAddr("unauthorized");

    function test_setCentrifugeRecipient_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.setCentrifugeRecipient(1, centrifugeRecipient1);
    }

    function test_setCentrifugeRecipient_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        mainnetController.setCentrifugeRecipient(1, centrifugeRecipient1);
    }

    function test_setCentrifugeRecipient() external {
        assertEq(mainnetController.centrifugeRecipients(1), bytes32(0));
        assertEq(mainnetController.centrifugeRecipients(2), bytes32(0));

        vm.expectEmit(address(mainnetController));
        emit CentrifugeLib.CentrifugeRecipientSet(1, centrifugeRecipient1);

        vm.prank(admin);
        mainnetController.setCentrifugeRecipient(1, centrifugeRecipient1);

        assertEq(mainnetController.centrifugeRecipients(1), centrifugeRecipient1);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit CentrifugeLib.CentrifugeRecipientSet(2, centrifugeRecipient2);

        vm.prank(admin);
        mainnetController.setCentrifugeRecipient(2, centrifugeRecipient2);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(mainnetController.centrifugeRecipients(2), centrifugeRecipient2);
    }

}


contract ForeignController_Admin_Tests is UnitTestBase {

    event MerklDistributorSet(address indexed merklDistributor);

    uint24 internal constant _MAX_TICK_DELTA = 887272;

    int24 internal constant _MIN_UNISWAP_TICK = -887_272;
    int24 internal constant _MAX_UNISWAP_TICK =  887_272;
    
    address internal immutable _cctpTokenMessenger = makeAddr("cctpTokenMessenger");
    address internal immutable _cctpUSDC           = makeAddr("cctpUSDC");
    address internal immutable _merklDistributor   = makeAddr("merklDistributor");
    address internal immutable _pendleRouter       = makeAddr("pendleRouter");
    address internal immutable _pool               = makeAddr("pool");
    address internal immutable _positionManager    = makeAddr("positionManager");
    address internal immutable _psm3               = makeAddr("psm3");
    address internal immutable _token              = makeAddr("token");
    address internal immutable _swapRouter         = makeAddr("swapRouter");
    address internal immutable _unauthorized       = makeAddr("unauthorized");

    ForeignController internal foreignController;

    bytes32 internal centrifugeRecipient1 = bytes32(uint256(uint160(makeAddr("centrifugeRecipient1"))));
    bytes32 internal centrifugeRecipient2 = bytes32(uint256(uint160(makeAddr("centrifugeRecipient2"))));
    bytes32 internal layerZeroRecipient1  = bytes32(uint256(uint160(makeAddr("layerZeroRecipient1"))));
    bytes32 internal layerZeroRecipient2  = bytes32(uint256(uint160(makeAddr("layerZeroRecipient2"))));
    bytes32 internal mintRecipient1       = bytes32(uint256(uint160(makeAddr("mintRecipient1"))));
    bytes32 internal mintRecipient2       = bytes32(uint256(uint160(makeAddr("mintRecipient2"))));

    function setUp() public {
        foreignController = new ForeignController(admin, makeAddr("almProxy"), makeAddr("rateLimits"));
    }

    function _setControllerEntered() internal {
        vm.store(address(foreignController), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);
    }

    function _assertReentrancyGuardWrittenToTwice() internal {
        _assertReentrancyGuardWrittenToTwice(address(foreignController));
    }

    function test_setMaxSlippage_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setMaxSlippage(makeAddr("pool"), 0.98e18);
    }

    function test_setMaxSlippage_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        foreignController.setMaxSlippage(makeAddr("pool"), 0.98e18);

        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        vm.prank(freezer);
        foreignController.setMaxSlippage(makeAddr("pool"), 0.98e18);
    }

    function test_setMaxSlippage_poolZeroAddress() external {
        vm.expectRevert("FC/pool-zero-address");
        vm.prank(admin);
        foreignController.setMaxSlippage(address(0), 0.98e18);
    }

    function test_setMaxSlippage() external {
        address pool = makeAddr("pool");

        assertEq(foreignController.maxSlippages(pool), 0);

        vm.expectEmit(address(foreignController));
        emit ForeignController.MaxSlippageSet(pool, 0.98e18);

        vm.prank(admin);
        foreignController.setMaxSlippage(pool, 0.98e18);

        assertEq(foreignController.maxSlippages(pool), 0.98e18);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit ForeignController.MaxSlippageSet(pool, 0.99e18);

        vm.prank(admin);
        foreignController.setMaxSlippage(pool, 0.99e18);

        assertEq(foreignController.maxSlippages(pool), 0.99e18);

        _assertReentrancyGuardWrittenToTwice();
    }

    function test_setMintRecipient_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setMintRecipient(1, mintRecipient1);
    }

    function test_setMintRecipient_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        foreignController.setMintRecipient(1, mintRecipient1);

        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        vm.prank(freezer);
        foreignController.setMintRecipient(1, mintRecipient1);
    }

    function test_setMintRecipient() external {
        assertEq(foreignController.mintRecipients(1), bytes32(0));
        assertEq(foreignController.mintRecipients(2), bytes32(0));

        vm.expectEmit(address(foreignController));
        emit CCTPLib.MintRecipientSet(1, mintRecipient1);

        vm.prank(admin);
        foreignController.setMintRecipient(1, mintRecipient1);

        assertEq(foreignController.mintRecipients(1), mintRecipient1);

        vm.expectEmit(address(foreignController));
        emit CCTPLib.MintRecipientSet(2, mintRecipient2);

        vm.prank(admin);
        foreignController.setMintRecipient(2, mintRecipient2);

        assertEq(foreignController.mintRecipients(2), mintRecipient2);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit CCTPLib.MintRecipientSet(1, mintRecipient2);

        vm.prank(admin);
        foreignController.setMintRecipient(1, mintRecipient2);

        assertEq(foreignController.mintRecipients(1), mintRecipient2);

        _assertReentrancyGuardWrittenToTwice();
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

    function test_setMerklDistributor_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setMerklDistributor(_merklDistributor);
    }

    function test_setMerklDistributor_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setMerklDistributor(_merklDistributor);
    }

    function test_setMerklDistributor() external {
        assertEq(foreignController.merklDistributor(), address(0));

        vm.expectEmit(address(foreignController));
        emit ForeignController.MerklDistributorSet(_merklDistributor);

        vm.prank(admin);
        foreignController.setMerklDistributor(_merklDistributor);

        assertEq(foreignController.merklDistributor(), _merklDistributor);
    }

    function test_setCentrifugeRecipient_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setCentrifugeRecipient(1, centrifugeRecipient1);
    }

    function test_setCentrifugeRecipient_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setCentrifugeRecipient(1, centrifugeRecipient1);
    }

    function test_setCentrifugeRecipient() external {
        assertEq(foreignController.centrifugeRecipients(1), bytes32(0));
        assertEq(foreignController.centrifugeRecipients(2), bytes32(0));

        vm.expectEmit(address(foreignController));
        emit CentrifugeLib.CentrifugeRecipientSet(1, centrifugeRecipient1);

        vm.prank(admin);
        foreignController.setCentrifugeRecipient(1, centrifugeRecipient1);

        assertEq(foreignController.centrifugeRecipients(1), centrifugeRecipient1);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit CentrifugeLib.CentrifugeRecipientSet(2, centrifugeRecipient2);

        vm.prank(admin);
        foreignController.setCentrifugeRecipient(2, centrifugeRecipient2);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(foreignController.centrifugeRecipients(2), centrifugeRecipient2);
    }

    function test_setMaxExchangeRate_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setMaxExchangeRate(_token, 1e18, 1e18);
    }

    function test_setMaxExchangeRate_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setMaxExchangeRate(_token, 1e18, 1e18);
    }

    function test_setMaxExchangeRate_tokenZeroAddress() external {
        vm.expectRevert("ERC4626Lib/token-zero-address");
        vm.prank(admin);
        foreignController.setMaxExchangeRate(address(0), 1e18, 1e18);
    }

    function test_setMaxExchangeRate() external {
        assertEq(foreignController.maxExchangeRates(_token), 0);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit ERC4626Lib.MaxExchangeRateSet(_token, 1e36);

        vm.prank(admin);
        foreignController.setMaxExchangeRate(_token, 1e18, 1e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(foreignController.maxExchangeRates(_token), 1e36);

        vm.expectEmit(address(foreignController));
        emit ERC4626Lib.MaxExchangeRateSet(_token, 1e24);

        vm.prank(admin);
        foreignController.setMaxExchangeRate(_token, 1e18, 1e6);

        assertEq(foreignController.maxExchangeRates(_token), 1e24);

        vm.expectEmit(address(foreignController));
        emit ERC4626Lib.MaxExchangeRateSet(_token, 1e48);

        vm.prank(admin);
        foreignController.setMaxExchangeRate(_token, 1e6, 1e18);

        assertEq(foreignController.maxExchangeRates(_token), 1e48);
    }

    function test_setPendleRouter_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setPendleRouter(_pendleRouter);
    }

    function test_setPendleRouter_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setPendleRouter(_pendleRouter);
    }

    function test_setPendleRouter() external {
        assertEq(foreignController.pendleRouter(), address(0));

        vm.record();

        vm.expectEmit(address(foreignController));
        emit ForeignController.PendleRouterSet(_pendleRouter);

        vm.prank(admin);
        foreignController.setPendleRouter(_pendleRouter);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(foreignController.pendleRouter(), _pendleRouter);
    }

    function test_setUniswapV3PositionManager_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setUniswapV3PositionManager(_positionManager);
    }

    function test_setUniswapV3PositionManager_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setUniswapV3PositionManager(_positionManager);
    }

    function test_setUniswapV3PositionManager() external {
        assertEq(foreignController.uniswapV3PositionManager(), address(0));

        vm.record();

        vm.expectEmit(address(foreignController));
        emit ForeignController.UniswapV3PositionManagerSet(_positionManager);

        vm.prank(admin);
        foreignController.setUniswapV3PositionManager(_positionManager);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(foreignController.uniswapV3PositionManager(), _positionManager);
    }

    function test_setUniswapV3SwapRouter_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setUniswapV3SwapRouter(_swapRouter);
    }

    function test_setUniswapV3SwapRouter_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setUniswapV3SwapRouter(_swapRouter);
    }

    function test_setUniswapV3SwapRouter() external {
        assertEq(foreignController.uniswapV3Router(), address(0));

        vm.record();

        vm.expectEmit(address(foreignController));
        emit ForeignController.UniswapV3SwapRouterSet(_swapRouter);

        vm.prank(admin);
        foreignController.setUniswapV3SwapRouter(_swapRouter);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(foreignController.uniswapV3Router(), _swapRouter);
    }

    function test_setUniswapV3PoolMaxTickDelta_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setUniswapV3PoolMaxTickDelta(_pool, 10);
    }

    function test_setUniswapV3PoolMaxTickDelta_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setUniswapV3PoolMaxTickDelta(_pool, 1000);
    }

    function test_setUniswapV3PoolMaxTickDelta_outOfBoundsBoundary() external {
        vm.expectRevert("UniswapV3Lib/max-tick-delta-oob");
        vm.prank(admin);
        foreignController.setUniswapV3PoolMaxTickDelta(_pool, 0);

        vm.expectRevert("UniswapV3Lib/max-tick-delta-oob");
        vm.prank(admin);
        foreignController.setUniswapV3PoolMaxTickDelta(_pool, _MAX_TICK_DELTA + 1);

        // Can set at boundary

        vm.prank(admin);
        foreignController.setUniswapV3PoolMaxTickDelta(_pool, 1);

        vm.prank(admin);
        foreignController.setUniswapV3PoolMaxTickDelta(_pool, _MAX_TICK_DELTA);
    }

    function test_setUniswapV3PoolMaxTickDelta() external {
        ( uint24 maxTickDelta, , ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(maxTickDelta, 0);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit UniswapV3Lib.UniswapV3PoolMaxTickDeltaSet(_pool, 1000);

        vm.prank(admin);
        foreignController.setUniswapV3PoolMaxTickDelta(_pool, 1000);

        _assertReentrancyGuardWrittenToTwice();

        ( maxTickDelta, , ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(maxTickDelta, 1000);
    }

    function test_setUniswapV3AddLiquidityLowerTickBound_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_pool, 100);
    }

    function test_setUniswapV3AddLiquidityLowerTickBound_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_pool, 100);
    }

    function test_setUniswapV3AddLiquidityLowerTickBound_outOfBoundsBoundary() external {
        vm.expectRevert("UniswapV3Lib/lower-tick-oob");
        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_pool, _MIN_UNISWAP_TICK - 1);

        // First set an upper tick bound
        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_pool, 1000);

        // Try to set lower tick at the upper tick
        vm.expectRevert("UniswapV3Lib/lower-tick-oob");
        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_pool, 1000);

        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_pool, _MIN_UNISWAP_TICK);

        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_pool, 999);
    }

    function test_setUniswapV3AddLiquidityLowerTickBound() external {
        // First set an upper tick bound so we have room to set lower
        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_pool, 5000);

        ( , UniswapV3Lib.Ticks memory tickBounds, ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.lower, 0);
        assertEq(tickBounds.upper, 5000);

        vm.expectEmit(address(foreignController));
        emit UniswapV3Lib.UniswapV3PoolLowerTickUpdated(_pool, -1000);

        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_pool, -1000);

        ( , tickBounds, ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.lower, -1000);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit UniswapV3Lib.UniswapV3PoolLowerTickUpdated(_pool, _MIN_UNISWAP_TICK);

        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_pool, _MIN_UNISWAP_TICK);

        _assertReentrancyGuardWrittenToTwice();

        ( , tickBounds, ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.lower, _MIN_UNISWAP_TICK);
    }

    function test_setUniswapV3AddLiquidityUpperTickBound_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_pool, 100);
    }

    function test_setUniswapV3AddLiquidityUpperTickBound_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_pool, 100);
    }

    function test_setUniswapV3AddLiquidityUpperTickBound_outOfBoundsBoundary() external {
        vm.expectRevert("UniswapV3Lib/upper-tick-oob");
        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_pool, _MAX_UNISWAP_TICK + 1);

        vm.expectRevert("UniswapV3Lib/upper-tick-oob");
        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_pool, 0); // Current lower tick is 0

        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_pool, _MAX_UNISWAP_TICK);

        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_pool, 1);
    }

    function test_setUniswapV3AddLiquidityUpperTickBound() external {
        ( , UniswapV3Lib.Ticks memory tickBounds, ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.lower, 0);
        assertEq(tickBounds.upper, 0);

        vm.expectEmit(address(foreignController));
        emit UniswapV3Lib.UniswapV3PoolUpperTickUpdated(_pool, 1000);

        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_pool, 1000);

        ( , tickBounds, ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.lower, 0);
        assertEq(tickBounds.upper, 1000);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit UniswapV3Lib.UniswapV3PoolUpperTickUpdated(_pool, _MAX_UNISWAP_TICK);

        vm.prank(admin);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_pool, _MAX_UNISWAP_TICK);

        _assertReentrancyGuardWrittenToTwice();

        ( , tickBounds, ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(tickBounds.upper, _MAX_UNISWAP_TICK);
    }

    function test_setUniswapV3TWAPSecondsAgo_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setUniswapV3TWAPSecondsAgo(_pool, 100);
    }

    function test_setUniswapV3TWAPSecondsAgo_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setUniswapV3TWAPSecondsAgo(_pool, 300);
    }

    function test_setUniswapV3TWAPSecondsAgo_outOfBoundsBoundary() external {
        vm.expectRevert("UniswapV3Lib/twap-seconds-ago-oob");
        vm.prank(admin);
        foreignController.setUniswapV3TWAPSecondsAgo(_pool, uint32(type(int32).max));

        vm.prank(admin);
        foreignController.setUniswapV3TWAPSecondsAgo(_pool, uint32(type(int32).max) - 1);
    }

    function test_setUniswapV3TWAPSecondsAgo() external {
        ( , , uint32 twapSecondsAgo ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(twapSecondsAgo, 0);

        vm.expectEmit(address(foreignController));
        emit UniswapV3Lib.UniswapV3PoolTWAPSecondsAgoUpdated(_pool, 300);

        vm.prank(admin);
        foreignController.setUniswapV3TWAPSecondsAgo(_pool, 300);

        ( , , twapSecondsAgo ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(twapSecondsAgo, 300);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit UniswapV3Lib.UniswapV3PoolTWAPSecondsAgoUpdated(_pool, 1800);

        vm.prank(admin);
        foreignController.setUniswapV3TWAPSecondsAgo(_pool, 1800);

        _assertReentrancyGuardWrittenToTwice();

        ( , , twapSecondsAgo ) = foreignController.uniswapV3PoolParams(_pool);

        assertEq(twapSecondsAgo, 1800);
    }
    
    function test_setPSM3_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setPSM3(_psm3);
    }

    function test_setPSM3_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setPSM3(_psm3);
    }

    function test_setPSM3() external {
        assertEq(foreignController.psm3(), address(0));

        vm.record();

        vm.expectEmit(address(foreignController));
        emit ForeignController.PSM3Set(_psm3);

        vm.prank(admin);
        foreignController.setPSM3(_psm3);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(foreignController.psm3(), _psm3);
    }

    function test_setCCTPTokenMessenger_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setCCTPTokenMessenger(_cctpTokenMessenger);
    }

    function test_setCCTPTokenMessenger_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setCCTPTokenMessenger(_cctpTokenMessenger);
    }

    function test_setCCTPTokenMessenger() external {
        assertEq(foreignController.cctpTokenMessenger(), address(0));

        vm.record();

        vm.expectEmit(address(foreignController));
        emit ForeignController.CCTPTokenMessengerSet(_cctpTokenMessenger);

        vm.prank(admin);
        foreignController.setCCTPTokenMessenger(_cctpTokenMessenger);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(foreignController.cctpTokenMessenger(), _cctpTokenMessenger);
    }

    function test_setCCTPUSDC_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setCCTPUSDC(_cctpUSDC);
    }

    function test_setCCTPUSDC_unauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(_unauthorized);
        foreignController.setCCTPUSDC(_cctpUSDC);
    }

    function test_setCCTPUSDC() external {
        assertEq(foreignController.cctpUSDC(), address(0));

        vm.record();

        vm.expectEmit(address(foreignController));
        emit ForeignController.CCTPUSDCSet(_cctpUSDC);

        vm.prank(admin);
        foreignController.setCCTPUSDC(_cctpUSDC);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(foreignController.cctpUSDC(), _cctpUSDC);
    }

}
