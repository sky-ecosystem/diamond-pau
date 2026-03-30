// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    IAsyncRedeemManagerLike,
    ICentrifugeV3VaultLike,
    IERC20Like
} from "../interfaces/Centrifuge.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface ISpokeLike {

    event InitiateTransferShares(
        uint16          centrifugeId,
        uint64  indexed poolId,
        bytes16 indexed scId,
        address indexed sender,
        bytes32         destinationAddress,
        uint128         amount
    );

}

abstract contract Centrifuge_TestBase is ForkTestBase {

    address internal constant CENTRIFUGE_VAULT = 0x1121F4e21eD8B9BC1BB9A2952cDD8639aC897784; // DEJAAA_VAULT_USDC

    uint16 internal constant DESTINATION_CENTRIFUGE_ID = 5; // Avalanche Centrifuge ID

    ICentrifugeV3VaultLike internal centrifugeVault = ICentrifugeV3VaultLike(CENTRIFUGE_VAULT);

    IAsyncRedeemManagerLike internal manager;

    address internal root;
    address internal spoke;
    address internal vaultToken;

    uint64 internal poolId;

    bytes16 internal scId;

    address internal unauthorized = makeAddr("unauthorized");

    function setUp() public override {
        super.setUp();

        root       = centrifugeVault.root();
        vaultToken = centrifugeVault.share();
        manager    = IAsyncRedeemManagerLike(centrifugeVault.manager());
        spoke      = manager.spoke();

        poolId = centrifugeVault.poolId();
        scId   = centrifugeVault.scId();
    }

    function _getBlock() internal pure override returns (uint256) {
        return 22968402;  // Jul 21, 2025
    }

}

contract MainnetController_CentrifugeV3_TransferShares_Tests is Centrifuge_TestBase {

    function test_transferSharesCentrifuge_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.transferSharesCentrifuge(CENTRIFUGE_VAULT, 1_000_000e6, DESTINATION_CENTRIFUGE_ID);
    }

    function test_transferSharesCentrifuge_zeroMaxAmount() external {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        mainnetController.transferSharesCentrifuge(CENTRIFUGE_VAULT, 1_000_000e6, DESTINATION_CENTRIFUGE_ID);
    }

    function test_transferSharesCentrifuge_rateLimitedBoundary() external {
        vm.startPrank(SPARK_PROXY);

        bytes32 target = bytes32(uint256(uint160(makeAddr("centrifugeRecipient"))));

        rateLimits.setRateLimitData(
            keccak256(abi.encode(
                mainnetController.LIMIT_CENTRIFUGE_TRANSFER(),
                CENTRIFUGE_VAULT,
                DESTINATION_CENTRIFUGE_ID
            )),
            10_000_000e6,
            0
        );

        mainnetController.setCentrifugeRecipient(DESTINATION_CENTRIFUGE_ID, target);

        vm.stopPrank();

        // Setup token balances
        deal(vaultToken, almProxy, 10_000_000e6);
        deal(RELAYER, 1 ether);  // Gas cost for Centrifuge

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        mainnetController.transferSharesCentrifuge{value: 0.1 ether}(
            CENTRIFUGE_VAULT,
            10_000_000e6 + 1,
            DESTINATION_CENTRIFUGE_ID
        );

        vm.prank(RELAYER);
        mainnetController.transferSharesCentrifuge{value: 0.1 ether}(
            CENTRIFUGE_VAULT,
            10_000_000e6,
            DESTINATION_CENTRIFUGE_ID
        );
    }

        function test_transferSharesCentrifuge_invalidCentrifugeId() external {
        vm.startPrank(SPARK_PROXY);

        rateLimits.setRateLimitData(
            keccak256(abi.encode(
                mainnetController.LIMIT_CENTRIFUGE_TRANSFER(),
                CENTRIFUGE_VAULT,
                DESTINATION_CENTRIFUGE_ID
            )),
            10_000_000e6,
            0
        );

        vm.stopPrank();

        // Setup token balances
        deal(vaultToken, almProxy, 10_000_000e6);
        deal(RELAYER, 1 ether);  // Gas cost for Centrifuge

        vm.expectRevert("CentrifugeFacet/id-not-configured");
        vm.prank(RELAYER);
        mainnetController.transferSharesCentrifuge{value: 0.1 ether}(
            CENTRIFUGE_VAULT,
            10_000_000e6,
            DESTINATION_CENTRIFUGE_ID
        );
    }

    function test_transferSharesCentrifuge() external {
        vm.startPrank(SPARK_PROXY);

        bytes32 target = bytes32(uint256(uint160(makeAddr("centrifugeRecipient"))));

        rateLimits.setRateLimitData(
            keccak256(abi.encode(
                mainnetController.LIMIT_CENTRIFUGE_TRANSFER(),
                CENTRIFUGE_VAULT,
                DESTINATION_CENTRIFUGE_ID
            )),
            10_000_000e6,
            0
        );

        mainnetController.setCentrifugeRecipient(DESTINATION_CENTRIFUGE_ID, target);

        vm.stopPrank();

        // Setup token balances
        deal(address(vaultToken), almProxy, 10_000_000e6);
        deal(RELAYER, 1 ether);  // Gas cost for Centrifuge

        // Issue shares at price 1.0
        vm.prank(root);
        manager.issuedShares(
            poolId,
            scId,
            10_000_000e6,
            1e18
        );

        uint256 proxyBalanceBefore     = IERC20Like(vaultToken).balanceOf(almProxy);
        uint256 shareTotalSupplyBefore = IERC20Like(vaultToken).totalSupply();

        vm.expectEmit(spoke);
        emit ISpokeLike.InitiateTransferShares(
            DESTINATION_CENTRIFUGE_ID,
            poolId,
            scId,
            almProxy,
            target,
            10_000_000e6
        );

        vm.prank(RELAYER);
        mainnetController.transferSharesCentrifuge{value: 0.1 ether}(
            CENTRIFUGE_VAULT,
            10_000_000e6,
            DESTINATION_CENTRIFUGE_ID
        );

        uint256 proxyBalanceAfter     = IERC20Like(vaultToken).balanceOf(almProxy);
        uint256 shareTotalSupplyAfter = IERC20Like(vaultToken).totalSupply();

        assertEq(proxyBalanceAfter,     proxyBalanceBefore     - 10_000_000e6);
        assertEq(shareTotalSupplyAfter, shareTotalSupplyBefore - 10_000_000e6);
    }

}
