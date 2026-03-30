// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IAccessControl }           from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IAccessControlEnumerable } from "../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";
import { IERC165 }                  from "../../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { ERC1967Proxy } from "../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { IWEETHModule } from "../../src/facets/weeth/IWEETHModule.sol";
import { WEETHModule }  from "../../src/facets/weeth/WEETHModule.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";

interface IEETHLike {

    function liquidityPool() external view returns (address);

}

interface IERC20Like {

    function transfer(address to, uint256 amount) external returns (bool);

}

interface ILiquidityPoolLike {

    function withdrawRequestNFT() external view returns (address);

}

interface IWEETHLike {

    function eETH() external view returns (address);

}

interface IWETHLike {

    function deposit() external payable;

}

interface IWithdrawRequestNFTLike {

    function claimWithdraw(uint256 requestId) external;

    function isFinalized(uint256 requestId) external view returns (bool);

    function isValid(uint256 requestId) external view returns (bool);

}

contract WEETHModule_Tests is UnitTestBase {

    address internal almProxy           = makeAddr("almProxy");
    address internal eeth               = makeAddr("eeth");
    address internal liquidityPool      = makeAddr("liquidityPool");
    address internal unauthorized       = makeAddr("unauthorized");
    address internal withdrawRequestNFT = makeAddr("withdrawRequestNFT");

    WEETHModule internal implementation;
    WEETHModule internal proxy;

    function setUp() external {
        implementation = new WEETHModule();

        proxy = WEETHModule(
                payable(
                    new ERC1967Proxy(
                        address(implementation),
                        abi.encodeCall(WEETHModule.initialize, (admin, almProxy))
                    )
                )
        );
    }

    /**********************************************************************************************/
    /*** initialize Tests                                                                       ***/
    /**********************************************************************************************/

    function test_initialize_invalidAdmin() external {
        vm.expectRevert("WEETHModule/invalid-admin");
        new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(WEETHModule.initialize, (address(0), almProxy))
        );
    }

    function test_initialize_invalidAlmProxy() external {
        vm.expectRevert("WEETHModule/invalid-alm-proxy");
        new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(WEETHModule.initialize, (admin, address(0)))
        );
    }

    function test_initialize_cannotInitializeAgain() external {
        vm.expectRevert("InvalidInitialization()");
        proxy.initialize(admin, almProxy);
    }

    function test_initialize_cannotInitializeImplementation() external {
        vm.expectRevert("InvalidInitialization()");
        implementation.initialize(admin, almProxy);
    }

    function test_initializedState() external {
        assertEq(proxy.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(proxy.almProxy(),                         almProxy);
    }

    /**********************************************************************************************/
    /*** claimWithdrawal Tests                                                                  ***/
    /**********************************************************************************************/

    function test_claimWithdrawal_invalidSender() external {
        vm.expectRevert("WEETHModule/invalid-sender");
        vm.prank(unauthorized);
        proxy.claimWithdrawal(0);
    }

    function test_claimWithdrawal_invalidRequestId() external {
        vm.mockCall(
            Ethereum.WEETH,
            abi.encodeWithSelector(IWEETHLike.eETH.selector),
            abi.encode(eeth)
        );

        vm.mockCall(
            eeth,
            abi.encodeWithSelector(IEETHLike.liquidityPool.selector),
            abi.encode(liquidityPool)
        );

        vm.mockCall(
            liquidityPool,
            abi.encodeWithSelector(ILiquidityPoolLike.withdrawRequestNFT.selector),
            abi.encode(withdrawRequestNFT)
        );

        vm.mockCall(
            withdrawRequestNFT,
            abi.encodeWithSelector(IWithdrawRequestNFTLike.isValid.selector, 1),
            abi.encode(false)
        );

        vm.expectRevert("WEETHModule/invalid-request-id");
        vm.prank(almProxy);
        proxy.claimWithdrawal(1);
    }

    function test_claimWithdrawal_requestNotFinalized() external {
        vm.mockCall(
            Ethereum.WEETH,
            abi.encodeWithSelector(IWEETHLike.eETH.selector),
            abi.encode(eeth)
        );

        vm.mockCall(
            eeth,
            abi.encodeWithSelector(IEETHLike.liquidityPool.selector),
            abi.encode(liquidityPool)
        );

        vm.mockCall(
            liquidityPool,
            abi.encodeWithSelector(ILiquidityPoolLike.withdrawRequestNFT.selector),
            abi.encode(withdrawRequestNFT)
        );

        vm.mockCall(
            withdrawRequestNFT,
            abi.encodeWithSelector(IWithdrawRequestNFTLike.isValid.selector, 1),
            abi.encode(true)
        );

        vm.mockCall(
            withdrawRequestNFT,
            abi.encodeWithSelector(IWithdrawRequestNFTLike.isFinalized.selector, 1),
            abi.encode(false)
        );

        vm.expectRevert("WEETHModule/request-not-finalized");
        vm.prank(almProxy);
        proxy.claimWithdrawal(1);
    }

    function test_claimWithdrawal() external {
        deal(address(proxy), 1 ether);

        _expectAndMockCall(
            Ethereum.WEETH,
            abi.encodeWithSelector(IWEETHLike.eETH.selector),
            abi.encode(eeth)
        );

        _expectAndMockCall(
            eeth,
            abi.encodeWithSelector(IEETHLike.liquidityPool.selector),
            abi.encode(liquidityPool)
        );

        _expectAndMockCall(
            liquidityPool,
            abi.encodeWithSelector(ILiquidityPoolLike.withdrawRequestNFT.selector),
            abi.encode(withdrawRequestNFT)
        );

        _expectAndMockCall(
            withdrawRequestNFT,
            abi.encodeWithSelector(IWithdrawRequestNFTLike.isValid.selector, 1),
            abi.encode(true)
        );

        _expectAndMockCall(
            withdrawRequestNFT,
            abi.encodeWithSelector(IWithdrawRequestNFTLike.isFinalized.selector, 1),
            abi.encode(true)
        );

        _expectAndMockCall(
            withdrawRequestNFT,
            abi.encodeWithSelector(IWithdrawRequestNFTLike.claimWithdraw.selector, 1),
            ""
        );

        _expectAndMockCall(
            Ethereum.WETH,
            1 ether,
            abi.encodeWithSelector(IWETHLike.deposit.selector),
            ""
        );

        _expectAndMockCall(
            Ethereum.WETH,
            abi.encodeWithSelector(IERC20Like.transfer.selector, almProxy, 1 ether),
            abi.encode(true)
        );

        vm.prank(almProxy);
        assertEq(proxy.claimWithdrawal(1), 1 ether);
    }

    /**********************************************************************************************/
    /*** supportsInterface Tests                                                                ***/
    /**********************************************************************************************/

    function test_supportsInterface() external view {
        assertEq(proxy.supportsInterface(type(IWEETHModule).interfaceId),             true);
        assertEq(proxy.supportsInterface(type(IAccessControlEnumerable).interfaceId), true);
        assertEq(proxy.supportsInterface(type(IAccessControl).interfaceId),           true);
        assertEq(proxy.supportsInterface(type(IERC165).interfaceId),                  true);
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _expectAndMockCall(address callee, bytes memory data, bytes memory returnData)
        internal
    {
        vm.expectCall(callee, data);
        vm.mockCall(callee, data, returnData);
    }

    function _expectAndMockCall(
        address callee,
        uint256 msgValue,
        bytes memory data,
        bytes memory returnData
    )
        internal
    {
        vm.expectCall(callee, msgValue, data);
        vm.mockCall(callee, msgValue, data, returnData);
    }

}
