// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;

import { Test } from "../../../lib/forge-std/src/Test.sol";

import { IParameterHelpersErrors } from "../../../src/interfaces/IParameterHelpersErrors.sol";

import { ParameterHelpers } from "../../../src/ParameterHelpers.sol";

contract ParameterHelpersHarness {

    /**********************************************************************************************/
    /*** Boolean Functions                                                                      ***/
    /**********************************************************************************************/

    function fromBool(bool value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBool(value);
    }

    function toBool(bytes32 parameter) external pure returns (bool value) {
        return ParameterHelpers.toBool(parameter);
    }

    /**********************************************************************************************/
    /*** Address Functions                                                                      ***/
    /**********************************************************************************************/

    function fromAddress(address value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromAddress(value);
    }

    function toAddress(bytes32 parameter) external pure returns (address value) {
        return ParameterHelpers.toAddress(parameter);
    }

    /**********************************************************************************************/
    /*** Bytes Functions                                                                        ***/
    /**********************************************************************************************/

    function fromBytes1(bytes1 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes1(value);
    }

    function toBytes1(bytes32 parameter) external pure returns (bytes1 value) {
        return ParameterHelpers.toBytes1(parameter);
    }

    function fromBytes2(bytes2 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes2(value);
    }

    function toBytes2(bytes32 parameter) external pure returns (bytes2 value) {
        return ParameterHelpers.toBytes2(parameter);
    }

    function fromBytes3(bytes3 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes3(value);
    }

    function toBytes3(bytes32 parameter) external pure returns (bytes3 value) {
        return ParameterHelpers.toBytes3(parameter);
    }

    function fromBytes4(bytes4 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes4(value);
    }

    function toBytes4(bytes32 parameter) external pure returns (bytes4 value) {
        return ParameterHelpers.toBytes4(parameter);
    }

    function fromBytes5(bytes5 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes5(value);
    }

    function toBytes5(bytes32 parameter) external pure returns (bytes5 value) {
        return ParameterHelpers.toBytes5(parameter);
    }

    function fromBytes6(bytes6 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes6(value);
    }

    function toBytes6(bytes32 parameter) external pure returns (bytes6 value) {
        return ParameterHelpers.toBytes6(parameter);
    }

    function fromBytes7(bytes7 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes7(value);
    }

    function toBytes7(bytes32 parameter) external pure returns (bytes7 value) {
        return ParameterHelpers.toBytes7(parameter);
    }

    function fromBytes8(bytes8 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes8(value);
    }

    function toBytes8(bytes32 parameter) external pure returns (bytes8 value) {
        return ParameterHelpers.toBytes8(parameter);
    }

    function fromBytes9(bytes9 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes9(value);
    }

    function toBytes9(bytes32 parameter) external pure returns (bytes9 value) {
        return ParameterHelpers.toBytes9(parameter);
    }

    function fromBytes10(bytes10 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes10(value);
    }

    function toBytes10(bytes32 parameter) external pure returns (bytes10 value) {
        return ParameterHelpers.toBytes10(parameter);
    }

    function fromBytes11(bytes11 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes11(value);
    }

    function toBytes11(bytes32 parameter) external pure returns (bytes11 value) {
        return ParameterHelpers.toBytes11(parameter);
    }

    function fromBytes12(bytes12 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes12(value);
    }

    function toBytes12(bytes32 parameter) external pure returns (bytes12 value) {
        return ParameterHelpers.toBytes12(parameter);
    }

    function fromBytes13(bytes13 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes13(value);
    }

    function toBytes13(bytes32 parameter) external pure returns (bytes13 value) {
        return ParameterHelpers.toBytes13(parameter);
    }

    function fromBytes14(bytes14 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes14(value);
    }

    function toBytes14(bytes32 parameter) external pure returns (bytes14 value) {
        return ParameterHelpers.toBytes14(parameter);
    }

    function fromBytes15(bytes15 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes15(value);
    }

    function toBytes15(bytes32 parameter) external pure returns (bytes15 value) {
        return ParameterHelpers.toBytes15(parameter);
    }

    function fromBytes16(bytes16 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes16(value);
    }

    function toBytes16(bytes32 parameter) external pure returns (bytes16 value) {
        return ParameterHelpers.toBytes16(parameter);
    }

    function fromBytes17(bytes17 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes17(value);
    }

    function toBytes17(bytes32 parameter) external pure returns (bytes17 value) {
        return ParameterHelpers.toBytes17(parameter);
    }

    function fromBytes18(bytes18 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes18(value);
    }

    function toBytes18(bytes32 parameter) external pure returns (bytes18 value) {
        return ParameterHelpers.toBytes18(parameter);
    }

    function fromBytes19(bytes19 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes19(value);
    }

    function toBytes19(bytes32 parameter) external pure returns (bytes19 value) {
        return ParameterHelpers.toBytes19(parameter);
    }

    function fromBytes20(bytes20 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes20(value);
    }

    function toBytes20(bytes32 parameter) external pure returns (bytes20 value) {
        return ParameterHelpers.toBytes20(parameter);
    }

    function fromBytes21(bytes21 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes21(value);
    }

    function toBytes21(bytes32 parameter) external pure returns (bytes21 value) {
        return ParameterHelpers.toBytes21(parameter);
    }

    function fromBytes22(bytes22 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes22(value);
    }

    function toBytes22(bytes32 parameter) external pure returns (bytes22 value) {
        return ParameterHelpers.toBytes22(parameter);
    }

    function fromBytes23(bytes23 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes23(value);
    }

    function toBytes23(bytes32 parameter) external pure returns (bytes23 value) {
        return ParameterHelpers.toBytes23(parameter);
    }

    function fromBytes24(bytes24 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes24(value);
    }

    function toBytes24(bytes32 parameter) external pure returns (bytes24 value) {
        return ParameterHelpers.toBytes24(parameter);
    }

    function fromBytes25(bytes25 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes25(value);
    }

    function toBytes25(bytes32 parameter) external pure returns (bytes25 value) {
        return ParameterHelpers.toBytes25(parameter);
    }

    function fromBytes26(bytes26 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes26(value);
    }

    function toBytes26(bytes32 parameter) external pure returns (bytes26 value) {
        return ParameterHelpers.toBytes26(parameter);
    }

    function fromBytes27(bytes27 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes27(value);
    }

    function toBytes27(bytes32 parameter) external pure returns (bytes27 value) {
        return ParameterHelpers.toBytes27(parameter);
    }

    function fromBytes28(bytes28 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes28(value);
    }

    function toBytes28(bytes32 parameter) external pure returns (bytes28 value) {
        return ParameterHelpers.toBytes28(parameter);
    }

    function fromBytes29(bytes29 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes29(value);
    }

    function toBytes29(bytes32 parameter) external pure returns (bytes29 value) {
        return ParameterHelpers.toBytes29(parameter);
    }

    function fromBytes30(bytes30 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes30(value);
    }

    function toBytes30(bytes32 parameter) external pure returns (bytes30 value) {
        return ParameterHelpers.toBytes30(parameter);
    }

    function fromBytes31(bytes31 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes31(value);
    }

    function toBytes31(bytes32 parameter) external pure returns (bytes31 value) {
        return ParameterHelpers.toBytes31(parameter);
    }

    function fromBytes32(bytes32 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromBytes32(value);
    }

    function toBytes32(bytes32 parameter) external pure returns (bytes32 value) {
        return ParameterHelpers.toBytes32(parameter);
    }

    /**********************************************************************************************/
    /*** Int Functions                                                                          ***/
    /**********************************************************************************************/

    function fromInt8(int8 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt8(value);
    }

    function toInt8(bytes32 parameter) external pure returns (int8 value) {
        return ParameterHelpers.toInt8(parameter);
    }

    function fromInt16(int16 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt16(value);
    }

    function toInt16(bytes32 parameter) external pure returns (int16 value) {
        return ParameterHelpers.toInt16(parameter);
    }

    function fromInt24(int24 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt24(value);
    }

    function toInt24(bytes32 parameter) external pure returns (int24 value) {
        return ParameterHelpers.toInt24(parameter);
    }

    function fromInt32(int32 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt32(value);
    }

    function toInt32(bytes32 parameter) external pure returns (int32 value) {
        return ParameterHelpers.toInt32(parameter);
    }

    function fromInt40(int40 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt40(value);
    }

    function toInt40(bytes32 parameter) external pure returns (int40 value) {
        return ParameterHelpers.toInt40(parameter);
    }

    function fromInt48(int48 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt48(value);
    }

    function toInt48(bytes32 parameter) external pure returns (int48 value) {
        return ParameterHelpers.toInt48(parameter);
    }

    function fromInt56(int56 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt56(value);
    }

    function toInt56(bytes32 parameter) external pure returns (int56 value) {
        return ParameterHelpers.toInt56(parameter);
    }

    function fromInt64(int64 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt64(value);
    }

    function toInt64(bytes32 parameter) external pure returns (int64 value) {
        return ParameterHelpers.toInt64(parameter);
    }

    function fromInt72(int72 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt72(value);
    }

    function toInt72(bytes32 parameter) external pure returns (int72 value) {
        return ParameterHelpers.toInt72(parameter);
    }

    function fromInt80(int80 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt80(value);
    }

    function toInt80(bytes32 parameter) external pure returns (int80 value) {
        return ParameterHelpers.toInt80(parameter);
    }

    function fromInt88(int88 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt88(value);
    }

    function toInt88(bytes32 parameter) external pure returns (int88 value) {
        return ParameterHelpers.toInt88(parameter);
    }

    function fromInt96(int96 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt96(value);
    }

    function toInt96(bytes32 parameter) external pure returns (int96 value) {
        return ParameterHelpers.toInt96(parameter);
    }

    function fromInt104(int104 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt104(value);
    }

    function toInt104(bytes32 parameter) external pure returns (int104 value) {
        return ParameterHelpers.toInt104(parameter);
    }

    function fromInt112(int112 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt112(value);
    }

    function toInt112(bytes32 parameter) external pure returns (int112 value) {
        return ParameterHelpers.toInt112(parameter);
    }

    function fromInt120(int120 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt120(value);
    }

    function toInt120(bytes32 parameter) external pure returns (int120 value) {
        return ParameterHelpers.toInt120(parameter);
    }

    function fromInt128(int128 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt128(value);
    }

    function toInt128(bytes32 parameter) external pure returns (int128 value) {
        return ParameterHelpers.toInt128(parameter);
    }

    function fromInt136(int136 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt136(value);
    }

    function toInt136(bytes32 parameter) external pure returns (int136 value) {
        return ParameterHelpers.toInt136(parameter);
    }

    function fromInt144(int144 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt144(value);
    }

    function toInt144(bytes32 parameter) external pure returns (int144 value) {
        return ParameterHelpers.toInt144(parameter);
    }

    function fromInt152(int152 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt152(value);
    }

    function toInt152(bytes32 parameter) external pure returns (int152 value) {
        return ParameterHelpers.toInt152(parameter);
    }

    function fromInt160(int160 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt160(value);
    }

    function toInt160(bytes32 parameter) external pure returns (int160 value) {
        return ParameterHelpers.toInt160(parameter);
    }

    function fromInt168(int168 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt168(value);
    }

    function toInt168(bytes32 parameter) external pure returns (int168 value) {
        return ParameterHelpers.toInt168(parameter);
    }

    function fromInt176(int176 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt176(value);
    }

    function toInt176(bytes32 parameter) external pure returns (int176 value) {
        return ParameterHelpers.toInt176(parameter);
    }

    function fromInt184(int184 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt184(value);
    }

    function toInt184(bytes32 parameter) external pure returns (int184 value) {
        return ParameterHelpers.toInt184(parameter);
    }

    function fromInt192(int192 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt192(value);
    }

    function toInt192(bytes32 parameter) external pure returns (int192 value) {
        return ParameterHelpers.toInt192(parameter);
    }

    function fromInt200(int200 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt200(value);
    }

    function toInt200(bytes32 parameter) external pure returns (int200 value) {
        return ParameterHelpers.toInt200(parameter);
    }

    function fromInt208(int208 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt208(value);
    }

    function toInt208(bytes32 parameter) external pure returns (int208 value) {
        return ParameterHelpers.toInt208(parameter);
    }

    function fromInt216(int216 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt216(value);
    }

    function toInt216(bytes32 parameter) external pure returns (int216 value) {
        return ParameterHelpers.toInt216(parameter);
    }

    function fromInt224(int224 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt224(value);
    }

    function toInt224(bytes32 parameter) external pure returns (int224 value) {
        return ParameterHelpers.toInt224(parameter);
    }

    function fromInt232(int232 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt232(value);
    }

    function toInt232(bytes32 parameter) external pure returns (int232 value) {
        return ParameterHelpers.toInt232(parameter);
    }

    function fromInt240(int240 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt240(value);
    }

    function toInt240(bytes32 parameter) external pure returns (int240 value) {
        return ParameterHelpers.toInt240(parameter);
    }

    function fromInt248(int248 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt248(value);
    }

    function toInt248(bytes32 parameter) external pure returns (int248 value) {
        return ParameterHelpers.toInt248(parameter);
    }

    function fromInt256(int256 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromInt256(value);
    }

    function toInt256(bytes32 parameter) external pure returns (int256 value) {
        return ParameterHelpers.toInt256(parameter);
    }

    /**********************************************************************************************/
    /*** Uint Functions                                                                         ***/
    /**********************************************************************************************/

    function fromUint8(uint8 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint8(value);
    }

    function toUint8(bytes32 parameter) external pure returns (uint8 value) {
        return ParameterHelpers.toUint8(parameter);
    }

    function fromUint16(uint16 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint16(value);
    }

    function toUint16(bytes32 parameter) external pure returns (uint16 value) {
        return ParameterHelpers.toUint16(parameter);
    }

    function fromUint24(uint24 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint24(value);
    }

    function toUint24(bytes32 parameter) external pure returns (uint24 value) {
        return ParameterHelpers.toUint24(parameter);
    }

    function fromUint32(uint32 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint32(value);
    }

    function toUint32(bytes32 parameter) external pure returns (uint32 value) {
        return ParameterHelpers.toUint32(parameter);
    }

    function fromUint40(uint40 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint40(value);
    }

    function toUint40(bytes32 parameter) external pure returns (uint40 value) {
        return ParameterHelpers.toUint40(parameter);
    }

    function fromUint48(uint48 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint48(value);
    }

    function toUint48(bytes32 parameter) external pure returns (uint48 value) {
        return ParameterHelpers.toUint48(parameter);
    }

    function fromUint56(uint56 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint56(value);
    }

    function toUint56(bytes32 parameter) external pure returns (uint56 value) {
        return ParameterHelpers.toUint56(parameter);
    }

    function fromUint64(uint64 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint64(value);
    }

    function toUint64(bytes32 parameter) external pure returns (uint64 value) {
        return ParameterHelpers.toUint64(parameter);
    }

    function fromUint72(uint72 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint72(value);
    }

    function toUint72(bytes32 parameter) external pure returns (uint72 value) {
        return ParameterHelpers.toUint72(parameter);
    }

    function fromUint80(uint80 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint80(value);
    }

    function toUint80(bytes32 parameter) external pure returns (uint80 value) {
        return ParameterHelpers.toUint80(parameter);
    }

    function fromUint88(uint88 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint88(value);
    }

    function toUint88(bytes32 parameter) external pure returns (uint88 value) {
        return ParameterHelpers.toUint88(parameter);
    }

    function fromUint96(uint96 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint96(value);
    }

    function toUint96(bytes32 parameter) external pure returns (uint96 value) {
        return ParameterHelpers.toUint96(parameter);
    }

    function fromUint104(uint104 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint104(value);
    }

    function toUint104(bytes32 parameter) external pure returns (uint104 value) {
        return ParameterHelpers.toUint104(parameter);
    }

    function fromUint112(uint112 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint112(value);
    }

    function toUint112(bytes32 parameter) external pure returns (uint112 value) {
        return ParameterHelpers.toUint112(parameter);
    }

    function fromUint120(uint120 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint120(value);
    }

    function toUint120(bytes32 parameter) external pure returns (uint120 value) {
        return ParameterHelpers.toUint120(parameter);
    }

    function fromUint128(uint128 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint128(value);
    }

    function toUint128(bytes32 parameter) external pure returns (uint128 value) {
        return ParameterHelpers.toUint128(parameter);
    }

    function fromUint136(uint136 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint136(value);
    }

    function toUint136(bytes32 parameter) external pure returns (uint136 value) {
        return ParameterHelpers.toUint136(parameter);
    }

    function fromUint144(uint144 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint144(value);
    }

    function toUint144(bytes32 parameter) external pure returns (uint144 value) {
        return ParameterHelpers.toUint144(parameter);
    }

    function fromUint152(uint152 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint152(value);
    }

    function toUint152(bytes32 parameter) external pure returns (uint152 value) {
        return ParameterHelpers.toUint152(parameter);
    }

    function fromUint160(uint160 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint160(value);
    }

    function toUint160(bytes32 parameter) external pure returns (uint160 value) {
        return ParameterHelpers.toUint160(parameter);
    }

    function fromUint168(uint168 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint168(value);
    }

    function toUint168(bytes32 parameter) external pure returns (uint168 value) {
        return ParameterHelpers.toUint168(parameter);
    }

    function fromUint176(uint176 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint176(value);
    }

    function toUint176(bytes32 parameter) external pure returns (uint176 value) {
        return ParameterHelpers.toUint176(parameter);
    }

    function fromUint184(uint184 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint184(value);
    }

    function toUint184(bytes32 parameter) external pure returns (uint184 value) {
        return ParameterHelpers.toUint184(parameter);
    }

    function fromUint192(uint192 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint192(value);
    }

    function toUint192(bytes32 parameter) external pure returns (uint192 value) {
        return ParameterHelpers.toUint192(parameter);
    }

    function fromUint200(uint200 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint200(value);
    }

    function toUint200(bytes32 parameter) external pure returns (uint200 value) {
        return ParameterHelpers.toUint200(parameter);
    }

    function fromUint208(uint208 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint208(value);
    }

    function toUint208(bytes32 parameter) external pure returns (uint208 value) {
        return ParameterHelpers.toUint208(parameter);
    }

    function fromUint216(uint216 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint216(value);
    }

    function toUint216(bytes32 parameter) external pure returns (uint216 value) {
        return ParameterHelpers.toUint216(parameter);
    }

    function fromUint224(uint224 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint224(value);
    }

    function toUint224(bytes32 parameter) external pure returns (uint224 value) {
        return ParameterHelpers.toUint224(parameter);
    }

    function fromUint232(uint232 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint232(value);
    }

    function toUint232(bytes32 parameter) external pure returns (uint232 value) {
        return ParameterHelpers.toUint232(parameter);
    }

    function fromUint240(uint240 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint240(value);
    }

    function toUint240(bytes32 parameter) external pure returns (uint240 value) {
        return ParameterHelpers.toUint240(parameter);
    }

    function fromUint248(uint248 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint248(value);
    }

    function toUint248(bytes32 parameter) external pure returns (uint248 value) {
        return ParameterHelpers.toUint248(parameter);
    }

    function fromUint256(uint256 value) external pure returns (bytes32 parameter) {
        return ParameterHelpers.fromUint256(value);
    }

    function toUint256(bytes32 parameter) external pure returns (uint256 value) {
        return ParameterHelpers.toUint256(parameter);
    }

}

contract ParameterHelpers_Tests is Test {

    ParameterHelpersHarness internal harness;

    function setUp() external {
        harness = new ParameterHelpersHarness();
    }

    /**********************************************************************************************/
    /*** Boolean Tests                                                                          ***/
    /**********************************************************************************************/

    function test_fromBool() external view {
        assertEq(harness.fromBool(true),  bytes32(uint256(1)));
        assertEq(harness.fromBool(false), bytes32(uint256(0)));
    }

    function test_toBool_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBool(bytes32(uint256(2)));
    }

    function test_toBool() external view {
        assertEq(harness.toBool(bytes32(uint256(1))), true);
        assertEq(harness.toBool(bytes32(uint256(0))), false);
    }

    function test_fromBool_roundTrip() external view {
        assertEq(harness.toBool(harness.fromBool(true)),  true);
        assertEq(harness.toBool(harness.fromBool(false)), false);
    }

    /**********************************************************************************************/
    /*** Address Tests                                                                          ***/
    /**********************************************************************************************/

    function test_fromAddress() external {
        address sample = makeAddr("sample");
        assertEq(harness.fromAddress(sample), bytes32(uint256(uint160(sample))));
    }

    function test_toAddress_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toAddress(bytes32(uint256(type(uint160).max) + 1));
    }

    function test_toAddress() external {
        address sample = makeAddr("sample");
        assertEq(harness.toAddress(bytes32(uint256(uint160(sample)))), sample);
    }

    function test_fromAddress_roundTrip() external {
        address sample = makeAddr("sample");
        assertEq(harness.toAddress(harness.fromAddress(sample)), sample);
    }

    /**********************************************************************************************/
    /*** Bytes Tests                                                                            ***/
    /**********************************************************************************************/

    function test_fromBytes1() external view {
        bytes1 sample = bytes1(type(uint8).max);
        assertEq(harness.fromBytes1(sample), bytes32(uint256(uint8(sample))));
    }

    function test_toBytes1_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes1(bytes32(uint256(type(uint8).max) + 1));
    }

    function test_toBytes1() external view {
        bytes1 sample = bytes1(type(uint8).max);
        assertEq(harness.toBytes1(bytes32(uint256(uint8(sample)))), sample);
    }

    function test_fromBytes1_roundTrip() external view {
        bytes1 sample = bytes1(type(uint8).max);
        assertEq(harness.toBytes1(harness.fromBytes1(sample)), sample);
    }

    function test_fromBytes2() external view {
        bytes2 sample = bytes2(type(uint16).max);
        assertEq(harness.fromBytes2(sample), bytes32(uint256(uint16(sample))));
    }

    function test_toBytes2_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes2(bytes32(uint256(type(uint16).max) + 1));
    }

    function test_toBytes2() external view {
        bytes2 sample = bytes2(type(uint16).max);
        assertEq(harness.toBytes2(bytes32(uint256(uint16(sample)))), sample);
    }

    function test_fromBytes2_roundTrip() external view {
        bytes2 sample = bytes2(type(uint16).max);
        assertEq(harness.toBytes2(harness.fromBytes2(sample)), sample);
    }

    function test_fromBytes3() external view {
        bytes3 sample = bytes3(type(uint24).max);
        assertEq(harness.fromBytes3(sample), bytes32(uint256(uint24(sample))));
    }

    function test_toBytes3_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes3(bytes32(uint256(type(uint24).max) + 1));
    }

    function test_toBytes3() external view {
        bytes3 sample = bytes3(type(uint24).max);
        assertEq(harness.toBytes3(bytes32(uint256(uint24(sample)))), sample);
    }

    function test_fromBytes3_roundTrip() external view {
        bytes3 sample = bytes3(type(uint24).max);
        assertEq(harness.toBytes3(harness.fromBytes3(sample)), sample);
    }

    function test_fromBytes4() external view {
        bytes4 sample = bytes4(type(uint32).max);
        assertEq(harness.fromBytes4(sample), bytes32(uint256(uint32(sample))));
    }

    function test_toBytes4_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes4(bytes32(uint256(type(uint32).max) + 1));
    }

    function test_toBytes4() external view {
        bytes4 sample = bytes4(type(uint32).max);
        assertEq(harness.toBytes4(bytes32(uint256(uint32(sample)))), sample);
    }

    function test_fromBytes4_roundTrip() external view {
        bytes4 sample = bytes4(type(uint32).max);
        assertEq(harness.toBytes4(harness.fromBytes4(sample)), sample);
    }

    function test_fromBytes5() external view {
        bytes5 sample = bytes5(type(uint40).max);
        assertEq(harness.fromBytes5(sample), bytes32(uint256(uint40(sample))));
    }

    function test_toBytes5_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes5(bytes32(uint256(type(uint40).max) + 1));
    }

    function test_toBytes5() external view {
        bytes5 sample = bytes5(type(uint40).max);
        assertEq(harness.toBytes5(bytes32(uint256(uint40(sample)))), sample);
    }

    function test_fromBytes5_roundTrip() external view {
        bytes5 sample = bytes5(type(uint40).max);
        assertEq(harness.toBytes5(harness.fromBytes5(sample)), sample);
    }

    function test_fromBytes6() external view {
        bytes6 sample = bytes6(type(uint48).max);
        assertEq(harness.fromBytes6(sample), bytes32(uint256(uint48(sample))));
    }

    function test_toBytes6_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes6(bytes32(uint256(type(uint48).max) + 1));
    }

    function test_toBytes6() external view {
        bytes6 sample = bytes6(type(uint48).max);
        assertEq(harness.toBytes6(bytes32(uint256(uint48(sample)))), sample);
    }

    function test_fromBytes6_roundTrip() external view {
        bytes6 sample = bytes6(type(uint48).max);
        assertEq(harness.toBytes6(harness.fromBytes6(sample)), sample);
    }

    function test_fromBytes7() external view {
        bytes7 sample = bytes7(type(uint56).max);
        assertEq(harness.fromBytes7(sample), bytes32(uint256(uint56(sample))));
    }

    function test_toBytes7_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes7(bytes32(uint256(type(uint56).max) + 1));
    }

    function test_toBytes7() external view {
        bytes7 sample = bytes7(type(uint56).max);
        assertEq(harness.toBytes7(bytes32(uint256(uint56(sample)))), sample);
    }

    function test_fromBytes7_roundTrip() external view {
        bytes7 sample = bytes7(type(uint56).max);
        assertEq(harness.toBytes7(harness.fromBytes7(sample)), sample);
    }

    function test_fromBytes8() external view {
        bytes8 sample = bytes8(type(uint64).max);
        assertEq(harness.fromBytes8(sample), bytes32(uint256(uint64(sample))));
    }

    function test_toBytes8_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes8(bytes32(uint256(type(uint64).max) + 1));
    }

    function test_toBytes8() external view {
        bytes8 sample = bytes8(type(uint64).max);
        assertEq(harness.toBytes8(bytes32(uint256(uint64(sample)))), sample);
    }

    function test_fromBytes8_roundTrip() external view {
        bytes8 sample = bytes8(type(uint64).max);
        assertEq(harness.toBytes8(harness.fromBytes8(sample)), sample);
    }

    function test_fromBytes9() external view {
        bytes9 sample = bytes9(type(uint72).max);
        assertEq(harness.fromBytes9(sample), bytes32(uint256(uint72(sample))));
    }

    function test_toBytes9_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes9(bytes32(uint256(type(uint72).max) + 1));
    }

    function test_toBytes9() external view {
        bytes9 sample = bytes9(type(uint72).max);
        assertEq(harness.toBytes9(bytes32(uint256(uint72(sample)))), sample);
    }

    function test_fromBytes9_roundTrip() external view {
        bytes9 sample = bytes9(type(uint72).max);
        assertEq(harness.toBytes9(harness.fromBytes9(sample)), sample);
    }

    function test_fromBytes10() external view {
        bytes10 sample = bytes10(type(uint80).max);
        assertEq(harness.fromBytes10(sample), bytes32(uint256(uint80(sample))));
    }

    function test_toBytes10_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes10(bytes32(uint256(type(uint80).max) + 1));
    }

    function test_toBytes10() external view {
        bytes10 sample = bytes10(type(uint80).max);
        assertEq(harness.toBytes10(bytes32(uint256(uint80(sample)))), sample);
    }

    function test_fromBytes10_roundTrip() external view {
        bytes10 sample = bytes10(type(uint80).max);
        assertEq(harness.toBytes10(harness.fromBytes10(sample)), sample);
    }

    function test_fromBytes11() external view {
        bytes11 sample = bytes11(type(uint88).max);
        assertEq(harness.fromBytes11(sample), bytes32(uint256(uint88(sample))));
    }

    function test_toBytes11_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes11(bytes32(uint256(type(uint88).max) + 1));
    }

    function test_toBytes11() external view {
        bytes11 sample = bytes11(type(uint88).max);
        assertEq(harness.toBytes11(bytes32(uint256(uint88(sample)))), sample);
    }

    function test_fromBytes11_roundTrip() external view {
        bytes11 sample = bytes11(type(uint88).max);
        assertEq(harness.toBytes11(harness.fromBytes11(sample)), sample);
    }

    function test_fromBytes12() external view {
        bytes12 sample = bytes12(type(uint96).max);
        assertEq(harness.fromBytes12(sample), bytes32(uint256(uint96(sample))));
    }

    function test_toBytes12_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes12(bytes32(uint256(type(uint96).max) + 1));
    }

    function test_toBytes12() external view {
        bytes12 sample = bytes12(type(uint96).max);
        assertEq(harness.toBytes12(bytes32(uint256(uint96(sample)))), sample);
    }

    function test_fromBytes12_roundTrip() external view {
        bytes12 sample = bytes12(type(uint96).max);
        assertEq(harness.toBytes12(harness.fromBytes12(sample)), sample);
    }

    function test_fromBytes13() external view {
        bytes13 sample = bytes13(type(uint104).max);
        assertEq(harness.fromBytes13(sample), bytes32(uint256(uint104(sample))));
    }

    function test_toBytes13_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes13(bytes32(uint256(type(uint104).max) + 1));
    }

    function test_toBytes13() external view {
        bytes13 sample = bytes13(type(uint104).max);
        assertEq(harness.toBytes13(bytes32(uint256(uint104(sample)))), sample);
    }

    function test_fromBytes13_roundTrip() external view {
        bytes13 sample = bytes13(type(uint104).max);
        assertEq(harness.toBytes13(harness.fromBytes13(sample)), sample);
    }

    function test_fromBytes14() external view {
        bytes14 sample = bytes14(type(uint112).max);
        assertEq(harness.fromBytes14(sample), bytes32(uint256(uint112(sample))));
    }

    function test_toBytes14_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes14(bytes32(uint256(type(uint112).max) + 1));
    }

    function test_toBytes14() external view {
        bytes14 sample = bytes14(type(uint112).max);
        assertEq(harness.toBytes14(bytes32(uint256(uint112(sample)))), sample);
    }

    function test_fromBytes14_roundTrip() external view {
        bytes14 sample = bytes14(type(uint112).max);
        assertEq(harness.toBytes14(harness.fromBytes14(sample)), sample);
    }

    function test_fromBytes15() external view {
        bytes15 sample = bytes15(type(uint120).max);
        assertEq(harness.fromBytes15(sample), bytes32(uint256(uint120(sample))));
    }

    function test_toBytes15_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes15(bytes32(uint256(type(uint120).max) + 1));
    }

    function test_toBytes15() external view {
        bytes15 sample = bytes15(type(uint120).max);
        assertEq(harness.toBytes15(bytes32(uint256(uint120(sample)))), sample);
    }

    function test_fromBytes15_roundTrip() external view {
        bytes15 sample = bytes15(type(uint120).max);
        assertEq(harness.toBytes15(harness.fromBytes15(sample)), sample);
    }

    function test_fromBytes16() external view {
        bytes16 sample = bytes16(type(uint128).max);
        assertEq(harness.fromBytes16(sample), bytes32(uint256(uint128(sample))));
    }

    function test_toBytes16_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes16(bytes32(uint256(type(uint128).max) + 1));
    }

    function test_toBytes16() external view {
        bytes16 sample = bytes16(type(uint128).max);
        assertEq(harness.toBytes16(bytes32(uint256(uint128(sample)))), sample);
    }

    function test_fromBytes16_roundTrip() external view {
        bytes16 sample = bytes16(type(uint128).max);
        assertEq(harness.toBytes16(harness.fromBytes16(sample)), sample);
    }

    function test_fromBytes17() external view {
        bytes17 sample = bytes17(type(uint136).max);
        assertEq(harness.fromBytes17(sample), bytes32(uint256(uint136(sample))));
    }

    function test_toBytes17_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes17(bytes32(uint256(type(uint136).max) + 1));
    }

    function test_toBytes17() external view {
        bytes17 sample = bytes17(type(uint136).max);
        assertEq(harness.toBytes17(bytes32(uint256(uint136(sample)))), sample);
    }

    function test_fromBytes17_roundTrip() external view {
        bytes17 sample = bytes17(type(uint136).max);
        assertEq(harness.toBytes17(harness.fromBytes17(sample)), sample);
    }

    function test_fromBytes18() external view {
        bytes18 sample = bytes18(type(uint144).max);
        assertEq(harness.fromBytes18(sample), bytes32(uint256(uint144(sample))));
    }

    function test_toBytes18_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes18(bytes32(uint256(type(uint144).max) + 1));
    }

    function test_toBytes18() external view {
        bytes18 sample = bytes18(type(uint144).max);
        assertEq(harness.toBytes18(bytes32(uint256(uint144(sample)))), sample);
    }

    function test_fromBytes18_roundTrip() external view {
        bytes18 sample = bytes18(type(uint144).max);
        assertEq(harness.toBytes18(harness.fromBytes18(sample)), sample);
    }

    function test_fromBytes19() external view {
        bytes19 sample = bytes19(type(uint152).max);
        assertEq(harness.fromBytes19(sample), bytes32(uint256(uint152(sample))));
    }

    function test_toBytes19_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes19(bytes32(uint256(type(uint152).max) + 1));
    }

    function test_toBytes19() external view {
        bytes19 sample = bytes19(type(uint152).max);
        assertEq(harness.toBytes19(bytes32(uint256(uint152(sample)))), sample);
    }

    function test_fromBytes19_roundTrip() external view {
        bytes19 sample = bytes19(type(uint152).max);
        assertEq(harness.toBytes19(harness.fromBytes19(sample)), sample);
    }

    function test_fromBytes20() external view {
        bytes20 sample = bytes20(type(uint160).max);
        assertEq(harness.fromBytes20(sample), bytes32(uint256(uint160(sample))));
    }

    function test_toBytes20_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes20(bytes32(uint256(type(uint160).max) + 1));
    }

    function test_toBytes20() external view {
        bytes20 sample = bytes20(type(uint160).max);
        assertEq(harness.toBytes20(bytes32(uint256(uint160(sample)))), sample);
    }

    function test_fromBytes20_roundTrip() external view {
        bytes20 sample = bytes20(type(uint160).max);
        assertEq(harness.toBytes20(harness.fromBytes20(sample)), sample);
    }

    function test_fromBytes21() external view {
        bytes21 sample = bytes21(type(uint168).max);
        assertEq(harness.fromBytes21(sample), bytes32(uint256(uint168(sample))));
    }

    function test_toBytes21_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes21(bytes32(uint256(type(uint168).max) + 1));
    }

    function test_toBytes21() external view {
        bytes21 sample = bytes21(type(uint168).max);
        assertEq(harness.toBytes21(bytes32(uint256(uint168(sample)))), sample);
    }

    function test_fromBytes21_roundTrip() external view {
        bytes21 sample = bytes21(type(uint168).max);
        assertEq(harness.toBytes21(harness.fromBytes21(sample)), sample);
    }

    function test_fromBytes22() external view {
        bytes22 sample = bytes22(type(uint176).max);
        assertEq(harness.fromBytes22(sample), bytes32(uint256(uint176(sample))));
    }

    function test_toBytes22_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes22(bytes32(uint256(type(uint176).max) + 1));
    }

    function test_toBytes22() external view {
        bytes22 sample = bytes22(type(uint176).max);
        assertEq(harness.toBytes22(bytes32(uint256(uint176(sample)))), sample);
    }

    function test_fromBytes22_roundTrip() external view {
        bytes22 sample = bytes22(type(uint176).max);
        assertEq(harness.toBytes22(harness.fromBytes22(sample)), sample);
    }

    function test_fromBytes23() external view {
        bytes23 sample = bytes23(type(uint184).max);
        assertEq(harness.fromBytes23(sample), bytes32(uint256(uint184(sample))));
    }

    function test_toBytes23_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes23(bytes32(uint256(type(uint184).max) + 1));
    }

    function test_toBytes23() external view {
        bytes23 sample = bytes23(type(uint184).max);
        assertEq(harness.toBytes23(bytes32(uint256(uint184(sample)))), sample);
    }

    function test_fromBytes23_roundTrip() external view {
        bytes23 sample = bytes23(type(uint184).max);
        assertEq(harness.toBytes23(harness.fromBytes23(sample)), sample);
    }

    function test_fromBytes24() external view {
        bytes24 sample = bytes24(type(uint192).max);
        assertEq(harness.fromBytes24(sample), bytes32(uint256(uint192(sample))));
    }

    function test_toBytes24_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes24(bytes32(uint256(type(uint192).max) + 1));
    }

    function test_toBytes24() external view {
        bytes24 sample = bytes24(type(uint192).max);
        assertEq(harness.toBytes24(bytes32(uint256(uint192(sample)))), sample);
    }

    function test_fromBytes24_roundTrip() external view {
        bytes24 sample = bytes24(type(uint192).max);
        assertEq(harness.toBytes24(harness.fromBytes24(sample)), sample);
    }

    function test_fromBytes25() external view {
        bytes25 sample = bytes25(type(uint200).max);
        assertEq(harness.fromBytes25(sample), bytes32(uint256(uint200(sample))));
    }

    function test_toBytes25_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes25(bytes32(uint256(type(uint200).max) + 1));
    }

    function test_toBytes25() external view {
        bytes25 sample = bytes25(type(uint200).max);
        assertEq(harness.toBytes25(bytes32(uint256(uint200(sample)))), sample);
    }

    function test_fromBytes25_roundTrip() external view {
        bytes25 sample = bytes25(type(uint200).max);
        assertEq(harness.toBytes25(harness.fromBytes25(sample)), sample);
    }

    function test_fromBytes26() external view {
        bytes26 sample = bytes26(type(uint208).max);
        assertEq(harness.fromBytes26(sample), bytes32(uint256(uint208(sample))));
    }

    function test_toBytes26_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes26(bytes32(uint256(type(uint208).max) + 1));
    }

    function test_toBytes26() external view {
        bytes26 sample = bytes26(type(uint208).max);
        assertEq(harness.toBytes26(bytes32(uint256(uint208(sample)))), sample);
    }

    function test_fromBytes26_roundTrip() external view {
        bytes26 sample = bytes26(type(uint208).max);
        assertEq(harness.toBytes26(harness.fromBytes26(sample)), sample);
    }

    function test_fromBytes27() external view {
        bytes27 sample = bytes27(type(uint216).max);
        assertEq(harness.fromBytes27(sample), bytes32(uint256(uint216(sample))));
    }

    function test_toBytes27_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes27(bytes32(uint256(type(uint216).max) + 1));
    }

    function test_toBytes27() external view {
        bytes27 sample = bytes27(type(uint216).max);
        assertEq(harness.toBytes27(bytes32(uint256(uint216(sample)))), sample);
    }

    function test_fromBytes27_roundTrip() external view {
        bytes27 sample = bytes27(type(uint216).max);
        assertEq(harness.toBytes27(harness.fromBytes27(sample)), sample);
    }

    function test_fromBytes28() external view {
        bytes28 sample = bytes28(type(uint224).max);
        assertEq(harness.fromBytes28(sample), bytes32(uint256(uint224(sample))));
    }

    function test_toBytes28_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes28(bytes32(uint256(type(uint224).max) + 1));
    }

    function test_toBytes28() external view {
        bytes28 sample = bytes28(type(uint224).max);
        assertEq(harness.toBytes28(bytes32(uint256(uint224(sample)))), sample);
    }

    function test_fromBytes28_roundTrip() external view {
        bytes28 sample = bytes28(type(uint224).max);
        assertEq(harness.toBytes28(harness.fromBytes28(sample)), sample);
    }

    function test_fromBytes29() external view {
        bytes29 sample = bytes29(type(uint232).max);
        assertEq(harness.fromBytes29(sample), bytes32(uint256(uint232(sample))));
    }

    function test_toBytes29_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes29(bytes32(uint256(type(uint232).max) + 1));
    }

    function test_toBytes29() external view {
        bytes29 sample = bytes29(type(uint232).max);
        assertEq(harness.toBytes29(bytes32(uint256(uint232(sample)))), sample);
    }

    function test_fromBytes29_roundTrip() external view {
        bytes29 sample = bytes29(type(uint232).max);
        assertEq(harness.toBytes29(harness.fromBytes29(sample)), sample);
    }

    function test_fromBytes30() external view {
        bytes30 sample = bytes30(type(uint240).max);
        assertEq(harness.fromBytes30(sample), bytes32(uint256(uint240(sample))));
    }

    function test_toBytes30_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes30(bytes32(uint256(type(uint240).max) + 1));
    }

    function test_toBytes30() external view {
        bytes30 sample = bytes30(type(uint240).max);
        assertEq(harness.toBytes30(bytes32(uint256(uint240(sample)))), sample);
    }

    function test_fromBytes30_roundTrip() external view {
        bytes30 sample = bytes30(type(uint240).max);
        assertEq(harness.toBytes30(harness.fromBytes30(sample)), sample);
    }

    function test_fromBytes31() external view {
        bytes31 sample = bytes31(type(uint248).max);
        assertEq(harness.fromBytes31(sample), bytes32(uint256(uint248(sample))));
    }

    function test_toBytes31_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toBytes31(bytes32(uint256(type(uint248).max) + 1));
    }

    function test_toBytes31() external view {
        bytes31 sample = bytes31(type(uint248).max);
        assertEq(harness.toBytes31(bytes32(uint256(uint248(sample)))), sample);
    }

    function test_fromBytes31_roundTrip() external view {
        bytes31 sample = bytes31(type(uint248).max);
        assertEq(harness.toBytes31(harness.fromBytes31(sample)), sample);
    }

    function test_fromBytes32() external view {
        bytes32 sample = bytes32(type(uint256).max);
        assertEq(harness.fromBytes32(sample), bytes32(uint256(uint256(sample))));
    }

    function test_toBytes32() external view {
        bytes32 sample = bytes32(type(uint256).max);
        assertEq(harness.toBytes32(bytes32(uint256(uint256(sample)))), sample);
    }

    function test_fromBytes32_roundTrip() external view {
        bytes32 sample = bytes32(type(uint256).max);
        assertEq(harness.toBytes32(harness.fromBytes32(sample)), sample);
    }

    /**********************************************************************************************/
    /*** Int Tests                                                                              ***/
    /**********************************************************************************************/

    function test_fromInt8() external view {
        int8 sample = type(int8).max;
        assertEq(harness.fromInt8(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt8_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt8(bytes32(uint256(int256(type(int8).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt8(bytes32(uint256(int256(type(int8).min) - int256(1))));
    }

    function test_toInt8() external view {
        int8 sample = type(int8).max;
        assertEq(harness.toInt8(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt8_roundTrip() external view {
        int8 sample = type(int8).max;
        assertEq(harness.toInt8(harness.fromInt8(sample)), sample);
    }

    function test_fromInt16() external view {
        int16 sample = type(int16).max;
        assertEq(harness.fromInt16(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt16_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt16(bytes32(uint256(int256(type(int16).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt16(bytes32(uint256(int256(type(int16).min) - int256(1))));
    }

    function test_toInt16() external view {
        int16 sample = type(int16).max;
        assertEq(harness.toInt16(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt16_roundTrip() external view {
        int16 sample = type(int16).max;
        assertEq(harness.toInt16(harness.fromInt16(sample)), sample);
    }

    function test_fromInt24() external view {
        int24 sample = type(int24).max;
        assertEq(harness.fromInt24(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt24_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt24(bytes32(uint256(int256(type(int24).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt24(bytes32(uint256(int256(type(int24).min) - int256(1))));
    }

    function test_toInt24() external view {
        int24 sample = type(int24).max;
        assertEq(harness.toInt24(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt24_roundTrip() external view {
        int24 sample = type(int24).max;
        assertEq(harness.toInt24(harness.fromInt24(sample)), sample);
    }

    function test_fromInt32() external view {
        int32 sample = type(int32).max;
        assertEq(harness.fromInt32(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt32_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt32(bytes32(uint256(int256(type(int32).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt32(bytes32(uint256(int256(type(int32).min) - int256(1))));
    }

    function test_toInt32() external view {
        int32 sample = type(int32).max;
        assertEq(harness.toInt32(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt32_roundTrip() external view {
        int32 sample = type(int32).max;
        assertEq(harness.toInt32(harness.fromInt32(sample)), sample);
    }

    function test_fromInt40() external view {
        int40 sample = type(int40).max;
        assertEq(harness.fromInt40(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt40_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt40(bytes32(uint256(int256(type(int40).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt40(bytes32(uint256(int256(type(int40).min) - int256(1))));
    }

    function test_toInt40() external view {
        int40 sample = type(int40).max;
        assertEq(harness.toInt40(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt40_roundTrip() external view {
        int40 sample = type(int40).max;
        assertEq(harness.toInt40(harness.fromInt40(sample)), sample);
    }

    function test_fromInt48() external view {
        int48 sample = type(int48).max;
        assertEq(harness.fromInt48(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt48_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt48(bytes32(uint256(int256(type(int48).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt48(bytes32(uint256(int256(type(int48).min) - int256(1))));
    }

    function test_toInt48() external view {
        int48 sample = type(int48).max;
        assertEq(harness.toInt48(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt48_roundTrip() external view {
        int48 sample = type(int48).max;
        assertEq(harness.toInt48(harness.fromInt48(sample)), sample);
    }

    function test_fromInt56() external view {
        int56 sample = type(int56).max;
        assertEq(harness.fromInt56(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt56_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt56(bytes32(uint256(int256(type(int56).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt56(bytes32(uint256(int256(type(int56).min) - int256(1))));
    }

    function test_toInt56() external view {
        int56 sample = type(int56).max;
        assertEq(harness.toInt56(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt56_roundTrip() external view {
        int56 sample = type(int56).max;
        assertEq(harness.toInt56(harness.fromInt56(sample)), sample);
    }

    function test_fromInt64() external view {
        int64 sample = type(int64).max;
        assertEq(harness.fromInt64(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt64_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt64(bytes32(uint256(int256(type(int64).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt64(bytes32(uint256(int256(type(int64).min) - int256(1))));
    }

    function test_toInt64() external view {
        int64 sample = type(int64).max;
        assertEq(harness.toInt64(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt64_roundTrip() external view {
        int64 sample = type(int64).max;
        assertEq(harness.toInt64(harness.fromInt64(sample)), sample);
    }

    function test_fromInt72() external view {
        int72 sample = type(int72).max;
        assertEq(harness.fromInt72(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt72_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt72(bytes32(uint256(int256(type(int72).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt72(bytes32(uint256(int256(type(int72).min) - int256(1))));
    }

    function test_toInt72() external view {
        int72 sample = type(int72).max;
        assertEq(harness.toInt72(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt72_roundTrip() external view {
        int72 sample = type(int72).max;
        assertEq(harness.toInt72(harness.fromInt72(sample)), sample);
    }

    function test_fromInt80() external view {
        int80 sample = type(int80).max;
        assertEq(harness.fromInt80(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt80_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt80(bytes32(uint256(int256(type(int80).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt80(bytes32(uint256(int256(type(int80).min) - int256(1))));
    }

    function test_toInt80() external view {
        int80 sample = type(int80).max;
        assertEq(harness.toInt80(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt80_roundTrip() external view {
        int80 sample = type(int80).max;
        assertEq(harness.toInt80(harness.fromInt80(sample)), sample);
    }

    function test_fromInt88() external view {
        int88 sample = type(int88).max;
        assertEq(harness.fromInt88(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt88_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt88(bytes32(uint256(int256(type(int88).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt88(bytes32(uint256(int256(type(int88).min) - int256(1))));
    }

    function test_toInt88() external view {
        int88 sample = type(int88).max;
        assertEq(harness.toInt88(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt88_roundTrip() external view {
        int88 sample = type(int88).max;
        assertEq(harness.toInt88(harness.fromInt88(sample)), sample);
    }

    function test_fromInt96() external view {
        int96 sample = type(int96).max;
        assertEq(harness.fromInt96(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt96_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt96(bytes32(uint256(int256(type(int96).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt96(bytes32(uint256(int256(type(int96).min) - int256(1))));
    }

    function test_toInt96() external view {
        int96 sample = type(int96).max;
        assertEq(harness.toInt96(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt96_roundTrip() external view {
        int96 sample = type(int96).max;
        assertEq(harness.toInt96(harness.fromInt96(sample)), sample);
    }

    function test_fromInt104() external view {
        int104 sample = type(int104).max;
        assertEq(harness.fromInt104(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt104_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt104(bytes32(uint256(int256(type(int104).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt104(bytes32(uint256(int256(type(int104).min) - int256(1))));
    }

    function test_toInt104() external view {
        int104 sample = type(int104).max;
        assertEq(harness.toInt104(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt104_roundTrip() external view {
        int104 sample = type(int104).max;
        assertEq(harness.toInt104(harness.fromInt104(sample)), sample);
    }

    function test_fromInt112() external view {
        int112 sample = type(int112).max;
        assertEq(harness.fromInt112(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt112_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt112(bytes32(uint256(int256(type(int112).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt112(bytes32(uint256(int256(type(int112).min) - int256(1))));
    }

    function test_toInt112() external view {
        int112 sample = type(int112).max;
        assertEq(harness.toInt112(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt112_roundTrip() external view {
        int112 sample = type(int112).max;
        assertEq(harness.toInt112(harness.fromInt112(sample)), sample);
    }

    function test_fromInt120() external view {
        int120 sample = type(int120).max;
        assertEq(harness.fromInt120(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt120_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt120(bytes32(uint256(int256(type(int120).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt120(bytes32(uint256(int256(type(int120).min) - int256(1))));
    }

    function test_toInt120() external view {
        int120 sample = type(int120).max;
        assertEq(harness.toInt120(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt120_roundTrip() external view {
        int120 sample = type(int120).max;
        assertEq(harness.toInt120(harness.fromInt120(sample)), sample);
    }

    function test_fromInt128() external view {
        int128 sample = type(int128).max;
        assertEq(harness.fromInt128(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt128_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt128(bytes32(uint256(int256(type(int128).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt128(bytes32(uint256(int256(type(int128).min) - int256(1))));
    }

    function test_toInt128() external view {
        int128 sample = type(int128).max;
        assertEq(harness.toInt128(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt128_roundTrip() external view {
        int128 sample = type(int128).max;
        assertEq(harness.toInt128(harness.fromInt128(sample)), sample);
    }

    function test_fromInt136() external view {
        int136 sample = type(int136).max;
        assertEq(harness.fromInt136(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt136_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt136(bytes32(uint256(int256(type(int136).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt136(bytes32(uint256(int256(type(int136).min) - int256(1))));
    }

    function test_toInt136() external view {
        int136 sample = type(int136).max;
        assertEq(harness.toInt136(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt136_roundTrip() external view {
        int136 sample = type(int136).max;
        assertEq(harness.toInt136(harness.fromInt136(sample)), sample);
    }

    function test_fromInt144() external view {
        int144 sample = type(int144).max;
        assertEq(harness.fromInt144(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt144_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt144(bytes32(uint256(int256(type(int144).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt144(bytes32(uint256(int256(type(int144).min) - int256(1))));
    }

    function test_toInt144() external view {
        int144 sample = type(int144).max;
        assertEq(harness.toInt144(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt144_roundTrip() external view {
        int144 sample = type(int144).max;
        assertEq(harness.toInt144(harness.fromInt144(sample)), sample);
    }

    function test_fromInt152() external view {
        int152 sample = type(int152).max;
        assertEq(harness.fromInt152(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt152_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt152(bytes32(uint256(int256(type(int152).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt152(bytes32(uint256(int256(type(int152).min) - int256(1))));
    }

    function test_toInt152() external view {
        int152 sample = type(int152).max;
        assertEq(harness.toInt152(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt152_roundTrip() external view {
        int152 sample = type(int152).max;
        assertEq(harness.toInt152(harness.fromInt152(sample)), sample);
    }

    function test_fromInt160() external view {
        int160 sample = type(int160).max;
        assertEq(harness.fromInt160(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt160_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt160(bytes32(uint256(int256(type(int160).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt160(bytes32(uint256(int256(type(int160).min) - int256(1))));
    }

    function test_toInt160() external view {
        int160 sample = type(int160).max;
        assertEq(harness.toInt160(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt160_roundTrip() external view {
        int160 sample = type(int160).max;
        assertEq(harness.toInt160(harness.fromInt160(sample)), sample);
    }

    function test_fromInt168() external view {
        int168 sample = type(int168).max;
        assertEq(harness.fromInt168(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt168_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt168(bytes32(uint256(int256(type(int168).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt168(bytes32(uint256(int256(type(int168).min) - int256(1))));
    }

    function test_toInt168() external view {
        int168 sample = type(int168).max;
        assertEq(harness.toInt168(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt168_roundTrip() external view {
        int168 sample = type(int168).max;
        assertEq(harness.toInt168(harness.fromInt168(sample)), sample);
    }

    function test_fromInt176() external view {
        int176 sample = type(int176).max;
        assertEq(harness.fromInt176(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt176_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt176(bytes32(uint256(int256(type(int176).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt176(bytes32(uint256(int256(type(int176).min) - int256(1))));
    }

    function test_toInt176() external view {
        int176 sample = type(int176).max;
        assertEq(harness.toInt176(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt176_roundTrip() external view {
        int176 sample = type(int176).max;
        assertEq(harness.toInt176(harness.fromInt176(sample)), sample);
    }

    function test_fromInt184() external view {
        int184 sample = type(int184).max;
        assertEq(harness.fromInt184(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt184_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt184(bytes32(uint256(int256(type(int184).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt184(bytes32(uint256(int256(type(int184).min) - int256(1))));
    }

    function test_toInt184() external view {
        int184 sample = type(int184).max;
        assertEq(harness.toInt184(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt184_roundTrip() external view {
        int184 sample = type(int184).max;
        assertEq(harness.toInt184(harness.fromInt184(sample)), sample);
    }

    function test_fromInt192() external view {
        int192 sample = type(int192).max;
        assertEq(harness.fromInt192(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt192_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt192(bytes32(uint256(int256(type(int192).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt192(bytes32(uint256(int256(type(int192).min) - int256(1))));
    }

    function test_toInt192() external view {
        int192 sample = type(int192).max;
        assertEq(harness.toInt192(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt192_roundTrip() external view {
        int192 sample = type(int192).max;
        assertEq(harness.toInt192(harness.fromInt192(sample)), sample);
    }

    function test_fromInt200() external view {
        int200 sample = type(int200).max;
        assertEq(harness.fromInt200(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt200_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt200(bytes32(uint256(int256(type(int200).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt200(bytes32(uint256(int256(type(int200).min) - int256(1))));
    }

    function test_toInt200() external view {
        int200 sample = type(int200).max;
        assertEq(harness.toInt200(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt200_roundTrip() external view {
        int200 sample = type(int200).max;
        assertEq(harness.toInt200(harness.fromInt200(sample)), sample);
    }

    function test_fromInt208() external view {
        int208 sample = type(int208).max;
        assertEq(harness.fromInt208(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt208_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt208(bytes32(uint256(int256(type(int208).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt208(bytes32(uint256(int256(type(int208).min) - int256(1))));
    }

    function test_toInt208() external view {
        int208 sample = type(int208).max;
        assertEq(harness.toInt208(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt208_roundTrip() external view {
        int208 sample = type(int208).max;
        assertEq(harness.toInt208(harness.fromInt208(sample)), sample);
    }

    function test_fromInt216() external view {
        int216 sample = type(int216).max;
        assertEq(harness.fromInt216(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt216_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt216(bytes32(uint256(int256(type(int216).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt216(bytes32(uint256(int256(type(int216).min) - int256(1))));
    }

    function test_toInt216() external view {
        int216 sample = type(int216).max;
        assertEq(harness.toInt216(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt216_roundTrip() external view {
        int216 sample = type(int216).max;
        assertEq(harness.toInt216(harness.fromInt216(sample)), sample);
    }

    function test_fromInt224() external view {
        int224 sample = type(int224).max;
        assertEq(harness.fromInt224(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt224_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt224(bytes32(uint256(int256(type(int224).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt224(bytes32(uint256(int256(type(int224).min) - int256(1))));
    }

    function test_toInt224() external view {
        int224 sample = type(int224).max;
        assertEq(harness.toInt224(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt224_roundTrip() external view {
        int224 sample = type(int224).max;
        assertEq(harness.toInt224(harness.fromInt224(sample)), sample);
    }

    function test_fromInt232() external view {
        int232 sample = type(int232).max;
        assertEq(harness.fromInt232(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt232_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt232(bytes32(uint256(int256(type(int232).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt232(bytes32(uint256(int256(type(int232).min) - int256(1))));
    }

    function test_toInt232() external view {
        int232 sample = type(int232).max;
        assertEq(harness.toInt232(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt232_roundTrip() external view {
        int232 sample = type(int232).max;
        assertEq(harness.toInt232(harness.fromInt232(sample)), sample);
    }

    function test_fromInt240() external view {
        int240 sample = type(int240).max;
        assertEq(harness.fromInt240(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt240_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt240(bytes32(uint256(int256(type(int240).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt240(bytes32(uint256(int256(type(int240).min) - int256(1))));
    }

    function test_toInt240() external view {
        int240 sample = type(int240).max;
        assertEq(harness.toInt240(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt240_roundTrip() external view {
        int240 sample = type(int240).max;
        assertEq(harness.toInt240(harness.fromInt240(sample)), sample);
    }

    function test_fromInt248() external view {
        int248 sample = type(int248).max;
        assertEq(harness.fromInt248(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt248_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt248(bytes32(uint256(int256(type(int248).max) + int256(1))));

        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toInt248(bytes32(uint256(int256(type(int248).min) - int256(1))));
    }

    function test_toInt248() external view {
        int240 sample = type(int240).max;
        assertEq(harness.toInt248(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt248_roundTrip() external view {
        int248 sample = type(int248).max;
        assertEq(harness.toInt248(harness.fromInt248(sample)), sample);
    }

    function test_fromInt256() external view {
        int256 sample = type(int256).max;
        assertEq(harness.fromInt256(sample), bytes32(uint256(int256(sample))));
    }

    function test_toInt256() external view {
        int256 sample = type(int256).max;
        assertEq(harness.toInt256(bytes32(uint256(int256(sample)))), sample);
    }

    function test_fromInt256_roundTrip() external view {
        int256 sample = type(int256).max;
        assertEq(harness.toInt256(harness.fromInt256(sample)), sample);
    }

    /**********************************************************************************************/
    /*** Uint Tests                                                                             ***/
    /**********************************************************************************************/

    function test_fromUint8() external view {
        uint8 sample = type(uint8).max;
        assertEq(harness.fromUint8(sample), bytes32(uint256(sample)));
    }

    function test_toUint8_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint8(bytes32(uint256(type(uint8).max) + 1));
    }

    function test_toUint8() external view {
        uint8 sample = type(uint8).max;
        assertEq(harness.toUint8(bytes32(uint256(sample))), sample);
    }

    function test_fromUint8_roundTrip() external view {
        uint8 sample = type(uint8).max;
        assertEq(harness.toUint8(harness.fromUint8(sample)), sample);
    }

    function test_fromUint16() external view {
        uint16 sample = type(uint16).max;
        assertEq(harness.fromUint16(sample), bytes32(uint256(sample)));
    }

    function test_toUint16_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint16(bytes32(uint256(type(uint16).max) + 1));
    }

    function test_toUint16() external view {
        uint16 sample = type(uint16).max;
        assertEq(harness.toUint16(bytes32(uint256(sample))), sample);
    }

    function test_fromUint16_roundTrip() external view {
        uint16 sample = type(uint16).max;
        assertEq(harness.toUint16(harness.fromUint16(sample)), sample);
    }

    function test_fromUint24() external view {
        uint24 sample = type(uint24).max;
        assertEq(harness.fromUint24(sample), bytes32(uint256(sample)));
    }

    function test_toUint24_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint24(bytes32(uint256(type(uint24).max) + 1));
    }

    function test_toUint24() external view {
        uint24 sample = type(uint24).max;
        assertEq(harness.toUint24(bytes32(uint256(sample))), sample);
    }

    function test_fromUint24_roundTrip() external view {
        uint24 sample = type(uint24).max;
        assertEq(harness.toUint24(harness.fromUint24(sample)), sample);
    }

    function test_fromUint32() external view {
        uint32 sample = type(uint32).max;
        assertEq(harness.fromUint32(sample), bytes32(uint256(sample)));
    }

    function test_toUint32_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint32(bytes32(uint256(type(uint32).max) + 1));
    }

    function test_toUint32() external view {
        uint32 sample = type(uint32).max;
        assertEq(harness.toUint32(bytes32(uint256(sample))), sample);
    }

    function test_fromUint32_roundTrip() external view {
        uint32 sample = type(uint32).max;
        assertEq(harness.toUint32(harness.fromUint32(sample)), sample);
    }

    function test_fromUint40() external view {
        uint40 sample = type(uint40).max;
        assertEq(harness.fromUint40(sample), bytes32(uint256(sample)));
    }

    function test_toUint40_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint40(bytes32(uint256(type(uint40).max) + 1));
    }

    function test_toUint40() external view {
        uint40 sample = type(uint40).max;
        assertEq(harness.toUint40(bytes32(uint256(sample))), sample);
    }

    function test_fromUint40_roundTrip() external view {
        uint40 sample = type(uint40).max;
        assertEq(harness.toUint40(harness.fromUint40(sample)), sample);
    }

    function test_fromUint48() external view {
        uint48 sample = type(uint48).max;
        assertEq(harness.fromUint48(sample), bytes32(uint256(sample)));
    }

    function test_toUint48_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint48(bytes32(uint256(type(uint48).max) + 1));
    }

    function test_toUint48() external view {
        uint48 sample = type(uint48).max;
        assertEq(harness.toUint48(bytes32(uint256(sample))), sample);
    }

    function test_fromUint48_roundTrip() external view {
        uint48 sample = type(uint48).max;
        assertEq(harness.toUint48(harness.fromUint48(sample)), sample);
    }

    function test_fromUint56() external view {
        uint56 sample = type(uint56).max;
        assertEq(harness.fromUint56(sample), bytes32(uint256(sample)));
    }

    function test_toUint56_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint56(bytes32(uint256(type(uint56).max) + 1));
    }

    function test_toUint56() external view {
        uint56 sample = type(uint56).max;
        assertEq(harness.toUint56(bytes32(uint256(sample))), sample);
    }

    function test_fromUint56_roundTrip() external view {
        uint56 sample = type(uint56).max;
        assertEq(harness.toUint56(harness.fromUint56(sample)), sample);
    }

    function test_fromUint64() external view {
        uint64 sample = type(uint64).max;
        assertEq(harness.fromUint64(sample), bytes32(uint256(sample)));
    }

    function test_toUint64_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint64(bytes32(uint256(type(uint64).max) + 1));
    }

    function test_toUint64() external view {
        uint64 sample = type(uint64).max;
        assertEq(harness.toUint64(bytes32(uint256(sample))), sample);
    }

    function test_fromUint64_roundTrip() external view {
        uint64 sample = type(uint64).max;
        assertEq(harness.toUint64(harness.fromUint64(sample)), sample);
    }

    function test_fromUint72() external view {
        uint72 sample = type(uint72).max;
        assertEq(harness.fromUint72(sample), bytes32(uint256(sample)));
    }

    function test_toUint72_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint72(bytes32(uint256(type(uint72).max) + 1));
    }

    function test_toUint72() external view {
        uint72 sample = type(uint72).max;
        assertEq(harness.toUint72(bytes32(uint256(sample))), sample);
    }

    function test_fromUint72_roundTrip() external view {
        uint72 sample = type(uint72).max;
        assertEq(harness.toUint72(harness.fromUint72(sample)), sample);
    }

    function test_fromUint80() external view {
        uint80 sample = type(uint80).max;
        assertEq(harness.fromUint80(sample), bytes32(uint256(sample)));
    }

    function test_toUint80_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint80(bytes32(uint256(type(uint80).max) + 1));
    }

    function test_toUint80() external view {
        uint80 sample = type(uint80).max;
        assertEq(harness.toUint80(bytes32(uint256(sample))), sample);
    }

    function test_fromUint80_roundTrip() external view {
        uint80 sample = type(uint80).max;
        assertEq(harness.toUint80(harness.fromUint80(sample)), sample);
    }

    function test_fromUint88() external view {
        uint88 sample = type(uint88).max;
        assertEq(harness.fromUint88(sample), bytes32(uint256(sample)));
    }

    function test_toUint88_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint88(bytes32(uint256(type(uint88).max) + 1));
    }

    function test_toUint88() external view {
        uint88 sample = type(uint88).max;
        assertEq(harness.toUint88(bytes32(uint256(sample))), sample);
    }

    function test_fromUint88_roundTrip() external view {
        uint88 sample = type(uint88).max;
        assertEq(harness.toUint88(harness.fromUint88(sample)), sample);
    }

    function test_fromUint96() external view {
        uint96 sample = type(uint96).max;
        assertEq(harness.fromUint96(sample), bytes32(uint256(sample)));
    }

    function test_toUint96_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint96(bytes32(uint256(type(uint96).max) + 1));
    }

    function test_toUint96() external view {
        uint96 sample = type(uint96).max;
        assertEq(harness.toUint96(bytes32(uint256(sample))), sample);
    }

    function test_fromUint96_roundTrip() external view {
        uint96 sample = type(uint96).max;
        assertEq(harness.toUint96(harness.fromUint96(sample)), sample);
    }

    function test_fromUint104() external view {
        uint104 sample = type(uint104).max;
        assertEq(harness.fromUint104(sample), bytes32(uint256(sample)));
    }

    function test_toUint104_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint104(bytes32(uint256(type(uint104).max) + 1));
    }

    function test_toUint104() external view {
        uint104 sample = type(uint104).max;
        assertEq(harness.toUint104(bytes32(uint256(sample))), sample);
    }

    function test_fromUint104_roundTrip() external view {
        uint104 sample = type(uint104).max;
        assertEq(harness.toUint104(harness.fromUint104(sample)), sample);
    }

    function test_fromUint112() external view {
        uint112 sample = type(uint112).max;
        assertEq(harness.fromUint112(sample), bytes32(uint256(sample)));
    }

    function test_toUint112_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint112(bytes32(uint256(type(uint112).max) + 1));
    }

    function test_toUint112() external view {
        uint112 sample = type(uint112).max;
        assertEq(harness.toUint112(bytes32(uint256(sample))), sample);
    }

    function test_fromUint112_roundTrip() external view {
        uint112 sample = type(uint112).max;
        assertEq(harness.toUint112(harness.fromUint112(sample)), sample);
    }

    function test_fromUint120() external view {
        uint120 sample = type(uint120).max;
        assertEq(harness.fromUint120(sample), bytes32(uint256(sample)));
    }

    function test_toUint120_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint120(bytes32(uint256(type(uint120).max) + 1));
    }

    function test_toUint120() external view {
        uint120 sample = type(uint120).max;
        assertEq(harness.toUint120(bytes32(uint256(sample))), sample);
    }

    function test_fromUint120_roundTrip() external view {
        uint120 sample = type(uint120).max;
        assertEq(harness.toUint120(harness.fromUint120(sample)), sample);
    }

    function test_fromUint128() external view {
        uint128 sample = type(uint128).max;
        assertEq(harness.fromUint128(sample), bytes32(uint256(sample)));
    }

    function test_toUint128_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint128(bytes32(uint256(type(uint128).max) + 1));
    }

    function test_toUint128() external view {
        uint128 sample = type(uint128).max;
        assertEq(harness.toUint128(bytes32(uint256(sample))), sample);
    }

    function test_fromUint128_roundTrip() external view {
        uint128 sample = type(uint128).max;
        assertEq(harness.toUint128(harness.fromUint128(sample)), sample);
    }

    function test_fromUint136() external view {
        uint136 sample = type(uint136).max;
        assertEq(harness.fromUint136(sample), bytes32(uint256(sample)));
    }

    function test_toUint136_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint136(bytes32(uint256(type(uint136).max) + 1));
    }

    function test_toUint136() external view {
        uint136 sample = type(uint136).max;
        assertEq(harness.toUint136(bytes32(uint256(sample))), sample);
    }

    function test_fromUint136_roundTrip() external view {
        uint136 sample = type(uint136).max;
        assertEq(harness.toUint136(harness.fromUint136(sample)), sample);
    }

    function test_fromUint144() external view {
        uint144 sample = type(uint144).max;
        assertEq(harness.fromUint144(sample), bytes32(uint256(sample)));
    }

    function test_toUint144_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint144(bytes32(uint256(type(uint144).max) + 1));
    }

    function test_toUint144() external view {
        uint144 sample = type(uint144).max;
        assertEq(harness.toUint144(bytes32(uint256(sample))), sample);
    }

    function test_fromUint144_roundTrip() external view {
        uint144 sample = type(uint144).max;
        assertEq(harness.toUint144(harness.fromUint144(sample)), sample);
    }

    function test_fromUint152() external view {
        uint152 sample = type(uint152).max;
        assertEq(harness.fromUint152(sample), bytes32(uint256(sample)));
    }

    function test_toUint152_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint152(bytes32(uint256(type(uint152).max) + 1));
    }

    function test_toUint152() external view {
        uint152 sample = type(uint152).max;
        assertEq(harness.toUint152(bytes32(uint256(sample))), sample);
    }

    function test_fromUint152_roundTrip() external view {
        uint152 sample = type(uint152).max;
        assertEq(harness.toUint152(harness.fromUint152(sample)), sample);
    }

    function test_fromUint160() external view {
        uint160 sample = type(uint160).max;
        assertEq(harness.fromUint160(sample), bytes32(uint256(sample)));
    }

    function test_toUint160_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint160(bytes32(uint256(type(uint160).max) + 1));
    }

    function test_toUint160() external view {
        uint160 sample = type(uint160).max;
        assertEq(harness.toUint160(bytes32(uint256(sample))), sample);
    }

    function test_fromUint160_roundTrip() external view {
        uint160 sample = type(uint160).max;
        assertEq(harness.toUint160(harness.fromUint160(sample)), sample);
    }

    function test_fromUint168() external view {
        uint168 sample = type(uint168).max;
        assertEq(harness.fromUint168(sample), bytes32(uint256(sample)));
    }

    function test_toUint168_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint168(bytes32(uint256(type(uint168).max) + 1));
    }

    function test_toUint168() external view {
        uint168 sample = type(uint168).max;
        assertEq(harness.toUint168(bytes32(uint256(sample))), sample);
    }

    function test_fromUint168_roundTrip() external view {
        uint168 sample = type(uint168).max;
        assertEq(harness.toUint168(harness.fromUint168(sample)), sample);
    }

    function test_fromUint176() external view {
        uint176 sample = type(uint176).max;
        assertEq(harness.fromUint176(sample), bytes32(uint256(sample)));
    }

    function test_toUint176_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint176(bytes32(uint256(type(uint176).max) + 1));
    }

    function test_toUint176() external view {
        uint176 sample = type(uint176).max;
        assertEq(harness.toUint176(bytes32(uint256(sample))), sample);
    }

    function test_fromUint176_roundTrip() external view {
        uint176 sample = type(uint176).max;
        assertEq(harness.toUint176(harness.fromUint176(sample)), sample);
    }

    function test_fromUint184() external view {
        uint184 sample = type(uint184).max;
        assertEq(harness.fromUint184(sample), bytes32(uint256(sample)));
    }

    function test_toUint184_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint184(bytes32(uint256(type(uint184).max) + 1));
    }

    function test_toUint184() external view {
        uint184 sample = type(uint184).max;
        assertEq(harness.toUint184(bytes32(uint256(sample))), sample);
    }

    function test_fromUint184_roundTrip() external view {
        uint184 sample = type(uint184).max;
        assertEq(harness.toUint184(harness.fromUint184(sample)), sample);
    }

    function test_fromUint192() external view {
        uint192 sample = type(uint192).max;
        assertEq(harness.fromUint192(sample), bytes32(uint256(sample)));
    }

    function test_toUint192_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint192(bytes32(uint256(type(uint192).max) + 1));
    }

    function test_toUint192() external view {
        uint192 sample = type(uint192).max;
        assertEq(harness.toUint192(bytes32(uint256(sample))), sample);
    }

    function test_fromUint192_roundTrip() external view {
        uint192 sample = type(uint192).max;
        assertEq(harness.toUint192(harness.fromUint192(sample)), sample);
    }

    function test_fromUint200() external view {
        uint200 sample = type(uint200).max;
        assertEq(harness.fromUint200(sample), bytes32(uint256(sample)));
    }

    function test_toUint200_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint200(bytes32(uint256(type(uint200).max) + 1));
    }

    function test_toUint200() external view {
        uint200 sample = type(uint200).max;
        assertEq(harness.toUint200(bytes32(uint256(sample))), sample);
    }

    function test_fromUint200_roundTrip() external view {
        uint200 sample = type(uint200).max;
        assertEq(harness.toUint200(harness.fromUint200(sample)), sample);
    }

    function test_fromUint208() external view {
        uint208 sample = type(uint208).max;
        assertEq(harness.fromUint208(sample), bytes32(uint256(sample)));
    }

    function test_toUint208_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint208(bytes32(uint256(type(uint208).max) + 1));
    }

    function test_toUint208() external view {
        uint208 sample = type(uint208).max;
        assertEq(harness.toUint208(bytes32(uint256(sample))), sample);
    }

    function test_fromUint208_roundTrip() external view {
        uint208 sample = type(uint208).max;
        assertEq(harness.toUint208(harness.fromUint208(sample)), sample);
    }

    function test_fromUint216() external view {
        uint216 sample = type(uint216).max;
        assertEq(harness.fromUint216(sample), bytes32(uint256(sample)));
    }

    function test_toUint216_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint216(bytes32(uint256(type(uint216).max) + 1));
    }

    function test_toUint216() external view {
        uint216 sample = type(uint216).max;
        assertEq(harness.toUint216(bytes32(uint256(sample))), sample);
    }

    function test_fromUint216_roundTrip() external view {
        uint216 sample = type(uint216).max;
        assertEq(harness.toUint216(harness.fromUint216(sample)), sample);
    }

    function test_fromUint224() external view {
        uint224 sample = type(uint224).max;
        assertEq(harness.fromUint224(sample), bytes32(uint256(sample)));
    }

    function test_toUint224_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint224(bytes32(uint256(type(uint224).max) + 1));
    }

    function test_toUint224() external view {
        uint224 sample = type(uint224).max;
        assertEq(harness.toUint224(bytes32(uint256(sample))), sample);
    }

    function test_fromUint224_roundTrip() external view {
        uint224 sample = type(uint224).max;
        assertEq(harness.toUint224(harness.fromUint224(sample)), sample);
    }

    function test_fromUint232() external view {
        uint232 sample = type(uint232).max;
        assertEq(harness.fromUint232(sample), bytes32(uint256(sample)));
    }

    function test_toUint232_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint232(bytes32(uint256(type(uint232).max) + 1));
    }

    function test_toUint232() external view {
        uint232 sample = type(uint232).max;
        assertEq(harness.toUint232(bytes32(uint256(sample))), sample);
    }

    function test_fromUint232_roundTrip() external view {
        uint232 sample = type(uint232).max;
        assertEq(harness.toUint232(harness.fromUint232(sample)), sample);
    }

    function test_fromUint240() external view {
        uint240 sample = type(uint240).max;
        assertEq(harness.fromUint240(sample), bytes32(uint256(sample)));
    }

    function test_toUint240_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint240(bytes32(uint256(type(uint240).max) + 1));
    }

    function test_toUint240() external view {
        uint240 sample = type(uint240).max;
        assertEq(harness.toUint240(bytes32(uint256(sample))), sample);
    }

    function test_fromUint240_roundTrip() external view {
        uint240 sample = type(uint240).max;
        assertEq(harness.toUint240(harness.fromUint240(sample)), sample);
    }

    function test_fromUint248() external view {
        uint248 sample = type(uint248).max;
        assertEq(harness.fromUint248(sample), bytes32(uint256(sample)));
    }

    function test_toUint248_outOfBounds() external {
        vm.expectRevert(IParameterHelpersErrors.ParameterOutOfTypeBounds.selector);
        harness.toUint248(bytes32(uint256(type(uint248).max) + 1));
    }

    function test_toUint248() external view {
        uint248 sample = type(uint248).max;
        assertEq(harness.toUint248(bytes32(uint256(sample))), sample);
    }

    function test_fromUint248_roundTrip() external view {
        uint248 sample = type(uint248).max;
        assertEq(harness.toUint248(harness.fromUint248(sample)), sample);
    }

    function test_fromUint256() external view {
        uint256 sample = type(uint256).max;
        assertEq(harness.fromUint256(sample), bytes32(uint256(sample)));
    }

    function test_toUint256() external view {
        uint256 sample = type(uint256).max;
        assertEq(harness.toUint256(bytes32(uint256(sample))), sample);
    }

    function test_fromUint256_roundTrip() external view {
        uint256 sample = type(uint256).max;
        assertEq(harness.toUint256(harness.fromUint256(sample)), sample);
    }

}
