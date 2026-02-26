// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { AccessControlEnumerable } from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";
import { ReentrancyGuard }         from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { AaveLib }          from "./libraries/AaveLib.sol";
import { CCTPLib }          from "./libraries/CCTPLib.sol";
import { CentrifugeLib }    from "./libraries/CentrifugeLib.sol";
import { ERC4626Lib }       from "./libraries/ERC4626Lib.sol";
import { ERC7540Lib }       from "./libraries/ERC7540Lib.sol";
import { LayerZeroLib }     from "./libraries/LayerZeroLib.sol";
import { PSM3Lib }          from "./libraries/PSM3Lib.sol";
import { SparkVaultLib }    from "./libraries/SparkVaultLib.sol";
import { TransferAssetLib } from "./libraries/TransferAssetLib.sol";

import { IALMProxy }   from "./interfaces/IALMProxy.sol";
import { IRateLimits } from "./interfaces/IRateLimits.sol";

contract ForeignController is ReentrancyGuard, AccessControlEnumerable {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event CentrifugeRecipientSet(uint16 indexed destinationCentrifugeId, bytes32 recipient);

    event MaxSlippageSet(address indexed pool, uint256 maxSlippage);

    event RelayerRemoved(address indexed relayer);

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    bytes32 public constant LIMIT_4626_DEPOSIT        = ERC4626Lib.LIMIT_DEPOSIT;
    bytes32 public constant LIMIT_4626_WITHDRAW       = ERC4626Lib.LIMIT_WITHDRAW;
    bytes32 public constant LIMIT_7540_DEPOSIT        = ERC7540Lib.LIMIT_7540_DEPOSIT;
    bytes32 public constant LIMIT_7540_REDEEM         = ERC7540Lib.LIMIT_7540_REDEEM;
    bytes32 public constant LIMIT_AAVE_DEPOSIT        = AaveLib.LIMIT_DEPOSIT;
    bytes32 public constant LIMIT_AAVE_WITHDRAW       = AaveLib.LIMIT_WITHDRAW;
    bytes32 public constant LIMIT_ASSET_TRANSFER      = TransferAssetLib.LIMIT_TRANSFER;
    bytes32 public constant LIMIT_CENTRIFUGE_TRANSFER = CentrifugeLib.LIMIT_CENTRIFUGE_TRANSFER;
    bytes32 public constant LIMIT_LAYERZERO_TRANSFER  = LayerZeroLib.LIMIT_TRANSFER;
    bytes32 public constant LIMIT_PSM_DEPOSIT         = PSM3Lib.LIMIT_DEPOSIT;
    bytes32 public constant LIMIT_PSM_WITHDRAW        = PSM3Lib.LIMIT_WITHDRAW;
    bytes32 public constant LIMIT_SPARK_VAULT_TAKE    = SparkVaultLib.LIMIT_TAKE;
    bytes32 public constant LIMIT_USDC_TO_CCTP        = CCTPLib.LIMIT_TO_CCTP;
    bytes32 public constant LIMIT_USDC_TO_DOMAIN      = CCTPLib.LIMIT_TO_DOMAIN;

    IALMProxy   public immutable proxy;
    address     public immutable cctp;
    address     public immutable psm;
    IRateLimits public immutable rateLimits;

    address public immutable usdc;

    uint256 internal CENTRIFUGE_REQUEST_ID = 0;

    mapping(address pool => uint256 maxSlippage) public maxSlippages;  // 1e18 precision

    mapping(uint32 destinationDomain     => bytes32 mintRecipient)      public mintRecipients;
    mapping(uint32 destinationEndpointId => bytes32 layerZeroRecipient) public layerZeroRecipients;
    mapping(uint16 destinationCentrifugeId => bytes32 recipient)        public centrifugeRecipients;

    // ERC4626 exchange rate thresholds (1e36 precision)
    mapping(address token => uint256 maxExchangeRate) public maxExchangeRates;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(
        address admin_,
        address proxy_,
        address rateLimits_,
        address psm_,
        address usdc_,
        address cctp_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        proxy      = IALMProxy(proxy_);
        rateLimits = IRateLimits(rateLimits_);
        psm        = psm_;
        usdc       = usdc_;
        cctp       = cctp_;
    }

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setMaxSlippage(address pool, uint256 maxSlippage)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(pool != address(0), "FC/pool-zero-address");

        maxSlippages[pool] = maxSlippage;
        emit MaxSlippageSet(pool, maxSlippage);
    }

    function setMintRecipient(uint32 destinationDomain, bytes32 recipient)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        CCTPLib.setMintRecipient(mintRecipients, recipient, destinationDomain);
    }

    function setLayerZeroRecipient(uint32 destinationEndpointId, bytes32 recipient)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        LayerZeroLib.setRecipient(layerZeroRecipients, destinationEndpointId, recipient);
    }

    function setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        ERC4626Lib.setMaxExchangeRate(maxExchangeRates, token, shares, maxExpectedAssets);
    }

    function setCentrifugeRecipient(uint16 destinationCentrifugeId, bytes32 recipient)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        centrifugeRecipients[destinationCentrifugeId] = recipient;
        emit CentrifugeRecipientSet(destinationCentrifugeId, recipient);
    }

    /**********************************************************************************************/
    /*** Freezer functions                                                                      ***/
    /**********************************************************************************************/

    function removeRelayer(address relayer) external nonReentrant onlyRole(FREEZER) {
        _revokeRole(RELAYER, relayer);
        emit RelayerRemoved(relayer);
    }

    /**********************************************************************************************/
    /*** Relayer ERC20 functions                                                                ***/
    /**********************************************************************************************/

    function transferAsset(address asset, address destination, uint256 amount)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        TransferAssetLib.transfer(address(proxy), address(rateLimits), asset, destination, amount);
    }

    /**********************************************************************************************/
    /*** Relayer PSM functions                                                                  ***/
    /**********************************************************************************************/

    function depositPSM(address asset, uint256 amount)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 shares)
    {
        return PSM3Lib.deposit(address(proxy), address(rateLimits), psm, asset, amount);
    }

    function withdrawPSM(address asset, uint256 maxAmount)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 assetsWithdrawn)
    {
        return PSM3Lib.withdraw(address(proxy), address(rateLimits), psm, asset, maxAmount);
    }

    /**********************************************************************************************/
    /*** Relayer bridging functions                                                             ***/
    /**********************************************************************************************/

    function transferUSDCToCCTP(uint256 usdcAmount, uint32 destinationDomain)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        CCTPLib.transfer({
            proxy             : address(proxy),
            rateLimits        : address(rateLimits),
            cctp              : cctp,
            usdc              : usdc,
            destinationDomain : destinationDomain,
            usdcAmount        : usdcAmount,
            mintRecipients    : mintRecipients
        });
    }

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
    /*** Relayer ERC4626 functions                                                              ***/
    /**********************************************************************************************/

    function depositERC4626(address token, uint256 amount, uint256 minSharesOut)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 shares)
    {
        return ERC4626Lib.deposit({
            proxy            : address(proxy),
            rateLimits       : address(rateLimits),
            token            : token,
            amount           : amount,
            minSharesOut     : minSharesOut,
            maxExchangeRates : maxExchangeRates
        });
    }

    function withdrawERC4626(address token, uint256 amount, uint256 maxSharesIn)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 shares)
    {
        return ERC4626Lib.withdraw(address(proxy), address(rateLimits), token, amount, maxSharesIn);
    }

    function redeemERC4626(address token, uint256 shares, uint256 minAssetsOut)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 assets)
    {
        return ERC4626Lib.redeem(address(proxy), address(rateLimits), token, shares, minAssetsOut);
    }

    function EXCHANGE_RATE_PRECISION() external pure returns (uint256) {
        return ERC4626Lib.EXCHANGE_RATE_PRECISION;
    }

    /**********************************************************************************************/
    /*** Relayer Aave functions                                                                 ***/
    /**********************************************************************************************/

    function depositAave(address aToken, uint256 amount) external nonReentrant onlyRole(RELAYER) {
        AaveLib.deposit(address(proxy), address(rateLimits), aToken, amount, maxSlippages);
    }

    function withdrawAave(address aToken, uint256 amount)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 amountWithdrawn)
    {
        return AaveLib.withdraw(address(proxy), address(rateLimits), aToken, amount);
    }

    /**********************************************************************************************/
    /*** Spark Vault functions                                                                  ***/
    /**********************************************************************************************/

    function takeFromSparkVault(address sparkVault, uint256 assetAmount)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        SparkVaultLib.take(address(proxy), address(rateLimits), sparkVault, assetAmount);
    }

    /**********************************************************************************************/
    /*** Relayer ERC7540 functions                                                              ***/
    /**********************************************************************************************/

    function requestDepositERC7540(address token, uint256 amount)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        ERC7540Lib.deposit({
            proxy      : address(proxy),
            rateLimits : address(rateLimits),
            token      : token,
            amount     : amount
        });
    }

    function claimDepositERC7540(address token)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        ERC7540Lib.claimDeposit({
            proxy      : address(proxy),
            rateLimits : address(rateLimits),
            token      : token
        });
    }

    function requestRedeemERC7540(address token, uint256 shares)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        ERC7540Lib.requestRedeem({
            proxy      : address(proxy),
            rateLimits : address(rateLimits),
            token      : token,
            shares     : shares
        });
    }

    function claimRedeemERC7540(address token)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        ERC7540Lib.claimRedeem({
            proxy      : address(proxy),
            rateLimits : address(rateLimits),
            token      : token
        });
    }

    /**********************************************************************************************/
    /*** Relayer Centrifuge functions                                                           ***/
    /**********************************************************************************************/

    // NOTE: These cancelation methods are compatible with ERC-7887

    function cancelCentrifugeDepositRequest(address token)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        CentrifugeLib.cancelCentrifugeDepositRequest({
            proxy      : address(proxy),
            rateLimits : address(rateLimits),
            token      : token,
            requestId  : CENTRIFUGE_REQUEST_ID
        });
    }

    function claimCentrifugeCancelDepositRequest(address token)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        CentrifugeLib.claimCentrifugeCancelDepositRequest({
            proxy      : address(proxy),
            rateLimits : address(rateLimits),
            token      : token,
            requestId  : CENTRIFUGE_REQUEST_ID
        });
    }

    function cancelCentrifugeRedeemRequest(address token)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        CentrifugeLib.cancelCentrifugeRedeemRequest({
            proxy      : address(proxy),
            rateLimits : address(rateLimits),
            token      : token,
            requestId  : CENTRIFUGE_REQUEST_ID
        });
    }

    function claimCentrifugeCancelRedeemRequest(address token)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        CentrifugeLib.claimCentrifugeCancelRedeemRequest({
            proxy      : address(proxy),
            rateLimits : address(rateLimits),
            token      : token,
            requestId  : CENTRIFUGE_REQUEST_ID
        });
    }

    function transferSharesCentrifuge(
        address token,
        uint128 amount,
        uint16  destinationCentrifugeId
    )
        external
        payable
        nonReentrant
        onlyRole(RELAYER)
    {
        CentrifugeLib.transferSharesCentrifuge({
            proxy                   : address(proxy),
            rateLimits              : address(rateLimits),
            token                   : token,
            destinationCentrifugeId : destinationCentrifugeId,
            amount                  : amount,
            recipient               : centrifugeRecipients[destinationCentrifugeId]
        });
    }

}
