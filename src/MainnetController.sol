// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {
    AccessControlEnumerable
} from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { AaveLib }          from "./libraries/AaveLib.sol";
import { CCTPLib }          from "./libraries/CCTPLib.sol";
import { CurveLib }         from "./libraries/CurveLib.sol";
import { DAIUSDSLib }       from "./libraries/DAIUSDSLib.sol";
import { ERC4626Lib }       from "./libraries/ERC4626Lib.sol";
import { FarmLib }          from "./libraries/FarmLib.sol";
import { LayerZeroLib }     from "./libraries/LayerZeroLib.sol";
import { MapleLib }         from "./libraries/MapleLib.sol";
import { OTCLib }           from "./libraries/OTCLib.sol";
import { PSMLib }           from "./libraries/PSMLib.sol";
import { SparkVaultLib }    from "./libraries/SparkVaultLib.sol";
import { SuperstateLib }    from "./libraries/SuperstateLib.sol";
import { TransferAssetLib } from "./libraries/TransferAssetLib.sol";
import { UniswapV4Lib }     from "./libraries/UniswapV4Lib.sol";
import { USDELib }          from "./libraries/USDELib.sol";
import { USDSLib }          from "./libraries/USDSLib.sol";
import { WEETHLib }         from "./libraries/WEETHLib.sol";
import { WrapProxyETHLib }  from "./libraries/WrapProxyETHLib.sol";
import { WSTETHLib }        from "./libraries/WSTETHLib.sol";

contract MainnetController is ReentrancyGuard, AccessControlEnumerable {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event MaxSlippageSet(address indexed pool, uint256 maxSlippage);

    event RelayerRemoved(address indexed relayer);

    /**********************************************************************************************/
    /*** Roles                                                                                  ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    /**********************************************************************************************/
    /*** Rate Limits Keys                                                                       ***/
    /**********************************************************************************************/

    // TODO: These should be baked into the deployed facets and wired as needed.
    bytes32 public constant LIMIT_4626_DEPOSIT            = ERC4626Lib.LIMIT_DEPOSIT;
    bytes32 public constant LIMIT_4626_WITHDRAW           = ERC4626Lib.LIMIT_WITHDRAW;
    bytes32 public constant LIMIT_AAVE_DEPOSIT            = AaveLib.LIMIT_DEPOSIT;
    bytes32 public constant LIMIT_AAVE_WITHDRAW           = AaveLib.LIMIT_WITHDRAW;
    bytes32 public constant LIMIT_ASSET_TRANSFER          = TransferAssetLib.LIMIT_TRANSFER;
    bytes32 public constant LIMIT_DAIUSDS_SWAP            = DAIUSDSLib.LIMIT_SWAP;
    bytes32 public constant LIMIT_CURVE_DEPOSIT           = CurveLib.LIMIT_DEPOSIT;
    bytes32 public constant LIMIT_CURVE_SWAP              = CurveLib.LIMIT_SWAP;
    bytes32 public constant LIMIT_CURVE_WITHDRAW          = CurveLib.LIMIT_WITHDRAW;
    bytes32 public constant LIMIT_FARM_DEPOSIT            = FarmLib.LIMIT_DEPOSIT;
    bytes32 public constant LIMIT_FARM_WITHDRAW           = FarmLib.LIMIT_WITHDRAW;
    bytes32 public constant LIMIT_LAYERZERO_TRANSFER      = LayerZeroLib.LIMIT_TRANSFER;
    bytes32 public constant LIMIT_MAPLE_REDEEM            = MapleLib.LIMIT_REDEEM;
    bytes32 public constant LIMIT_OTC_SWAP                = OTCLib.LIMIT_SWAP;
    bytes32 public constant LIMIT_SPARK_VAULT_TAKE        = SparkVaultLib.LIMIT_TAKE;
    bytes32 public constant LIMIT_SUPERSTATE_SUBSCRIBE    = SuperstateLib.LIMIT_SUBSCRIBE;
    bytes32 public constant LIMIT_SUSDE_COOLDOWN          = USDELib.LIMIT_SUSDE_COOLDOWN;
    bytes32 public constant LIMIT_UNISWAP_V4_DEPOSIT      = UniswapV4Lib.LIMIT_DEPOSIT;
    bytes32 public constant LIMIT_UNISWAP_V4_SWAP         = UniswapV4Lib.LIMIT_SWAP;
    bytes32 public constant LIMIT_UNISWAP_V4_WITHDRAW     = UniswapV4Lib.LIMIT_WITHDRAW;
    bytes32 public constant LIMIT_USDC_TO_CCTP            = CCTPLib.LIMIT_TO_CCTP;
    bytes32 public constant LIMIT_USDC_TO_DOMAIN          = CCTPLib.LIMIT_TO_DOMAIN;
    bytes32 public constant LIMIT_USDE_BURN               = USDELib.LIMIT_USDE_BURN;
    bytes32 public constant LIMIT_USDE_MINT               = USDELib.LIMIT_USDE_MINT;
    bytes32 public constant LIMIT_USDS_MINT               = USDSLib.LIMIT_MINT;
    bytes32 public constant LIMIT_USDS_TO_USDC            = PSMLib.LIMIT_USDS_TO_USDC;
    bytes32 public constant LIMIT_WEETH_DEPOSIT           = WEETHLib.LIMIT_DEPOSIT;
    bytes32 public constant LIMIT_WEETH_REQUEST_WITHDRAW  = WEETHLib.LIMIT_REQUEST_WITHDRAW;
    bytes32 public constant LIMIT_WSTETH_DEPOSIT          = WSTETHLib.LIMIT_DEPOSIT;
    bytes32 public constant LIMIT_WSTETH_REQUEST_WITHDRAW = WSTETHLib.LIMIT_REQUEST_WITHDRAW;

    /**********************************************************************************************/
    /*** Controller State Variables                                                             ***/
    /**********************************************************************************************/

    address public immutable proxy;
    address public immutable rateLimits;

    /**********************************************************************************************/
    /*** Integration-Specific State Variables                                                   ***/
    /**********************************************************************************************/

    address public usdsVault;

    address public ethenaMinter;

    address public cctpTokenMessenger;
    address public cctpUSDC;

    mapping(address pool => uint256 maxSlippage) public maxSlippages;  // 1e18 precision

    mapping(uint32 destinationDomain     => bytes32 mintRecipient)      public mintRecipients;  // CCTP mint recipients
    mapping(uint32 destinationEndpointId => bytes32 layerZeroRecipient) public layerZeroRecipients;

    // OTC swap (also uses maxSlippages)
    mapping(address exchange => OTCLib.OTC otcData) public otcs;

    mapping(address exchange => mapping(address asset => bool)) public otcWhitelistedAssets;

    // ERC4626 exchange rate thresholds (1e36 precision)
    mapping(address token => uint256 maxExchangeRate) public maxExchangeRates;

    // Uniswap V4 tick ranges
    mapping(bytes32 poolId => UniswapV4Lib.TickLimits tickLimits) public uniswapV4TickLimits;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(address admin_, address proxy_, address rateLimits_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        proxy      = proxy_;
        rateLimits = rateLimits_;
    }

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

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

    function setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        ERC4626Lib.setMaxExchangeRate(maxExchangeRates, token, shares, maxExpectedAssets);
    }

    function setUniswapV4TickLimits(
        bytes32 poolId,
        int24   tickLowerMin,
        int24   tickUpperMax,
        uint24  maxTickSpacing
    )
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        UniswapV4Lib.setTickLimits(
            poolId,
            tickLowerMin,
            tickUpperMax,
            maxTickSpacing,
            uniswapV4TickLimits
        );
    }

    function setUSDSVault(address vault) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        usdsVault = vault;
    }

    function setEthenaMinter(address minter) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        ethenaMinter = minter;
    }

    function setCCTPTokenMessenger(address messenger) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        cctpTokenMessenger = messenger;
    }

    function setCCTPUSDC(address usdc) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        cctpUSDC = usdc;
    }

    /**********************************************************************************************/
    /*** Freezer functions                                                                      ***/
    /**********************************************************************************************/

    function removeRelayer(address relayer) external nonReentrant onlyRole(FREEZER) {
        _revokeRole(RELAYER, relayer);
        emit RelayerRemoved(relayer);
    }

    /**********************************************************************************************/
    /*** Relayer vault functions                                                                ***/
    /**********************************************************************************************/

    function mintUSDS(uint256 usdsAmount) external nonReentrant onlyRole(RELAYER) {
        USDSLib.mint(proxy, rateLimits, usdsVault, usdsAmount);
    }

    function burnUSDS(uint256 usdsAmount) external nonReentrant onlyRole(RELAYER) {
        USDSLib.burn(proxy, rateLimits, usdsVault, usdsAmount);
    }

    /**********************************************************************************************/
    /*** Relayer ERC20 functions                                                                ***/
    /**********************************************************************************************/

    function transferAsset(address asset, address destination, uint256 amount)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        TransferAssetLib.transfer(proxy, rateLimits, asset, destination, amount);
    }

    /**********************************************************************************************/
    /*** wstETH Integration                                                                     ***/
    /**********************************************************************************************/

    function depositToWSTETH(uint256 amount) external nonReentrant onlyRole(RELAYER) {
        WSTETHLib.deposit(proxy, rateLimits, amount);
    }

    function requestWithdrawFromWSTETH(uint256 amountToRedeem)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256[] memory requestIds)
    {
        return WSTETHLib.requestWithdraw(proxy, rateLimits, amountToRedeem);
    }

    function claimWithdrawalFromWSTETH(uint256 requestId) external nonReentrant onlyRole(RELAYER) {
        WSTETHLib.claimWithdrawal(proxy, rateLimits, requestId);
    }

    /**********************************************************************************************/
    /*** weETH Integration                                                                      ***/
    /**********************************************************************************************/

    function depositToWEETH(uint256 amount, uint256 minSharesOut)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 shares)
    {
        return WEETHLib.deposit(proxy, rateLimits, amount, minSharesOut);
    }

    function requestWithdrawFromWEETH(
        address weethModule,
        uint256 weethShares,
        uint256 minEETHShares
    )
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 requestId)
    {
        return WEETHLib.requestWithdraw(proxy, rateLimits, weethModule, weethShares, minEETHShares);
    }

    function claimWithdrawalFromWEETH(address weethModule, uint256 requestId)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 ethReceived)
    {
        return WEETHLib.claimWithdrawal(proxy, rateLimits, weethModule, requestId);
    }

    /**********************************************************************************************/
    /*** Relayer wrap ETH function                                                              ***/
    /**********************************************************************************************/

    function wrapAllProxyETH() external nonReentrant onlyRole(RELAYER) {
        WrapProxyETHLib.wrapAll(proxy);
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
        return ERC4626Lib.deposit(proxy, rateLimits, token, amount, minSharesOut, maxExchangeRates);
    }

    function withdrawERC4626(address token, uint256 amount, uint256 maxSharesIn)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 shares)
    {
        return ERC4626Lib.withdraw(proxy, rateLimits, token, amount, maxSharesIn);
    }

    function redeemERC4626(address token, uint256 shares, uint256 minAssetsOut)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 assets)
    {
        return ERC4626Lib.redeem(proxy, rateLimits, token, shares, minAssetsOut);
    }

    function EXCHANGE_RATE_PRECISION() external pure returns (uint256) {
        return ERC4626Lib.EXCHANGE_RATE_PRECISION;
    }

    /**********************************************************************************************/
    /*** Relayer Aave functions                                                                 ***/
    /**********************************************************************************************/

    function depositAave(address aToken, uint256 amount) external nonReentrant onlyRole(RELAYER) {
        AaveLib.deposit(proxy, rateLimits, aToken, amount, maxSlippages);
    }

    function withdrawAave(address aToken, uint256 amount)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 amountWithdrawn)
    {
        return AaveLib.withdraw(proxy, rateLimits, aToken, amount);
    }

    /**********************************************************************************************/
    /*** Relayer Curve StableSwap functions                                                     ***/
    /**********************************************************************************************/

    function swapCurve(
        address pool,
        uint256 inputIndex,
        uint256 outputIndex,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 amountOut)
    {
        return CurveLib.swap({
            proxy        : proxy,
            rateLimits   : rateLimits,
            pool         : pool,
            inputIndex   : inputIndex,
            outputIndex  : outputIndex,
            amountIn     : amountIn,
            minAmountOut : minAmountOut,
            maxSlippages : maxSlippages
        });
    }

    function addLiquidityCurve(address pool, uint256[] memory depositAmounts, uint256 minLpAmount)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 shares)
    {
        return CurveLib.addLiquidity({
            proxy          : proxy,
            rateLimits     : rateLimits,
            pool           : pool,
            minLpAmount    : minLpAmount,
            depositAmounts : depositAmounts,
            maxSlippages   : maxSlippages
        });
    }

    function removeLiquidityCurve(
        address            pool,
        uint256            lpBurnAmount,
        uint256[] calldata minWithdrawAmounts
    )
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256[] memory withdrawnTokens)
    {
        return CurveLib.removeLiquidity({
            proxy              : proxy,
            rateLimits         : rateLimits,
            pool               : pool,
            lpBurnAmount       : lpBurnAmount,
            minWithdrawAmounts : minWithdrawAmounts,
            maxSlippages       : maxSlippages
        });
    }

    /**********************************************************************************************/
    /*** Uniswap V4 functions                                                                   ***/
    /**********************************************************************************************/

    function mintPositionUniswapV4(
        bytes32 poolId,
        int24   tickLower,
        int24   tickUpper,
        uint128 liquidity,
        uint128 amount0Max,
        uint128 amount1Max
    )
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        UniswapV4Lib.mintPosition({
            proxy      : proxy,
            rateLimits : rateLimits,
            poolId     : poolId,
            tickLower  : tickLower,
            tickUpper  : tickUpper,
            liquidity  : liquidity,
            amount0Max : amount0Max,
            amount1Max : amount1Max,
            tickLimits : uniswapV4TickLimits
        });
    }

    function increaseLiquidityUniswapV4(
        bytes32 poolId,
        uint256 tokenId,
        uint128 liquidityIncrease,
        uint128 amount0Max,
        uint128 amount1Max
    )
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        UniswapV4Lib.increasePosition({
            proxy             : proxy,
            rateLimits        : rateLimits,
            poolId            : poolId,
            tokenId           : tokenId,
            liquidityIncrease : liquidityIncrease,
            amount0Max        : amount0Max,
            amount1Max        : amount1Max,
            tickLimits        : uniswapV4TickLimits
        });
    }

    function decreaseLiquidityUniswapV4(
        bytes32 poolId,
        uint256 tokenId,
        uint128 liquidityDecrease,
        uint128 amount0Min,
        uint128 amount1Min
    )
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        UniswapV4Lib.decreasePosition({
            proxy             : proxy,
            rateLimits        : rateLimits,
            poolId            : poolId,
            tokenId           : tokenId,
            liquidityDecrease : liquidityDecrease,
            amount0Min        : amount0Min,
            amount1Min        : amount1Min
        });
    }

    function swapUniswapV4(
        bytes32 poolId,
        address tokenIn,
        uint128 amountIn,
        uint128 amountOutMin
    )
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        UniswapV4Lib.swap(proxy, rateLimits, poolId, tokenIn, amountIn, amountOutMin, maxSlippages);
    }

    /**********************************************************************************************/
    /*** Relayer Ethena functions                                                               ***/
    /**********************************************************************************************/

    function setDelegatedSigner(address delegatedSigner) external nonReentrant onlyRole(RELAYER) {
        USDELib.setDelegatedSigner(proxy, ethenaMinter, delegatedSigner);
    }

    function removeDelegatedSigner(address delegatedSigner)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        USDELib.removeDelegatedSigner(proxy, ethenaMinter, delegatedSigner);
    }

    // Note that Ethena's mint/redeem per-block limits include other users.
    function prepareUSDEMint(uint256 usdcAmount) external nonReentrant onlyRole(RELAYER) {
        USDELib.prepareMint(proxy, rateLimits, ethenaMinter, usdcAmount);
    }

    function prepareUSDEBurn(uint256 usdeAmount) external nonReentrant onlyRole(RELAYER) {
        USDELib.prepareBurn(proxy, rateLimits, ethenaMinter, usdeAmount);
    }

    function cooldownAssetsSUSDE(uint256 usdeAmount)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 cooldownShares)
    {
        return USDELib.cooldownAssets(proxy, rateLimits, usdeAmount);
    }

    function cooldownSharesSUSDE(uint256 susdeAmount)
        external
        nonReentrant
        onlyRole(RELAYER)
        returns (uint256 cooldownAssets)
    {
        return USDELib.cooldownShares(proxy, rateLimits, susdeAmount);
    }

    function unstakeSUSDE() external nonReentrant onlyRole(RELAYER) {
        USDELib.unstakeSUSDE(proxy);
    }

    /**********************************************************************************************/
    /*** Relayer Maple functions                                                                ***/
    /**********************************************************************************************/

    function requestMapleRedemption(address mapleToken, uint256 shares)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        MapleLib.requestRedemption(proxy, rateLimits, mapleToken, shares);
    }

    function cancelMapleRedemption(address mapleToken, uint256 shares)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        MapleLib.cancelRedemption(proxy, rateLimits, mapleToken, shares);
    }

    /**********************************************************************************************/
    /*** Relayer Superstate functions                                                           ***/
    /**********************************************************************************************/

    function subscribeSuperstate(uint256 usdcAmount) external nonReentrant onlyRole(RELAYER) {
        SuperstateLib.subscribe(proxy, rateLimits, usdcAmount);
    }

    /**********************************************************************************************/
    /*** Relayer DaiUsds functions                                                              ***/
    /**********************************************************************************************/

    function swapUSDSToDAI(uint256 usdsAmount) external nonReentrant onlyRole(RELAYER) {
        DAIUSDSLib.swapUSDSToDAI(proxy, rateLimits, usdsAmount);
    }

    function swapDAIToUSDS(uint256 daiAmount) external nonReentrant onlyRole(RELAYER) {
        DAIUSDSLib.swapDAIToUSDS(proxy, rateLimits, daiAmount);
    }

    /**********************************************************************************************/
    /*** Relayer PSM functions                                                                  ***/
    /**********************************************************************************************/

    // NOTE: The param `usdcAmount` is denominated in 1e6 precision to match how PSM uses
    //       USDC precision for both `buyGemNoFee` and `sellGemNoFee`
    function swapUSDSToUSDC(uint256 usdcAmount) external nonReentrant onlyRole(RELAYER) {
        PSMLib.swapUSDSToUSDC(proxy, rateLimits, usdcAmount);
    }

    function swapUSDCToUSDS(uint256 usdcAmount) external nonReentrant onlyRole(RELAYER) {
        PSMLib.swapUSDCToUSDS(proxy, rateLimits, usdcAmount);
    }

    function psmTo18ConversionFactor() external view returns (uint256) {
        return PSMLib.to18ConversionFactor();
    }

    /**********************************************************************************************/
    /*** LayerZero functions                                                                    ***/
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
            proxy                 : proxy,
            rateLimits            : rateLimits,
            oftAddress            : oftAddress,
            amount                : amount,
            destinationEndpointId : destinationEndpointId,
            layerZeroRecipients   : layerZeroRecipients
        });
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
            proxy             : proxy,
            rateLimits        : rateLimits,
            cctp              : cctpTokenMessenger,
            usdc              : cctpUSDC,
            destinationDomain : destinationDomain,
            usdcAmount        : usdcAmount,
            mintRecipients    : mintRecipients
        });
    }

    /**********************************************************************************************/
    /*** Relayer SPK Farm functions                                                             ***/
    /**********************************************************************************************/

    function depositToFarm(address farm, uint256 amount) external nonReentrant onlyRole(RELAYER) {
        FarmLib.deposit(proxy, rateLimits, farm, amount);
    }

    function withdrawFromFarm(address farm, uint256 amount)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        FarmLib.withdraw(proxy, rateLimits, farm, amount);
    }

    /**********************************************************************************************/
    /*** Spark Vault functions                                                                  ***/
    /**********************************************************************************************/

    function takeFromSparkVault(address sparkVault, uint256 assetAmount)
        external
        nonReentrant
        onlyRole(RELAYER)
    {
        SparkVaultLib.take(proxy, rateLimits, sparkVault, assetAmount);
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
            proxy             : proxy,
            rateLimits        : rateLimits,
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
        OTCLib.claim(proxy, exchange, assetToClaim, otcWhitelistedAssets, otcs);
    }

    function getOTCClaimWithRecharge(address exchange) external view returns (uint256) {
        return OTCLib.getClaimWithRecharge(exchange, otcs);
    }

    function isOTCSwapReady(address exchange) external view returns (bool) {
        return OTCLib.isSwapReady(exchange, otcs, maxSlippages);
    }

}
