// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib } from "../../libraries/ApproveLib.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { FacetBase } from "../FacetBase.sol";

import { IUSDEFacet } from "./IUSDEFacet.sol";

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

}

interface IMinterLike {

    function setDelegatedSigner(address delegateSigner) external;

    function removeDelegatedSigner(address delegateSigner) external;

}

interface ISUSDELike {

    function cooldownAssets(uint256 usdeAmount) external returns (uint256);

    function cooldownShares(uint256 susdeAmount) external returns (uint256);

    function unstake(address receiver) external;

}

contract USDEFacet is IUSDEFacet, FacetBase {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.USDEFacet.v1
    struct FacetStorage {
        address minter;
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.USDEFacet.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant FACET_STORAGE_LOCATION =
        0x55c91bfe71e19bbbf4b478c668445eb4a02c5233a3ae262d70774d0a79b96600;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant override LIMIT_USDE_BURN      = keccak256("LIMIT_USDE_BURN");
    bytes32 public constant override LIMIT_USDE_MINT      = keccak256("LIMIT_USDE_MINT");
    bytes32 public constant override LIMIT_SUSDE_COOLDOWN = keccak256("LIMIT_SUSDE_COOLDOWN");

    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    address public immutable override susde;
    address public immutable override usdc;
    address public immutable override usde;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address susde_, address usdc_, address usde_) {
        require(susde_ != address(0), "USDEFacet/zero-susde");
        require(usdc_  != address(0), "USDEFacet/zero-usdc");
        require(usde_  != address(0), "USDEFacet/zero-usde");

        susde = susde_;
        usdc  = usdc_;
        usde  = usde_;
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function setMinter(address minter_)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(minter_ != address(0), "USDEFacet/zero-minter");

        emit USDEMinterSet(_getFacetStorage().minter = minter_);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    function setDelegatedSigner(address delegatedSigner)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        IALMProxy(_getSharedControllerStorage().proxy).doCall(
            _getFacetStorage().minter,
            abi.encodeCall(IMinterLike.setDelegatedSigner, (delegatedSigner))
        );

        emit USDESetDelegatedSigner(delegatedSigner);
    }

    function removeDelegatedSigner(address delegatedSigner)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        IALMProxy(_getSharedControllerStorage().proxy).doCall(
            _getFacetStorage().minter,
            abi.encodeCall(IMinterLike.removeDelegatedSigner, (delegatedSigner))
        );

        emit USDERemoveDelegatedSigner(delegatedSigner);
    }

    function prepareMint(uint256 usdcAmount) external override nonReentrant onlyRole(RELAYER_ROLE) {
        _decreaseRateLimit(LIMIT_USDE_MINT, usdcAmount);

        ApproveLib.approve(
            usdc,
            _getSharedControllerStorage().proxy,
            _getFacetStorage().minter,
            usdcAmount
        );

        emit USDEPrepareMint(usdcAmount);
    }

    function prepareBurn(uint256 usdeAmount) external override nonReentrant onlyRole(RELAYER_ROLE) {
        _decreaseRateLimit(LIMIT_USDE_BURN, usdeAmount);

        ApproveLib.approve(
            usde,
            _getSharedControllerStorage().proxy,
            _getFacetStorage().minter,
            usdeAmount
        );

        emit USDEPrepareBurn(usdeAmount);
    }

    function cooldownAssets(uint256 usdeAmount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 shares)
    {
        _decreaseRateLimit(LIMIT_SUSDE_COOLDOWN, usdeAmount);

        shares = abi.decode(
            IALMProxy(_getSharedControllerStorage().proxy).doCall(
                susde,
                abi.encodeCall(ISUSDELike.cooldownAssets, (usdeAmount))
            ),
            (uint256)
        );

        emit USDECooldownAssets(usdeAmount, shares);
    }

    function cooldownShares(uint256 susdeAmount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 assets)
    {
        // NOTE: Rate limited at end of function, so cannot return here.
        assets = abi.decode(
            IALMProxy(_getSharedControllerStorage().proxy).doCall(
                susde,
                abi.encodeCall(ISUSDELike.cooldownShares, (susdeAmount))
            ),
            (uint256)
        );

        _decreaseRateLimit(LIMIT_SUSDE_COOLDOWN, assets);

        emit USDECooldownShares(susdeAmount, assets);
    }

    function unstakeSUSDE() external override nonReentrant onlyRole(RELAYER_ROLE) {
        address proxy = _getSharedControllerStorage().proxy;

        uint256 usdeBefore = IERC20Like(usde).balanceOf(proxy);

        IALMProxy(proxy).doCall(susde, abi.encodeCall(ISUSDELike.unstake, (proxy)));

        emit USDEUnstakeSUSDE(IERC20Like(usde).balanceOf(proxy) - usdeBefore);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IUSDEFacet
    function minter() external view override returns (address) {
        return _getFacetStorage().minter;
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _decreaseRateLimit(bytes32 key, uint256 amount) internal {
        IRateLimits(_getSharedControllerStorage().rateLimits).triggerRateLimitDecrease(key, amount);
    }

}
