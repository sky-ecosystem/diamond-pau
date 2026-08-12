// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Currency } from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IHooks } from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { IEnumerableIntegrations }               from "../../../src/interfaces/IEnumerableIntegrations.sol";
import { IFacet }                                from "../../../src/facets/IFacet.sol";
import { IDualPoolFacet }                        from "../../../src/facets/dual-pool/IDualPoolFacet.sol";
import { makeAddressBytes32Key, makeBytes32Key } from "../../../src/libraries/RateLimitHelpers.sol";

import { DualPoolFacet } from "../../../src/facets/dual-pool/DualPoolFacet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function deposit(
        PoolKey calldata key,
        uint256 sharesToMint,
        uint128 amount0Max,
        uint128 amount1Max
    ) external;

    function setMaxSlippage(bytes32 poolId, uint256 maxSlippage) external;

    function setPriceRatio(bytes32 poolId, uint256 priceRatio) external;

    function withdraw(
        PoolKey calldata key,
        uint256 sharesToBurn,
        uint128 amount0Min,
        uint128 amount1Min
    ) external;

    function hook() external view returns (address);

    function getAggregateDepositRateLimitKey(bytes32 poolId) external pure returns (bytes32);

    function getAggregateWithdrawRateLimitKey(bytes32 poolId) external pure returns (bytes32);

    function getAssetDepositRateLimitKey(bytes32 poolId, address token) external pure returns (bytes32);

    function getAssetWithdrawRateLimitKey(bytes32 poolId, address token) external pure returns (bytes32);

    function getMaxSlippage(bytes32 poolId) external view returns (uint256);

    function getPriceRatio(bytes32 poolId) external view returns (uint256);

    function getShares(PoolKey calldata key) external view returns (uint256);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

contract Controller_DualPoolFacet_Tests is Integration_TestBase {

    address internal hookAddress = makeAddr("hook");

    IControllerLike internal controller;

    PoolKey internal poolKey;

    bytes32 internal poolId;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new DualPoolFacet({ hook_ : hookAddress }));

        vm.label(facet, "DualPoolFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](12);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.deposit.selector,
            IDualPoolFacet.deposit.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerLike.setMaxSlippage.selector,
            IDualPoolFacet.setMaxSlippage.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IControllerLike.setPriceRatio.selector,
            IDualPoolFacet.setPriceRatio.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IControllerLike.withdraw.selector,
            IDualPoolFacet.withdraw.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IControllerLike.hook.selector,
            IDualPoolFacet.hook.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IControllerLike.getAggregateDepositRateLimitKey.selector,
            IDualPoolFacet.getAggregateDepositRateLimitKey.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IControllerLike.getAggregateWithdrawRateLimitKey.selector,
            IDualPoolFacet.getAggregateWithdrawRateLimitKey.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IControllerLike.getAssetDepositRateLimitKey.selector,
            IDualPoolFacet.getAssetDepositRateLimitKey.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IControllerLike.getAssetWithdrawRateLimitKey.selector,
            IDualPoolFacet.getAssetWithdrawRateLimitKey.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            IControllerLike.getMaxSlippage.selector,
            IDualPoolFacet.getMaxSlippage.selector
        );

        wires[10] = IEnumerableIntegrations.Wire(
            IControllerLike.getPriceRatio.selector,
            IDualPoolFacet.getPriceRatio.selector
        );

        wires[11] = IEnumerableIntegrations.Wire(
            IControllerLike.getShares.selector,
            IDualPoolFacet.getShares.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("DUAL_POOL_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "DUAL_POOL_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);

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

    function _expectUnauthorized(address caller, bytes32 role) internal {
        vm.expectRevert(
            abi.encodeWithSelector(IFacet.AccessControlUnauthorizedAccount.selector, caller, role)
        );
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor_zeroHook() external {
        vm.expectRevert("DualPoolFacet/zero-hook");
        new DualPoolFacet(address(0));
    }

    function test_constructor() external {
        DualPoolFacet facet = new DualPoolFacet(hookAddress);

        assertEq(facet.hook(), hookAddress);
    }

    /**********************************************************************************************/
    /*** Immutables Tests                                                                       ***/
    /**********************************************************************************************/

    function test_immutables() external {
        assertEq(controller.hook(), hookAddress);
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
