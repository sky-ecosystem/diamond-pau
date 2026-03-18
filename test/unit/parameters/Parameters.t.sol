// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;

import { Test } from "../../../lib/forge-std/src/Test.sol";

import { IParameters } from "../../../src/interfaces/IParameters.sol";

import { Parameters } from "../../../src/Parameters.sol";

contract ParametersHarness is Parameters {

    constructor(address[] memory admins) Parameters(admins) {}

    function __setParameter(string calldata key, address value) external {
        _setParameter(key, bytes32(uint256(uint160(value))));
    }

    function __setParameter(string calldata key, bool value) external {
        __setParameter(key, value ? bytes32(uint256(1)) : bytes32(uint256(0)));
    }

    function __setParameter(string calldata key, uint256 value) external {
        __setParameter(key, bytes32(value));
    }

    function __setParameter(string calldata key, bytes32 value) public {
        _parameters[key] = value;
    }

}

contract Parameters_Tests is Test {

    ParametersHarness internal parameters;

    address internal admin1       = 0x0000000000000000000000000000000000000001;
    address internal admin2       = 0x0000000000000000000000000000000000000002;
    address internal unauthorized = 0x0000000000000000000000000000000000000003;

    function setUp() external {
        address[] memory admins = new address[](2);
        admins[0] = admin1;
        admins[1] = admin2;

        parameters = new ParametersHarness(admins);
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor_emptyAdmins() external {
        vm.expectRevert(IParameters.EmptyAdmins.selector);
        new ParametersHarness(new address[](0));
    }

    function test_constructor_zeroAdmin() external {
        vm.expectRevert(IParameters.ZeroAdmin.selector);
        new ParametersHarness(new address[](1));
    }

    function test_constructor() external {
        address[] memory admins = new address[](2);
        admins[0] = admin1;
        admins[1] = admin2;

        vm.expectEmit();
        emit IParameters.ParameterSet(
            "sky.pau.parameters.isAdmin.0x0000000000000000000000000000000000000001",
            "sky.pau.parameters.isAdmin.0x0000000000000000000000000000000000000001",
            bytes32(uint256(1))
        );

        vm.expectEmit();
        emit IParameters.ParameterSet(
            "sky.pau.parameters.isAdmin.0x0000000000000000000000000000000000000002",
            "sky.pau.parameters.isAdmin.0x0000000000000000000000000000000000000002",
            bytes32(uint256(1))
        );

        new ParametersHarness(admins);
    }

    /**********************************************************************************************/
    /*** Set One Tests                                                                          ***/
    /**********************************************************************************************/

    function test_set_one_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IParameters.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        parameters.set("", 0);
    }

    function test_set_one() external {
        vm.expectEmit(address(parameters));
        emit IParameters.ParameterSet("this.is.a.parameter", "this.is.a.parameter", bytes32(uint256(1010101)));

        vm.prank(admin1);
        parameters.set("this.is.a.parameter", bytes32(uint256(1010101)));

        assertEq(parameters.get("this.is.a.parameter"), bytes32(uint256(1010101)));
    }

    /**********************************************************************************************/
    /*** Set Several Tests                                                                      ***/
    /**********************************************************************************************/

    function test_set_several_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IParameters.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        parameters.set(new string[](0), new bytes32[](0));
    }

    function test_set_several_noKeys() external {
        vm.expectRevert(IParameters.NoKeys.selector);
        vm.prank(admin1);
        parameters.set(new string[](0), new bytes32[](0));
    }

    function test_set_several_arrayLengthMismatch() external {
        vm.expectRevert(IParameters.ArrayLengthMismatch.selector);
        vm.prank(admin1);
        parameters.set(new string[](1), new bytes32[](2));
    }

    function test_set_several() external {
        string[] memory keys_ = new string[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(1010101));
        values_[1] = bytes32(uint256(2020202));

        vm.expectEmit(address(parameters));
        emit IParameters.ParameterSet(keys_[0], keys_[0], values_[0]);

        vm.expectEmit(address(parameters));
        emit IParameters.ParameterSet(keys_[1], keys_[1], values_[1]);

        vm.prank(admin1);
        parameters.set(keys_, values_);

        assertEq(parameters.get(keys_[0]), bytes32(uint256(1010101)));
        assertEq(parameters.get(keys_[1]), bytes32(uint256(2020202)));
    }

    /**********************************************************************************************/
    /*** Is Admin Tests                                                                         ***/
    /**********************************************************************************************/

    function test_isAdmin() external {
        assertFalse(parameters.isAdmin(address(3)));

        parameters.__setParameter(
            "sky.pau.parameters.isAdmin.0x0000000000000000000000000000000000000003",
            bytes32(uint256(1))
        );

        assertTrue(parameters.isAdmin(address(3)));

        assertEq(
            keccak256(bytes(parameters.ADMIN_PARAMETER_KEY_PREFIX())),
            keccak256(bytes("sky.pau.parameters.isAdmin"))
        );
    }

    /**********************************************************************************************/
    /*** Get One Tests                                                                          ***/
    /**********************************************************************************************/

    function test_get_one() external {
        parameters.__setParameter("this.is.a.parameter", bytes32(uint256(1010101)));

        assertEq(parameters.get("this.is.a.parameter"),                           bytes32(uint256(1010101)));
        assertEq(parameters.get(string(bytes("this.is.a.parameter"))),            bytes32(uint256(1010101)));
        assertEq(parameters.get(string(abi.encodePacked("this.is.a.parameter"))), bytes32(uint256(1010101)));

        // NOTE: Encoding a string non-compactly is a different key.
        assertNotEq(parameters.get(string(abi.encode("this.is.a.parameter"))), bytes32(uint256(1010101)));
    }

    /**********************************************************************************************/
    /*** Get Several Tests                                                                      ***/
    /**********************************************************************************************/

    function test_get_several_noKeys() external {
        vm.expectRevert(IParameters.NoKeys.selector);
        parameters.get(new string[](0));
    }

    function test_get_several() external {
        string[] memory keys_ = new string[](2);

        keys_[0] = "this.is.a.parameter";
        keys_[1] = "this.is.another.parameter";

        bytes32[] memory expectedValues_ = new bytes32[](2);
        expectedValues_[0] = bytes32(uint256(1010101));
        expectedValues_[1] = bytes32(uint256(2020202));

        parameters.__setParameter(keys_[0], expectedValues_[0]);
        parameters.__setParameter(keys_[1], expectedValues_[1]);

        bytes32[] memory values_ = parameters.get(keys_);

        assertEq(values_.length, keys_.length);
        assertEq(values_[0], expectedValues_[0]);
        assertEq(values_[1], expectedValues_[1]);
    }

}
