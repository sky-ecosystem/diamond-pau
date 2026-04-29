// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IController }     from "../../src/interfaces/IController.sol";
import { IRateLimits }     from "../../src/interfaces/IRateLimits.sol";
import { IUniswapV3Facet } from "../../src/facets/uniswap-v3/IUniswapV3Facet.sol";

interface IMainnetControllerFull is IController {

    /**********************************************************************************************/
    /*** AaveFacet actions                                                                      ***/
    /**********************************************************************************************/

    function setAaveMaxSlippage(address aToken, uint256 maxSlippage) external;

    function setAaveDepositRateLimit(
        address aToken,
        address pool,
        address underlyingAsset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setAaveWithdrawRateLimit(
        address aToken,
        address pool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function depositAave(address aToken, uint256 amount) external;

    function withdrawAave(address aToken, uint256 amount)
        external
        returns (uint256 amountWithdrawn);

    function LIMIT_AAVE_DEPOSIT() external pure returns (bytes32);

    function LIMIT_AAVE_WITHDRAW() external pure returns (bytes32);

    function getAaveMaxSlippage(address aToken) external view returns (uint256);

    function getAaveDepositRateLimit(address aToken, address pool, address underlyingAsset)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getAaveWithdrawRateLimit(address aToken, address pool)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** BasinFacet actions                                                                     ***/
    /**********************************************************************************************/

    function setBasinDepositRateLimit(
        address basin,
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setBasinWithdrawRateLimit(
        address basin,
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function depositBasin(address basin, address asset, uint256 amount, uint256 minSharesOut)
        external returns (uint256 shares);

    function withdrawBasin(
        address basin,
        address asset,
        uint256 maxAmount,
        uint256 minConversionRate
    ) external returns (uint256 assetsWithdrawn);

    function LIMIT_BASIN_DEPOSIT() external pure returns (bytes32);

    function LIMIT_BASIN_WITHDRAW() external pure returns (bytes32);

    function getBasinDepositRateLimit(address basin, address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getBasinWithdrawRateLimit(address basin, address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** CCTPFacet actions                                                                      ***/
    /**********************************************************************************************/

    function setCCTPMaxFeeCap(uint256 maxFeeCap) external;

    function setCCTPMintRecipient(uint32 destinationDomain, bytes32 recipient) external;

    function setCCTPToCCTPRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setCCTPToDomainRateLimit(
        uint32  destinationDomain,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function transferUSDCToCCTP(uint256 usdcAmount, uint32 destinationDomain) external;

    function transferUSDCToCCTPWithFee(uint256 usdcAmount, uint256 maxFee, uint32 destinationDomain)
        external;

    function LIMIT_USDC_TO_CCTP() external pure returns (bytes32);

    function LIMIT_USDC_TO_DOMAIN() external pure returns (bytes32);

    function getCCTPMaxFeeCap() external view returns (uint256);

    function getCCTPMintRecipient(uint32 destinationDomain) external view returns (bytes32);

    function getCCTPToDomainRateLimit(uint32 destinationDomain)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function CCTPToCCTPRateLimit() external view returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** CentrifugeFacet actions                                                                ***/
    /**********************************************************************************************/

    function setCentrifugeRecipient(uint16 centrifugeId, bytes32 recipient) external;

    function setCentrifugeTransferRateLimit(
        address token,
        uint16  centrifugeId,
        address spoke,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function cancelCentrifugeDepositRequest(address token) external;

    function claimCentrifugeCancelDepositRequest(address token) external;

    function cancelCentrifugeRedeemRequest(address token) external;

    function claimCentrifugeCancelRedeemRequest(address token) external;

    function transferSharesCentrifuge(address token, uint128 amount, uint16 centrifugeId)
        external
        payable;

    // NOTE: DEPOSIT, REDEEM keys will be reused from ERC7450Facet wiring
    function LIMIT_CENTRIFUGE_TRANSFER() external pure returns (bytes32);

    function getCentrifugeRecipient(uint16 centrifugeId) external view returns (bytes32);

    function getCentrifugeTransferRateLimit(address token, uint16 centrifugeId, address spoke)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** CurveFacet actions                                                                     ***/
    /**********************************************************************************************/

    function setCurveMaxSlippage(address pool, uint256 maxSlippage) external;

    function setCurveDepositRateLimit(
        address pool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setCurveSwapRateLimit(
        address pool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setCurveWithdrawRateLimit(
        address pool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function swapCurve(
        address pool,
        uint256 inputIndex,
        uint256 outputIndex,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        returns (uint256 amountOut);

    function addLiquidityCurve(address pool, uint256[] calldata depositAmounts, uint256 minLpAmount)
        external
        returns (uint256 shares);

    function removeLiquidityCurve(
        address            pool,
        uint256            lpBurnAmount,
        uint256[] calldata minWithdrawAmounts
    )
        external
        returns (uint256[] memory withdrawnTokens);

    function LIMIT_CURVE_DEPOSIT() external pure returns (bytes32);

    function LIMIT_CURVE_SWAP() external pure returns (bytes32);

    function LIMIT_CURVE_WITHDRAW() external pure returns (bytes32);

    function getCurveMaxSlippage(address pool) external view returns (uint256);

    function getCurveDepositRateLimit(address pool)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getCurveSwapRateLimit(address pool)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getCurveWithdrawRateLimit(address pool)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** DaiUsdsFacet actions                                                                   ***/
    /**********************************************************************************************/

    function swapUSDSToDAI(uint256 usdsAmount) external;

    function swapDAIToUSDS(uint256 daiAmount) external;

    /**********************************************************************************************/
    /*** ERC4626Facet actions                                                                   ***/
    /**********************************************************************************************/

    function setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets) external;

    function setERC4626DepositRateLimit(
        address token,
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setERC4626WithdrawRateLimit(
        address token,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function depositERC4626(address token, uint256 amount, uint256 minSharesOut)
        external
        returns (uint256 shares);

    function withdrawERC4626(address token, uint256 amount, uint256 maxSharesIn)
        external
        returns (uint256 shares);

    function redeemERC4626(address token, uint256 shares, uint256 minAssetsOut)
        external
        returns (uint256 assets);

    function EXCHANGE_RATE_PRECISION() external pure returns (uint256);

    function LIMIT_4626_DEPOSIT() external pure returns (bytes32);

    function LIMIT_4626_WITHDRAW() external pure returns (bytes32);

    function maxExchangeRates(address token) external view returns (uint256);

    function getERC4626DepositRateLimit(address token, address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getERC4626WithdrawRateLimit(address token)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** ERC7540Facet actions                                                                   ***/
    /**********************************************************************************************/

    function setERC7540DepositRateLimit(
        address token,
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setERC7540RedeemRateLimit(
        address token,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function requestDepositERC7540(address token, uint256 amount) external;

    function claimDepositERC7540(address token) external;

    function requestRedeemERC7540(address token, uint256 shares) external;

    function claimRedeemERC7540(address token) external;

    function LIMIT_7540_DEPOSIT() external pure returns (bytes32);

    function LIMIT_7540_REDEEM() external pure returns (bytes32);

    function getERC7540DepositRateLimit(address token, address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getERC7540RedeemRateLimit(address token)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** FarmFacet actions                                                                      ***/
    /**********************************************************************************************/

    function setFarmDepositRateLimit(
        address farm,
        address stakingToken,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setFarmWithdrawRateLimit(
        address farm,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function depositToFarm(address farm, uint256 amount) external;

    function claimRewardFromFarm(address farm) external returns (uint256 reward);

    function withdrawFromFarm(address farm, uint256 amount) external returns (uint256 reward);

    function LIMIT_FARM_DEPOSIT() external pure returns (bytes32);

    function LIMIT_FARM_WITHDRAW() external pure returns (bytes32);

    function getFarmDepositRateLimit(address farm, address stakingToken)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getFarmWithdrawRateLimit(address farm)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** LayerZeroFacet actions                                                                 ***/
    /**********************************************************************************************/

    function setLayerZeroRecipient(uint32 destinationEndpointId, bytes32 recipient) external;

    function setTransferRateLimit(
        address oft,
        uint32  destinationEndpointId,
        address token,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function transferTokenLayerZero(address oft, uint256 amount, uint32 destinationEndpointId)
        external
        payable;

    function LIMIT_LAYERZERO_TRANSFER() external pure returns (bytes32);

    function layerZeroRecipients(uint32 destinationEndpointId) external view returns (bytes32);

    function getLayerZeroTransferRateLimit(address oft, uint32 destinationEndpointId, address token)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** MapleFacet actions                                                                     ***/
    /**********************************************************************************************/

    function setMapleRedeemRateLimit(
        address mapleToken,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function requestMapleRedemption(address mapleToken, uint256 shares) external;

    function cancelMapleRedemption(address mapleToken, uint256 shares) external;

    function LIMIT_MAPLE_REDEEM() external pure returns (bytes32);

    function getMapleRedeemRateLimit(address mapleToken)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** MerklFacet actions                                                                     ***/
    /**********************************************************************************************/

    function setMerklDistributor(address distributor) external;

    function toggleOperatorMerkl(address operator) external;

    function merklDistributor() external view returns (address);

    /**********************************************************************************************/
    /*** OTCFacet actions                                                                       ***/
    /**********************************************************************************************/

    function setOTCMaxSlippage(address exchange, uint256 maxSlippage) external;

    function setOTCBuffer(address exchange, address otcBuffer) external;

    function setOTCRechargeRate(address exchange, uint256 rechargeRate18) external;

    function setOTCWhitelistedAsset(address exchange, address asset, bool isWhitelisted) external;

    function setOTCSwapRateLimit(
        address exchange,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function otcSend(address exchange, address assetToSend, uint256 amount) external;

    function otcClaim(address exchange, address assetToClaim) external;

    function LIMIT_OTC_SWAP() external pure returns (bytes32);

    function getOTCBuffer(address exchange) external view returns (address);

    function getOTCMaxSlippage(address exchange) external view returns (uint256);

    function getOTCRechargeRate(address exchange) external view returns (uint256);

    function otcWhitelistedAssets(address exchange, address asset) external view returns (bool);

    function otcs(address exchange)
        external
        view
        returns (uint256 sent18, uint256 sentTimestamp, uint256 claimed18);

    function getOtcClaimWithRecharge(address exchange) external view returns (uint256);

    function isOtcSwapReady(address exchange) external view returns (bool);

    function getOTCSwapRateLimit(address exchange)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** PendleFacet actions                                                                    ***/
    /**********************************************************************************************/

    function setPendleRedeemRateLimit(
        address pendleMarket,
        address pt,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function redeemPendlePT(address pendleMarket, uint256 pyAmountIn, uint256 minAmountOut)
        external;

    function LIMIT_PENDLE_PT_REDEEM() external pure returns (bytes32);

    function getPendleRedeemRateLimit(address pendleMarket, address pt)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** PSMFacet actions                                                                       ***/
    /**********************************************************************************************/

    function setPSMUSDSToUSDCSwapRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function swapUSDSToUSDC(uint256 usdcAmount) external;

    function swapUSDCToUSDS(uint256 usdcAmount) external;

    function LIMIT_USDS_TO_USDC() external pure returns (bytes32);

    function psmTo18ConversionFactor() external view returns (uint256);

    function PSMUSDSToUSDCSwapRateLimit() external view returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** SparkVaultFacet actions                                                                ***/
    /**********************************************************************************************/

    function setSparkVaultTakeRateLimit(
        address sparkVault,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function takeFromSparkVault(address sparkVault, uint256 assetAmount) external;

    function LIMIT_SPARK_VAULT_TAKE() external pure returns (bytes32);

    function getSparkVaultTakeRateLimit(address sparkVault)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** SuperstateFacet actions                                                                ***/
    /**********************************************************************************************/

    function setSuperstateSubscribeRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function subscribeSuperstate(uint256 usdcAmount) external;

    function LIMIT_SUPERSTATE_SUBSCRIBE() external pure returns (bytes32);

    function getSuperstateSubscribeRateLimit()
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** TransferAssetFacet actions                                                             ***/
    /**********************************************************************************************/

    function setTransferAssetTransferRateLimit(
        address asset,
        address destination,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function transferAsset(address asset, address destination, uint256 amount) external;

    function LIMIT_ASSET_TRANSFER() external pure returns (bytes32);

    function getTransferAssetTransferRateLimit(address asset, address destination)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** UniswapV3Facet actions                                                                 ***/
    /**********************************************************************************************/

    function setUniswapV3MaxSlippage(address pool, uint256 maxSlippage) external;

    function setUniswapV3PoolMaxTickDelta(address pool, uint24 maxTickDelta) external;

    function setUniswapV3AddLiquidityLowerTickBound(address pool, int24 lowerTickBound) external;

    function setUniswapV3AddLiquidityUpperTickBound(address pool, int24 upperTickBound) external;

    function setUniswapV3TWAPSecondsAgo(address pool, uint32 twapSecondsAgo) external;

    function setUniswapV3DepositRateLimit(
        address pool,
        address token,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setUniswapV3SwapRateLimit(
        address pool,
        address token,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setUniswapV3WithdrawRateLimit(
        address pool,
        address token,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function swapUniswapV3(
        address pool,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24  tickDelta
    )
        external
        returns (uint256 amountOut);

    function addLiquidityUniswapV3(
        address                               pool,
        uint256                               tokenId,
        IUniswapV3Facet.Ticks        calldata ticks,
        IUniswapV3Facet.TokenAmounts calldata target,
        IUniswapV3Facet.TokenAmounts calldata min,
        uint256                               deadline
    )
        external
        returns (uint256, uint128, IUniswapV3Facet.TokenAmounts memory);

    function removeLiquidityUniswapV3(
        address                               pool,
        uint256                               tokenId,
        uint128                               liquidity,
        IUniswapV3Facet.TokenAmounts calldata min,
        uint256                               deadline
    )
        external
        returns (IUniswapV3Facet.TokenAmounts memory);

    function LIMIT_UNISWAP_V3_DEPOSIT() external pure returns (bytes32);

    function LIMIT_UNISWAP_V3_SWAP() external pure returns (bytes32);

    function LIMIT_UNISWAP_V3_WITHDRAW() external pure returns (bytes32);

    function getUniswapV3MaxSlippage(address pool) external view returns (uint256);

    function getUniswapV3PoolMaxTickDelta(address pool) external view returns (uint24);

    function getUniswapV3AddLiquidityTickBounds(address pool)
        external
        view
        returns (int24 lower, int24 upper);

    function getUniswapV3TWAPSecondsAgo(address pool) external view returns (uint32);

    function getUniswapV3DepositRateLimit(address pool, address token)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getUniswapV3SwapRateLimit(address pool, address token)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getUniswapV3WithdrawRateLimit(address pool, address token)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** UniswapV4Facet actions                                                                 ***/
    /**********************************************************************************************/

    function setUniswapV4MaxSlippage(bytes32 poolId, uint256 maxSlippage) external;

    function setUniswapV4TickLimits(
        bytes32 poolId,
        int24   tickLowerMin,
        int24   tickUpperMax,
        uint24  maxTickSpacing
    )
        external;

    function setUniswapV4DepositRateLimit(
        bytes32 poolId,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setUniswapV4SwapRateLimit(
        bytes32 poolId,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setUniswapV4WithdrawRateLimit(
        bytes32 poolId,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function mintPositionUniswapV4(
        bytes32 poolId,
        int24   tickLower,
        int24   tickUpper,
        uint128 liquidity,
        uint128 amount0Max,
        uint128 amount1Max
    )
        external;

    function increaseLiquidityUniswapV4(
        bytes32 poolId,
        uint256 tokenId,
        uint128 liquidityIncrease,
        uint128 amount0Max,
        uint128 amount1Max
    )
        external;

    function decreaseLiquidityUniswapV4(
        bytes32 poolId,
        uint256 tokenId,
        uint128 liquidityDecrease,
        uint128 amount0Min,
        uint128 amount1Min
    )
        external;

    function swapUniswapV4(bytes32 poolId, address tokenIn, uint128 amountIn, uint128 amountOutMin)
        external;

    function LIMIT_UNISWAP_V4_DEPOSIT() external pure returns (bytes32);

    function LIMIT_UNISWAP_V4_SWAP() external pure returns (bytes32);

    function LIMIT_UNISWAP_V4_WITHDRAW() external pure returns (bytes32);

    function uniswapV4MaxSlippages(bytes32 poolId) external view returns (uint256);

    function uniswapV4TickLimits(bytes32 poolId)
        external
        view
        returns (int24 tickLowerMin, int24 tickUpperMax, uint24 maxTickSpacing);

    function getUniswapV4DepositRateLimit(bytes32 poolId)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getUniswapV4SwapRateLimit(bytes32 poolId)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getUniswapV4WithdrawRateLimit(bytes32 poolId)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** USDEFacet actions                                                                      ***/
    /**********************************************************************************************/

    function setUSDEBurnRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setUSDEMintRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setUSDECooldownRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setDelegatedSigner(address delegatedSigner) external;

    function removeDelegatedSigner(address delegatedSigner) external;

    function prepareUSDeMint(uint256 usdcAmount) external;

    function prepareUSDeBurn(uint256 usdeAmount) external;

    function cooldownAssetsSUSDe(uint256 usdeAmount) external returns (uint256 cooldownShares);

    function cooldownSharesSUSDe(uint256 susdeAmount) external returns (uint256 cooldownAssets);

    function unstakeSUSDe() external;

    function LIMIT_USDE_BURN() external view returns (bytes32);

    function LIMIT_USDE_MINT() external view returns (bytes32);

    function LIMIT_SUSDE_COOLDOWN() external view returns (bytes32);

    function USDEBurnRateLimit() external view returns (IRateLimits.RateLimitData memory);

    function USDEMintRateLimit() external view returns (IRateLimits.RateLimitData memory);

    function USDECooldownRateLimit() external view returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** USDSFacet actions                                                                      ***/
    /**********************************************************************************************/

    function setUSDSVault(address vault) external;

    function setUSDSMintRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function mintUSDS(uint256 usdsAmount) external;

    function burnUSDS(uint256 usdsAmount) external;

    function LIMIT_USDS_MINT() external pure returns (bytes32);

    function usdsVault() external view returns (address);

    function USDSMintRateLimit() external view returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** WEETHFacet actions                                                                     ***/
    /**********************************************************************************************/

    function setWEETHDepositRateLimit(
        address weethModule,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setWEETHWithdrawRateLimit(
        address weethModule,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function depositToWeETH(uint256 amount, uint256 minSharesOut) external returns (uint256 shares);

    function requestWithdrawFromWeETH(
        address weethModule,
        uint256 weethShares,
        uint256 minEETHShares
    )
        external
        returns (uint256 requestId);

    function claimWithdrawalFromWeETH(address weethModule, uint256 requestId)
        external
        returns (uint256 ethReceived);

    function LIMIT_WEETH_DEPOSIT() external pure returns (bytes32);

    function LIMIT_WEETH_REQUEST_WITHDRAW() external pure returns (bytes32);

    function getWEETHDepositRateLimit(address weethModule)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getWEETHWithdrawRateLimit(address weethModule)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    /**********************************************************************************************/
    /*** WrapProxyETHFacet actions                                                              ***/
    /**********************************************************************************************/

    function wrapAllProxyETH() external;

    /**********************************************************************************************/
    /*** WSTETHFacet actions                                                                    ***/
    /**********************************************************************************************/

    function setWSTETHDepositRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setWSTETHRequestWithdrawRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function depositToWstETH(uint256 amount) external;

    function requestWithdrawFromWstETH(uint256 amountToRedeem)
        external
        returns (uint256[] memory requestIds);

    function claimWithdrawalFromWstETH(uint256 requestId) external;

    function LIMIT_WSTETH_DEPOSIT() external pure returns (bytes32);

    function LIMIT_WSTETH_REQUEST_WITHDRAW() external pure returns (bytes32);

    function WSTETHDepositRateLimit() external view returns (IRateLimits.RateLimitData memory);

    function WSTETHRequestWithdrawRateLimit()
        external
        view
        returns (IRateLimits.RateLimitData memory);

}
