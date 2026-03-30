// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Base as GroveBase } from "../../lib/grove-address-registry/src/Base.sol";
import { Base as SparkBase } from "../../lib/spark-address-registry/src/Base.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface IMerklDistributorLike {

    event OperatorToggled(address indexed user, address indexed operator, bool isWhitelisted);

    function toggleOperator(address user, address operator) external;

    function operators(address user, address operator) external view returns (uint256);

    function claim(
        address[]   calldata users,
        address[]   calldata tokens,
        uint256[]   calldata amounts,
        bytes32[][] calldata proofs
    ) external;

}

interface IOperatorLike {

    error InvalidProof();

    error NotWhitelisted();

}

abstract contract Merkl_TestBase is ForkTestBase {

    address internal operator1    = makeAddr("operator1");
    address internal operator2    = makeAddr("operator2");
    address internal unauthorized = makeAddr("unauthorized");

    IMerklDistributorLike internal merklDistributor = IMerklDistributorLike(GroveBase.MERKL_DISTRIBUTOR);

}

contract ForeignController_Merkl_ToggleOperator_Tests is Merkl_TestBase {

    function test_toggleOperatorMerkl_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        foreignController.toggleOperatorMerkl(operator1);
    }

    function test_toggleOperatorMerkl_singleOperator() external {
        assertEq(merklDistributor.operators(almProxy, operator1), 0);

        vm.expectEmit(address(merklDistributor));
        emit IMerklDistributorLike.OperatorToggled(almProxy, operator1, true);

        vm.prank(RELAYER);
        foreignController.toggleOperatorMerkl(operator1);

        assertEq(merklDistributor.operators(almProxy, operator1), 1);

        vm.expectEmit(address(merklDistributor));
        emit IMerklDistributorLike.OperatorToggled(almProxy, operator1, false);

        vm.prank(RELAYER);
        foreignController.toggleOperatorMerkl(operator1);

        assertEq(merklDistributor.operators(almProxy, operator1), 0);

        vm.expectEmit(address(merklDistributor));
        emit IMerklDistributorLike.OperatorToggled(almProxy, operator1, true);

        vm.prank(RELAYER);
        foreignController.toggleOperatorMerkl(operator1);

        assertEq(merklDistributor.operators(almProxy, operator1), 1);
    }

    function test_toggleOperatorMerkl_multipleOperators() external {
        assertEq(merklDistributor.operators(almProxy, operator1), 0);
        assertEq(merklDistributor.operators(almProxy, operator2), 0);

        vm.prank(RELAYER);
        foreignController.toggleOperatorMerkl(operator1);

        assertEq(merklDistributor.operators(almProxy, operator1), 1);
        assertEq(merklDistributor.operators(almProxy, operator2), 0);

        vm.prank(RELAYER);
        foreignController.toggleOperatorMerkl(operator1);

        assertEq(merklDistributor.operators(almProxy, operator1), 0);
        assertEq(merklDistributor.operators(almProxy, operator2), 0);

        vm.prank(RELAYER);
        foreignController.toggleOperatorMerkl(operator1);

        assertEq(merklDistributor.operators(almProxy, operator1), 1);
        assertEq(merklDistributor.operators(almProxy, operator2), 0);

        vm.prank(RELAYER);
        foreignController.toggleOperatorMerkl(operator2);

        assertEq(merklDistributor.operators(almProxy, operator1), 1);
        assertEq(merklDistributor.operators(almProxy, operator2), 1);
    }

    function test_toggleOperatorMerkl_attemptClaim() external {
        address[]   memory users   = new address[](1);
        address[]   memory tokens  = new address[](1);
        uint256[]   memory amounts = new uint256[](1);
        bytes32[][] memory proofs  = new bytes32[][](1);

        users[0]     = almProxy;
        tokens[0]    = address(0);
        amounts[0]   = 299_033.458789039331965803e18;
        proofs[0]    = new bytes32[](1);
        proofs[0][0] = bytes32(0);

        vm.expectRevert(IOperatorLike.NotWhitelisted.selector);
        vm.prank(operator1);
        merklDistributor.claim(users, tokens, amounts, proofs);

        vm.prank(RELAYER);
        foreignController.toggleOperatorMerkl(operator1);

        // Hitting the InvalidProof() error proves that we are whitelisted as operator1
        // (https://github.com/AngleProtocol/merkl-contracts/blob/e4c49c1fbfb274029d31969adf70ca6aeec689f0/contracts/Distributor.sol#L378-L383)
        vm.expectRevert(IOperatorLike.InvalidProof.selector);
        vm.prank(operator1);
        merklDistributor.claim(users, tokens, amounts, proofs);
    }

}
