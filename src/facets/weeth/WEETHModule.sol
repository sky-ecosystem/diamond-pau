// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    AccessControlEnumerableUpgradeable
} from "../../../lib/oz-upgradeable/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";

import {
    UUPSUpgradeable
} from "../../../lib/oz-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { IWEETHModule } from "./IWEETHModule.sol";

interface IERC20Like {

    function transfer(address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

}

interface IEETHLike {

    function liquidityPool() external view returns (address);

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

    struct WithdrawRequest {
        uint96 amountOfEEth;
        uint96 shareOfEEth;
        bool   isValid;
        uint32 feeGwei;
    }

    function claimWithdraw(uint256 requestId) external;

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);

    function isFinalized(uint256 requestId) external view returns (bool);

    function ownerOf(uint256 requestId) external view returns (address);

}

// NOTE: This contract is specifically for Mainnet Ethereum.
contract WEETHModule is IWEETHModule, AccessControlEnumerableUpgradeable, UUPSUpgradeable {

    /**********************************************************************************************/
    /*** UUPS Storage                                                                           ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.WEETHModule.v1
    struct WEETHModuleStorage {
        address proxy;
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.WEETHModule.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _WEETH_MODULE_STORAGE_LOCATION =
        0x072d818e7fec5969c5ff28092831f41de97405b50d97fe9622741f7cad03bb00;

    function _getWEETHModuleStorage() internal pure returns (WEETHModuleStorage storage $) {
        assembly {
            $.slot := _WEETH_MODULE_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    address public immutable override weeth;
    address public immutable override weth;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address weeth_, address weth_) {
        require(weeth_ != address(0), "WEETHModule/zero-weeth");
        require(weth_  != address(0), "WEETHModule/zero-weth");

        weeth = weeth_;
        weth  = weth_;

        _disableInitializers();  // Avoid initializing in the context of the implementation
    }

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    /// @inheritdoc IWEETHModule
    function initialize(address admin_, address proxy_) external override initializer {
        require(proxy_ != address(0), "WEETHModule/invalid-proxy");
        require(admin_ != address(0), "WEETHModule/invalid-admin");

        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        _getWEETHModuleStorage().proxy = proxy_;
    }

    /**********************************************************************************************/
    /*** External Interactive ALMProxy Functions                                                ***/
    /**********************************************************************************************/

    /// @inheritdoc IWEETHModule
    function claimWithdrawal(uint256 requestId) external override returns (uint256 ethReceived) {
        require(msg.sender == _getWEETHModuleStorage().proxy, "WEETHModule/invalid-sender");

        address eeth          = IWEETHLike(weeth).eETH();
        address liquidityPool = IEETHLike(eeth).liquidityPool();

        IWithdrawRequestNFTLike withdrawRequestNFT =
            IWithdrawRequestNFTLike(ILiquidityPoolLike(liquidityPool).withdrawRequestNFT());

        IWithdrawRequestNFTLike.WithdrawRequest memory request =
            withdrawRequestNFT.getRequest(requestId);

        // NOTE: Any account can settle a finalized request, which pays the ETH to the NFT owner
        //       (this module) and deletes the request. A request with no shares was already
        //       settled (or never existed), so there is nothing to claim and the ETH already held
        //       by this module is swept instead.
        if (request.shareOfEEth == 0) return _sweepWETH(msg.sender);

        // NOTE: `ownerOf` also reverts if the request does not exist.
        require(
            withdrawRequestNFT.ownerOf(requestId) == address(this),
            "WEETHModule/not-request-owner"
        );

        require(request.isValid,                           "WEETHModule/invalid-request-id");
        require(withdrawRequestNFT.isFinalized(requestId), "WEETHModule/request-not-finalized");

        withdrawRequestNFT.claimWithdraw(requestId);

        return _sweepWETH(msg.sender);
    }

    /**********************************************************************************************/
    /*** External Variable Getters                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc IWEETHModule
    function proxy() external view override returns (address) {
        return _getWEETHModuleStorage().proxy;
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IWEETHModule
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    /// @inheritdoc IWEETHModule
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IWEETHModule, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IWEETHModule).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**********************************************************************************************/
    /*** Receive function                                                                       ***/
    /**********************************************************************************************/

    receive() external payable {}

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    // Only DEFAULT_ADMIN_ROLE can upgrade the implementation
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // Wraps all ETH held by this module into WETH and transfers all WETH to `receiver`.
    function _sweepWETH(address receiver) internal returns (uint256 wethSwept) {
        IWETHLike(weth).deposit{value: address(this).balance}();

        wethSwept = IERC20Like(weth).balanceOf(address(this));

        require(wethSwept != 0, "WEETHModule/nothing-to-claim");

        // No need for SafeERC20 as we are transferring WETH with an expected transfer function.
        IERC20Like(weth).transfer(receiver, wethSwept);
    }

}
