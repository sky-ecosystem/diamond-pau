// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    AccessControlEnumerable
} from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

import { IALMProxy }   from "./interfaces/IALMProxy.sol";
import { IRateLimits } from "./interfaces/IRateLimits.sol";

import { LayerZeroLib }  from "./libraries/LayerZeroLib.sol";
import { OTCLib }        from "./libraries/OTCLib.sol";

import { Controller } from "./Controller.sol";

contract MainnetController is Controller, AccessControlEnumerable {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event MaxSlippageSet(address indexed pool, uint256 maxSlippage);

    event RelayerRemoved(address indexed relayer);

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public FREEZER = keccak256("FREEZER");
    bytes32 public RELAYER = keccak256("RELAYER");

    bytes32 public LIMIT_LAYERZERO_TRANSFER = LayerZeroLib.LIMIT_TRANSFER;
    bytes32 public LIMIT_OTC_SWAP           = OTCLib.LIMIT_SWAP;

    IALMProxy   public proxy;
    IRateLimits public rateLimits;

    mapping(address pool => uint256 maxSlippage) public maxSlippages;  // 1e18 precision

    mapping(uint32 destinationEndpointId => bytes32 layerZeroRecipient)  public layerZeroRecipients;

    // OTC swap (also uses maxSlippages)
    mapping(address exchange => OTCLib.OTC otcData) public otcs;

    mapping(address exchange => mapping(address asset => bool)) public otcWhitelistedAssets;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(address admin_, address proxy_, address rateLimits_, address accessControls_)
        Controller(accessControls_, proxy_, rateLimits_)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        proxy      = IALMProxy(proxy_);
        rateLimits = IRateLimits(rateLimits_);
    }

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setLayerZeroRecipient(uint32 destinationEndpointId, bytes32 recipient)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        LayerZeroLib.setRecipient(layerZeroRecipients, destinationEndpointId, recipient);
    }

    function setMaxSlippage(address pool, uint256 maxSlippage)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(pool != address(0), "MC/pool-zero-address");

        maxSlippages[pool] = maxSlippage;
        emit MaxSlippageSet(pool, maxSlippage);
    }

    function setOTCBuffer(address exchange, address otcBuffer)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        OTCLib.setBuffer(exchange, otcBuffer, otcs, maxSlippages);
    }

    function setOTCRechargeRate(address exchange, uint256 rechargeRate18)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        OTCLib.setRechargeRate(exchange, rechargeRate18, otcs);
    }

    function setOTCWhitelistedAsset(address exchange, address asset, bool isWhitelisted)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        OTCLib.setWhitelistedAsset(exchange, asset, isWhitelisted, otcWhitelistedAssets, otcs);
    }

    /**********************************************************************************************/
    /*** Freezer functions                                                                      ***/
    /**********************************************************************************************/

    function removeRelayer(address relayer) external nonReentrant onlyRole(FREEZER) {
        _revokeRole(RELAYER, relayer);
        emit RelayerRemoved(relayer);
    }

    /**********************************************************************************************/
    /*** Relayer LayerZero functions                                                            ***/
    /**********************************************************************************************/

    // NOTE: !!! This function was deployed without integration testing !!!
    //       KEEP RATE LIMIT AT ZERO until LayerZero dependencies are live and
    //       all functionality has been thoroughly integration tested.
    function transferTokenLayerZero(
        address oftAddress,
        uint256 amount,
        uint32  destinationEndpointId
    )
        external
        payable
        nonReentrant
        onlyRole(RELAYER)
    {
        LayerZeroLib.transfer({
            proxy                 : address(proxy),
            rateLimits            : address(rateLimits),
            oftAddress            : oftAddress,
            amount                : amount,
            destinationEndpointId : destinationEndpointId,
            layerZeroRecipients   : layerZeroRecipients
        });
    }

    /**********************************************************************************************/
    /*** OTC swap functions                                                                     ***/
    /**********************************************************************************************/

    function otcSend(address exchange, address assetToSend, uint256 amount)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        OTCLib.send({
            proxy             : address(proxy),
            rateLimits        : address(rateLimits),
            exchange          : exchange,
            assetToSend       : assetToSend,
            amount            : amount,
            whitelistedAssets : otcWhitelistedAssets,
            otcs              : otcs,
            maxSlippages      : maxSlippages
        });
    }

    function otcClaim(address exchange, address assetToClaim)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        OTCLib.claim({
            proxy             : address(proxy),
            exchange          : exchange,
            assetToClaim      : assetToClaim,
            whitelistedAssets : otcWhitelistedAssets,
            otcs              : otcs
        });
    }

    function getOtcClaimWithRecharge(address exchange) external view returns (uint256) {
        return OTCLib.getClaimWithRecharge(exchange, otcs);
    }

    function isOtcSwapReady(address exchange) external view returns (bool) {
        return OTCLib.isSwapReady(exchange, otcs, maxSlippages);
    }

}
