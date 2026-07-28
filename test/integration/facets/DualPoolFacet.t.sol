// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Currency } from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IHooks } from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { IAccessControls }                       from "../../../src/interfaces/IAccessControls.sol";
import { IController }                           from "../../../src/interfaces/IController.sol";
import { IEnumerableIntegrations }               from "../../../src/interfaces/IEnumerableIntegrations.sol";
import { IFacet }                                from "../../../src/facets/IFacet.sol";
import { IDualPoolFacet }                        from "../../../src/facets/dual-pool/IDualPoolFacet.sol";
import { makeAddressBytes32Key, makeBytes32Key } from "../../../src/libraries/RateLimitHelpers.sol";

import { DualPoolFacet } from "../../../src/facets/dual-pool/DualPoolFacet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function acceptHookOwnership() external;

    function bootstrap(PoolKey calldata key, uint256 amount0, uint256 amount1) external;

    function deposit(PoolKey calldata key, uint256 sharesToMint, uint128 amount0Max, uint128 amount1Max)
        external;

    function emergencyRevokeVault(PoolKey calldata key) external;

    function initializePool(PoolKey calldata key, IDualPoolFacet.PoolConfig calldata config) external;

    function pausePool(PoolKey calldata key) external;

    function refreshVaultApproval(PoolKey calldata key, Currency currency) external;

    function resumePool(PoolKey calldata key) external;

    function setDistribution(PoolKey calldata key, IDualPoolFacet.LiquidityBucket[] calldata buckets)
        external;

    function setExternalDeposits(PoolKey calldata key, bool enabled) external;

    function setMaxSlippage(bytes32 poolId, uint256 maxSlippage) external;

    function setPriceRatio(bytes32 poolId, uint256 priceRatio) external;

    function swap(PoolKey calldata key, address tokenIn, uint128 amountIn, uint128 amountOutMin)
        external;

    function transferHookOwnership(address newOwner) external;

    function withdraw(PoolKey calldata key, uint256 sharesToBurn, uint128 amount0Min, uint128 amount1Min)
        external;

    function FREEZER_ROLE() external pure returns (bytes32);

    function hook() external view returns (address);

    function permit2() external view returns (address);

    function router() external view returns (address);

    function getAggregateDepositRateLimitKey(bytes32 poolId) external pure returns (bytes32);

    function getAggregateWithdrawRateLimitKey(bytes32 poolId) external pure returns (bytes32);

    function getAssetDepositRateLimitKey(bytes32 poolId, address token) external pure returns (bytes32);

    function getAssetWithdrawRateLimitKey(bytes32 poolId, address token) external pure returns (bytes32);

    function getMaxSlippage(bytes32 poolId) external view returns (uint256);

    function getPriceRatio(bytes32 poolId) external view returns (uint256);

    function getSwapRateLimitKey(bytes32 poolId, address token) external pure returns (bytes32);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

contract Controller_DualPoolFacet_Tests is Integration_TestBase {

    bytes32 internal constant FREEZER_ROLE = keccak256("FREEZER_ROLE");

    address internal freezer = makeAddr("freezer");

    address internal hookAddress = makeAddr("hook");

    IControllerLike internal controller;

    PoolKey internal poolKey;

    bytes32 internal poolId;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new DualPoolFacet({
            hook_    : hookAddress,
            permit2_ : makeAddr("permit2"),
            router_  : makeAddr("router")
        }));

        vm.label(facet, "DualPoolFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](26);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.acceptHookOwnership.selector,
            IDualPoolFacet.acceptHookOwnership.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerLike.bootstrap.selector,
            IDualPoolFacet.bootstrap.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IControllerLike.deposit.selector,
            IDualPoolFacet.deposit.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IControllerLike.emergencyRevokeVault.selector,
            IDualPoolFacet.emergencyRevokeVault.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IControllerLike.initializePool.selector,
            IDualPoolFacet.initializePool.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IControllerLike.pausePool.selector,
            IDualPoolFacet.pausePool.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IControllerLike.refreshVaultApproval.selector,
            IDualPoolFacet.refreshVaultApproval.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IControllerLike.resumePool.selector,
            IDualPoolFacet.resumePool.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IControllerLike.setDistribution.selector,
            IDualPoolFacet.setDistribution.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            IControllerLike.setExternalDeposits.selector,
            IDualPoolFacet.setExternalDeposits.selector
        );

        wires[10] = IEnumerableIntegrations.Wire(
            IControllerLike.setMaxSlippage.selector,
            IDualPoolFacet.setMaxSlippage.selector
        );

        wires[11] = IEnumerableIntegrations.Wire(
            IControllerLike.swap.selector,
            IDualPoolFacet.swap.selector
        );

        wires[12] = IEnumerableIntegrations.Wire(
            IControllerLike.transferHookOwnership.selector,
            IDualPoolFacet.transferHookOwnership.selector
        );

        wires[13] = IEnumerableIntegrations.Wire(
            IControllerLike.withdraw.selector,
            IDualPoolFacet.withdraw.selector
        );

        wires[14] = IEnumerableIntegrations.Wire(
            IControllerLike.FREEZER_ROLE.selector,
            IDualPoolFacet.FREEZER_ROLE.selector
        );

        wires[15] = IEnumerableIntegrations.Wire(
            IControllerLike.hook.selector,
            IDualPoolFacet.hook.selector
        );

        wires[16] = IEnumerableIntegrations.Wire(
            IControllerLike.permit2.selector,
            IDualPoolFacet.permit2.selector
        );

        wires[17] = IEnumerableIntegrations.Wire(
            IControllerLike.router.selector,
            IDualPoolFacet.router.selector
        );

        wires[18] = IEnumerableIntegrations.Wire(
            IControllerLike.getAggregateDepositRateLimitKey.selector,
            IDualPoolFacet.getAggregateDepositRateLimitKey.selector
        );

        wires[19] = IEnumerableIntegrations.Wire(
            IControllerLike.getAggregateWithdrawRateLimitKey.selector,
            IDualPoolFacet.getAggregateWithdrawRateLimitKey.selector
        );

        wires[20] = IEnumerableIntegrations.Wire(
            IControllerLike.getAssetDepositRateLimitKey.selector,
            IDualPoolFacet.getAssetDepositRateLimitKey.selector
        );

        wires[21] = IEnumerableIntegrations.Wire(
            IControllerLike.getAssetWithdrawRateLimitKey.selector,
            IDualPoolFacet.getAssetWithdrawRateLimitKey.selector
        );

        wires[22] = IEnumerableIntegrations.Wire(
            IControllerLike.getMaxSlippage.selector,
            IDualPoolFacet.getMaxSlippage.selector
        );

        wires[23] = IEnumerableIntegrations.Wire(
            IControllerLike.getSwapRateLimitKey.selector,
            IDualPoolFacet.getSwapRateLimitKey.selector
        );

        wires[24] = IEnumerableIntegrations.Wire(
            IControllerLike.setPriceRatio.selector,
            IDualPoolFacet.setPriceRatio.selector
        );

        wires[25] = IEnumerableIntegrations.Wire(
            IControllerLike.getPriceRatio.selector,
            IDualPoolFacet.getPriceRatio.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("DUAL_POOL_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "DUAL_POOL_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);

        address accessControls = IController(payable(address(controller))).accessControls();

        vm.prank(admin);
        IAccessControls(accessControls).grantRole(FREEZER_ROLE, freezer);

        address tokenA = makeAddr("tokenA");
        address tokenB = makeAddr("tokenB");

        ( address token0, address token1 ) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        poolKey = PoolKey({
            currency0   : Currency.wrap(token0),
            currency1   : Currency.wrap(token1),
            fee         : 100,
            tickSpacing : 1,
            hooks       : IHooks(hookAddress)
        });

        poolId = keccak256(abi.encode(poolKey));
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _badHookKey() internal view returns (PoolKey memory badKey) {
        badKey = poolKey;
        badKey.hooks = IHooks(address(0xBAD));
    }

    function _defaultConfig() internal pure returns (IDualPoolFacet.PoolConfig memory config) {
        IDualPoolFacet.LiquidityBucket[] memory distribution = new IDualPoolFacet.LiquidityBucket[](1);

        distribution[0] = IDualPoolFacet.LiquidityBucket({
            tickLower : -10,
            tickUpper : 10,
            weightBps : 10_000
        });

        config = IDualPoolFacet.PoolConfig({
            sqrtPriceX96          : 79228162514264337593543950336,  // 2**96, price of 1.0
            distribution          : distribution,
            allowExternalDeposits : false,
            vault0                : address(0),
            vault1                : address(0),
            minDepositBlocks      : 1
        });
    }

    function _expectUnauthorized(address caller, bytes32 role) internal {
        vm.expectRevert(
            abi.encodeWithSelector(IFacet.AccessControlUnauthorizedAccount.selector, caller, role)
        );
    }

    function _setMaxSlippage(uint256 maxSlippage) internal {
        vm.prank(admin);
        controller.setMaxSlippage(poolId, maxSlippage);
    }

    function _setPriceRatio(uint256 priceRatio) internal {
        vm.prank(admin);
        controller.setPriceRatio(poolId, priceRatio);
    }

    /// @dev Both halves of the value floor, which is what opens the allocator paths.
    function _onboard() internal {
        _setMaxSlippage(0.99e18);
        _setPriceRatio(1e18);
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor_zeroHook() external {
        vm.expectRevert("DualPoolFacet/zero-hook");
        new DualPoolFacet(address(0), address(0), address(0));
    }

    function test_constructor_zeroPermit2() external {
        vm.expectRevert("DualPoolFacet/zero-permit2");
        new DualPoolFacet(hookAddress, address(0), address(0));
    }

    function test_constructor_zeroRouter() external {
        vm.expectRevert("DualPoolFacet/zero-router");
        new DualPoolFacet(hookAddress, makeAddr("permit2"), address(0));
    }

    function test_constructor() external {
        address permit2 = makeAddr("permit2");
        address router  = makeAddr("router");

        DualPoolFacet facet = new DualPoolFacet(hookAddress, permit2, router);

        assertEq(facet.hook(),    hookAddress);
        assertEq(facet.permit2(), permit2);
        assertEq(facet.router(),  router);
    }

    /**********************************************************************************************/
    /*** Immutables Tests                                                                       ***/
    /**********************************************************************************************/

    function test_immutables() external {
        assertEq(controller.hook(),    hookAddress);
        assertEq(controller.permit2(), makeAddr("permit2"));
        assertEq(controller.router(),  makeAddr("router"));
    }

    function test_freezerRole() external {
        assertEq(controller.FREEZER_ROLE(), keccak256("FREEZER_ROLE"));
    }

    /**********************************************************************************************/
    /*** setMaxSlippage Tests                                                                   ***/
    /**********************************************************************************************/

    function test_setMaxSlippage_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setMaxSlippage(bytes32(0), 0);
    }

    function test_setMaxSlippage_notAdmin() external {
        _expectUnauthorized(unauthorized, DEFAULT_ADMIN_ROLE);
        vm.prank(unauthorized);
        controller.setMaxSlippage(bytes32(0), 0);

        _expectUnauthorized(allocator, DEFAULT_ADMIN_ROLE);
        vm.prank(allocator);
        controller.setMaxSlippage(bytes32(0), 0);
    }

    function test_setMaxSlippage_zeroPoolId() external {
        vm.expectRevert("DualPoolFacet/zero-pool-id");
        vm.prank(admin);
        controller.setMaxSlippage(bytes32(0), 0.98e18);
    }

    function test_setMaxSlippage_aboveOne() external {
        vm.expectRevert("DualPoolFacet/max-slippage-too-high");
        vm.prank(admin);
        controller.setMaxSlippage(poolId, 1e18 + 1);

        vm.expectRevert("DualPoolFacet/max-slippage-too-high");
        vm.prank(admin);
        controller.setMaxSlippage(poolId, type(uint256).max);
    }

    function test_setMaxSlippage_atOneBoundary() external {
        vm.prank(admin);
        controller.setMaxSlippage(poolId, 1e18);

        assertEq(controller.getMaxSlippage(poolId), 1e18);
    }

    function test_setMaxSlippage() external {
        vm.expectEmit(address(controller));
        emit IDualPoolFacet.DualPoolMaxSlippageSet(poolId, 0.98e18);

        vm.record();

        vm.prank(admin);
        controller.setMaxSlippage(poolId, 0.98e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));

        assertEq(controller.getMaxSlippage(poolId), 0.98e18);
    }

    /**********************************************************************************************/
    /*** setPriceRatio Tests                                                                    ***/
    /**********************************************************************************************/

    function test_setPriceRatio_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setPriceRatio(bytes32(0), 0);
    }

    function test_setPriceRatio_notAdmin() external {
        _expectUnauthorized(unauthorized, DEFAULT_ADMIN_ROLE);
        vm.prank(unauthorized);
        controller.setPriceRatio(bytes32(0), 0);

        _expectUnauthorized(allocator, DEFAULT_ADMIN_ROLE);
        vm.prank(allocator);
        controller.setPriceRatio(bytes32(0), 0);
    }

    function test_setPriceRatio_zeroPoolId() external {
        vm.expectRevert("DualPoolFacet/zero-pool-id");
        vm.prank(admin);
        controller.setPriceRatio(bytes32(0), 1e18);
    }

    function test_setPriceRatio() external {
        vm.expectEmit(address(controller));
        emit IDualPoolFacet.DualPoolPriceRatioSet(poolId, 1.0002e18);

        vm.record();

        vm.prank(admin);
        controller.setPriceRatio(poolId, 1.0002e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));

        assertEq(controller.getPriceRatio(poolId), 1.0002e18);
    }

    /**********************************************************************************************/
    /*** getPriceRatio Tests                                                                    ***/
    /**********************************************************************************************/

    function test_getPriceRatio_unset() external {
        assertEq(controller.getPriceRatio(poolId), 0);
    }

    /**********************************************************************************************/
    /*** initializePool Tests                                                                   ***/
    /**********************************************************************************************/

    function test_initializePool_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.initializePool(poolKey, _defaultConfig());
    }

    function test_initializePool_notAdmin() external {
        _expectUnauthorized(unauthorized, DEFAULT_ADMIN_ROLE);
        vm.prank(unauthorized);
        controller.initializePool(poolKey, _defaultConfig());

        _expectUnauthorized(allocator, DEFAULT_ADMIN_ROLE);
        vm.prank(allocator);
        controller.initializePool(poolKey, _defaultConfig());
    }

    function test_initializePool_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(admin);
        controller.initializePool(_badHookKey(), _defaultConfig());
    }

    /**********************************************************************************************/
    /*** bootstrap Tests                                                                        ***/
    /**********************************************************************************************/

    function test_bootstrap_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.bootstrap(poolKey, 0, 0);
    }

    function test_bootstrap_notAdmin() external {
        _expectUnauthorized(unauthorized, DEFAULT_ADMIN_ROLE);
        vm.prank(unauthorized);
        controller.bootstrap(poolKey, 0, 0);

        _expectUnauthorized(allocator, DEFAULT_ADMIN_ROLE);
        vm.prank(allocator);
        controller.bootstrap(poolKey, 0, 0);
    }

    function test_bootstrap_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(admin);
        controller.bootstrap(_badHookKey(), 0, 0);
    }

    /**********************************************************************************************/
    /*** setDistribution Tests                                                                  ***/
    /**********************************************************************************************/

    function test_setDistribution_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setDistribution(poolKey, new IDualPoolFacet.LiquidityBucket[](0));
    }

    function test_setDistribution_notAdmin() external {
        _expectUnauthorized(unauthorized, DEFAULT_ADMIN_ROLE);
        vm.prank(unauthorized);
        controller.setDistribution(poolKey, new IDualPoolFacet.LiquidityBucket[](0));

        _expectUnauthorized(allocator, DEFAULT_ADMIN_ROLE);
        vm.prank(allocator);
        controller.setDistribution(poolKey, new IDualPoolFacet.LiquidityBucket[](0));
    }

    function test_setDistribution_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(admin);
        controller.setDistribution(_badHookKey(), new IDualPoolFacet.LiquidityBucket[](0));
    }

    /**********************************************************************************************/
    /*** setExternalDeposits Tests                                                              ***/
    /**********************************************************************************************/

    function test_setExternalDeposits_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setExternalDeposits(poolKey, true);
    }

    function test_setExternalDeposits_notAdmin() external {
        _expectUnauthorized(unauthorized, DEFAULT_ADMIN_ROLE);
        vm.prank(unauthorized);
        controller.setExternalDeposits(poolKey, true);

        _expectUnauthorized(allocator, DEFAULT_ADMIN_ROLE);
        vm.prank(allocator);
        controller.setExternalDeposits(poolKey, true);
    }

    function test_setExternalDeposits_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(admin);
        controller.setExternalDeposits(_badHookKey(), true);
    }

    /**********************************************************************************************/
    /*** resumePool Tests                                                                       ***/
    /**********************************************************************************************/

    function test_resumePool_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.resumePool(poolKey);
    }

    function test_resumePool_notAdmin() external {
        _expectUnauthorized(unauthorized, DEFAULT_ADMIN_ROLE);
        vm.prank(unauthorized);
        controller.resumePool(poolKey);

        // The freezer path is strictly de-escalatory: pausing is the freezer's lever, resuming
        // is admin-only.
        _expectUnauthorized(freezer, DEFAULT_ADMIN_ROLE);
        vm.prank(freezer);
        controller.resumePool(poolKey);
    }

    function test_resumePool_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(admin);
        controller.resumePool(_badHookKey());
    }

    /**********************************************************************************************/
    /*** refreshVaultApproval Tests                                                             ***/
    /**********************************************************************************************/

    function test_refreshVaultApproval_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.refreshVaultApproval(poolKey, poolKey.currency0);
    }

    function test_refreshVaultApproval_notAdmin() external {
        _expectUnauthorized(unauthorized, DEFAULT_ADMIN_ROLE);
        vm.prank(unauthorized);
        controller.refreshVaultApproval(poolKey, poolKey.currency0);

        _expectUnauthorized(allocator, DEFAULT_ADMIN_ROLE);
        vm.prank(allocator);
        controller.refreshVaultApproval(poolKey, poolKey.currency0);
    }

    function test_refreshVaultApproval_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(admin);
        controller.refreshVaultApproval(_badHookKey(), poolKey.currency0);
    }

    /**********************************************************************************************/
    /*** acceptHookOwnership Tests                                                              ***/
    /**********************************************************************************************/

    function test_acceptHookOwnership_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.acceptHookOwnership();
    }

    function test_acceptHookOwnership_notAdmin() external {
        _expectUnauthorized(unauthorized, DEFAULT_ADMIN_ROLE);
        vm.prank(unauthorized);
        controller.acceptHookOwnership();

        _expectUnauthorized(allocator, DEFAULT_ADMIN_ROLE);
        vm.prank(allocator);
        controller.acceptHookOwnership();
    }

    /**********************************************************************************************/
    /*** transferHookOwnership Tests                                                            ***/
    /**********************************************************************************************/

    function test_transferHookOwnership_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.transferHookOwnership(makeAddr("newOwner"));
    }

    function test_transferHookOwnership_notAdmin() external {
        _expectUnauthorized(unauthorized, DEFAULT_ADMIN_ROLE);
        vm.prank(unauthorized);
        controller.transferHookOwnership(makeAddr("newOwner"));

        _expectUnauthorized(allocator, DEFAULT_ADMIN_ROLE);
        vm.prank(allocator);
        controller.transferHookOwnership(makeAddr("newOwner"));
    }

    function test_transferHookOwnership_zeroNewOwner() external {
        vm.expectRevert("DualPoolFacet/zero-new-owner");
        vm.prank(admin);
        controller.transferHookOwnership(address(0));
    }

    /**********************************************************************************************/
    /*** pausePool Tests                                                                        ***/
    /**********************************************************************************************/

    function test_pausePool_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.pausePool(poolKey);
    }

    function test_pausePool_notFreezer() external {
        _expectUnauthorized(unauthorized, FREEZER_ROLE);
        vm.prank(unauthorized);
        controller.pausePool(poolKey);

        _expectUnauthorized(allocator, FREEZER_ROLE);
        vm.prank(allocator);
        controller.pausePool(poolKey);

        _expectUnauthorized(admin, FREEZER_ROLE);
        vm.prank(admin);
        controller.pausePool(poolKey);
    }

    function test_pausePool_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(freezer);
        controller.pausePool(_badHookKey());
    }

    /**********************************************************************************************/
    /*** emergencyRevokeVault Tests                                                             ***/
    /**********************************************************************************************/

    function test_emergencyRevokeVault_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.emergencyRevokeVault(poolKey);
    }

    function test_emergencyRevokeVault_notFreezer() external {
        _expectUnauthorized(unauthorized, FREEZER_ROLE);
        vm.prank(unauthorized);
        controller.emergencyRevokeVault(poolKey);

        _expectUnauthorized(allocator, FREEZER_ROLE);
        vm.prank(allocator);
        controller.emergencyRevokeVault(poolKey);

        _expectUnauthorized(admin, FREEZER_ROLE);
        vm.prank(admin);
        controller.emergencyRevokeVault(poolKey);
    }

    function test_emergencyRevokeVault_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(freezer);
        controller.emergencyRevokeVault(_badHookKey());
    }

    /**********************************************************************************************/
    /*** deposit Tests                                                                          ***/
    /**********************************************************************************************/

    function test_deposit_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.deposit(poolKey, 1e18, 1e18, 1e18);
    }

    function test_deposit_notAllocator() external {
        _expectUnauthorized(unauthorized, ALLOCATOR_ROLE);
        vm.prank(unauthorized);
        controller.deposit(poolKey, 1e18, 1e18, 1e18);

        _expectUnauthorized(admin, ALLOCATOR_ROLE);
        vm.prank(admin);
        controller.deposit(poolKey, 1e18, 1e18, 1e18);
    }

    function test_deposit_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(allocator);
        controller.deposit(_badHookKey(), 1e18, 1e18, 1e18);
    }

    function test_deposit_maxSlippageNotSet() external {
        vm.expectRevert("DualPoolFacet/max-slippage-not-set");
        vm.prank(allocator);
        controller.deposit(poolKey, 1e18, 1e18, 1e18);
    }

    function test_deposit_priceRatioNotSet() external {
        _setMaxSlippage(0.99e18);

        vm.expectRevert("DualPoolFacet/price-ratio-not-set");
        vm.prank(allocator);
        controller.deposit(poolKey, 1e18, 1e18, 1e18);
    }

    // A zero-share deposit moves no tokens and consumes no rate limit, so it would otherwise reach
    // the hook and re-arm the ALMProxy's deposit lock for free.
    function test_deposit_zeroShares() external {
        _onboard();

        vm.expectRevert("DualPoolFacet/zero-shares");
        vm.prank(allocator);
        controller.deposit(poolKey, 0, 0, 0);
    }

    /**********************************************************************************************/
    /*** withdraw Tests                                                                         ***/
    /**********************************************************************************************/

    function test_withdraw_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.withdraw(poolKey, 1e18, 0, 0);
    }

    function test_withdraw_notAllocator() external {
        _expectUnauthorized(unauthorized, ALLOCATOR_ROLE);
        vm.prank(unauthorized);
        controller.withdraw(poolKey, 1e18, 0, 0);

        _expectUnauthorized(admin, ALLOCATOR_ROLE);
        vm.prank(admin);
        controller.withdraw(poolKey, 1e18, 0, 0);
    }

    function test_withdraw_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(allocator);
        controller.withdraw(_badHookKey(), 1e18, 0, 0);
    }

    function test_withdraw_maxSlippageNotSet() external {
        vm.expectRevert("DualPoolFacet/max-slippage-not-set");
        vm.prank(allocator);
        controller.withdraw(poolKey, 1e18, 0, 0);
    }

    function test_withdraw_priceRatioNotSet() external {
        _setMaxSlippage(0.99e18);

        vm.expectRevert("DualPoolFacet/price-ratio-not-set");
        vm.prank(allocator);
        controller.withdraw(poolKey, 1e18, 0, 0);
    }

    function test_withdraw_zeroShares() external {
        _onboard();

        vm.expectRevert("DualPoolFacet/zero-shares");
        vm.prank(allocator);
        controller.withdraw(poolKey, 0, 0, 0);
    }

    /**********************************************************************************************/
    /*** swap Tests                                                                             ***/
    /**********************************************************************************************/

    function test_swap_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.swap(poolKey, Currency.unwrap(poolKey.currency0), 1e18, 1e18);
    }

    function test_swap_notAllocator() external {
        _expectUnauthorized(unauthorized, ALLOCATOR_ROLE);
        vm.prank(unauthorized);
        controller.swap(poolKey, Currency.unwrap(poolKey.currency0), 1e18, 1e18);

        _expectUnauthorized(admin, ALLOCATOR_ROLE);
        vm.prank(admin);
        controller.swap(poolKey, Currency.unwrap(poolKey.currency0), 1e18, 1e18);
    }

    function test_swap_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(allocator);
        controller.swap(_badHookKey(), Currency.unwrap(poolKey.currency0), 1e18, 1e18);
    }

    function test_swap_maxSlippageNotSet() external {
        vm.expectRevert("DualPoolFacet/max-slippage-not-set");
        vm.prank(allocator);
        controller.swap(poolKey, Currency.unwrap(poolKey.currency0), 1e18, 1e18);
    }

    function test_swap_priceRatioNotSet() external {
        _setMaxSlippage(0.99e18);

        vm.expectRevert("DualPoolFacet/price-ratio-not-set");
        vm.prank(allocator);
        controller.swap(poolKey, Currency.unwrap(poolKey.currency0), 1e18, 1e18);
    }

    function test_swap_invalidTokenIn() external {
        _onboard();

        vm.expectRevert("DualPoolFacet/invalid-tokenIn");
        vm.prank(allocator);
        controller.swap(poolKey, makeAddr("otherToken"), 1e18, 1e18);
    }

    function test_swap_zeroAmountIn() external {
        _onboard();

        vm.expectRevert("DualPoolFacet/zero-amount-in");
        vm.prank(allocator);
        controller.swap(poolKey, Currency.unwrap(poolKey.currency0), 0, 0);
    }

    function test_swap_zeroMaxAmountRateLimit() external {
        _onboard();

        // The swap rate limit is decreased before any token interaction, so an unseeded rate
        // limit is the next boundary after config checks.
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        controller.swap(poolKey, Currency.unwrap(poolKey.currency0), 1e18, 1e18);
    }

    /**********************************************************************************************/
    /*** getAggregateDepositRateLimitKey Tests                                                  ***/
    /**********************************************************************************************/

    function test_getAggregateDepositRateLimitKey() external {
        bytes32 keyPrefix = keccak256("LIMIT_DUALPOOL_DEPOSIT");

        assertEq(controller.getAggregateDepositRateLimitKey(poolId), makeBytes32Key(keyPrefix, poolId));
    }

    /**********************************************************************************************/
    /*** getAssetDepositRateLimitKey Tests                                                      ***/
    /**********************************************************************************************/

    function test_getAssetDepositRateLimitKey() external {
        bytes32 keyPrefix = keccak256("LIMIT_DUALPOOL_DEPOSIT");
        address token     = makeAddr("token");

        assertEq(
            controller.getAssetDepositRateLimitKey(poolId, token),
            makeAddressBytes32Key(keyPrefix, token, poolId)
        );
    }

    /**********************************************************************************************/
    /*** getSwapRateLimitKey Tests                                                              ***/
    /**********************************************************************************************/

    function test_getSwapRateLimitKey() external {
        bytes32 keyPrefix = keccak256("LIMIT_DUALPOOL_SWAP");
        address token     = makeAddr("token");

        assertEq(
            controller.getSwapRateLimitKey(poolId, token),
            makeAddressBytes32Key(keyPrefix, token, poolId)
        );
    }

    /**********************************************************************************************/
    /*** getAggregateWithdrawRateLimitKey Tests                                                 ***/
    /**********************************************************************************************/

    function test_getAggregateWithdrawRateLimitKey() external {
        bytes32 keyPrefix = keccak256("LIMIT_DUALPOOL_WITHDRAW");

        assertEq(
            controller.getAggregateWithdrawRateLimitKey(poolId),
            makeBytes32Key(keyPrefix, poolId)
        );
    }

    /**********************************************************************************************/
    /*** getAssetWithdrawRateLimitKey Tests                                                     ***/
    /**********************************************************************************************/

    function test_getAssetWithdrawRateLimitKey() external {
        bytes32 keyPrefix = keccak256("LIMIT_DUALPOOL_WITHDRAW");
        address token     = makeAddr("token");

        assertEq(
            controller.getAssetWithdrawRateLimitKey(poolId, token),
            makeAddressBytes32Key(keyPrefix, token, poolId)
        );
    }

}
