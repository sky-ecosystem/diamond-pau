// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IController }     from "../../src/interfaces/IController.sol";
import { IUniswapV3Facet } from "../../src/facets/uniswap-v3/IUniswapV3Facet.sol";

interface IMainnetControllerFull is IController {

    /**********************************************************************************************/
    /*** AaveFacet actions                                                                      ***/
    /**********************************************************************************************/

    function AAVE_FACET_VERSION() external pure returns (string memory);

    function setAaveMaxSlippage(address aToken, uint256 maxSlippage) external;

    function depositAave(address aToken, uint256 amount) external;

    function withdrawAave(address aToken, uint256 amount)
        external
        returns (uint256 amountWithdrawn);

    function getAaveMaxSlippage(address aToken) external view returns (uint256);

    function getAaveDepositRateLimitKey(address aToken, address pool, address underlyingAsset)
        external
        pure
        returns (bytes32 key);

    function getAaveWithdrawRateLimitKey(address aToken, address pool)
        external
        pure
        returns (bytes32 key);

    /**********************************************************************************************/
    /*** BasinFacet actions                                                                     ***/
    /**********************************************************************************************/

    function BASIN_FACET_VERSION() external pure returns (string memory);

    function depositBasin(address basin, address asset, uint256 amount, uint256 minSharesOut)
        external returns (uint256 shares);

    function withdrawBasin(
        address basin,
        address asset,
        uint256 maxAmount,
        uint256 minConversionRate
    ) external returns (uint256 assetsWithdrawn);

    function getBasinDepositRateLimitKey(address basin, address asset)
        external
        pure
        returns (bytes32 key);

    function getBasinWithdrawRateLimitKey(address basin, address asset)
        external
        pure
        returns (bytes32 key);

    /**********************************************************************************************/
    /*** CCTPFacet actions                                                                      ***/
    /**********************************************************************************************/

    function CCTP_FACET_VERSION() external pure returns (string memory);

    function CCTP_DESTINATION_CALLER() external pure returns (bytes32);

    function CCTP_MAX_FEE() external pure returns (uint256);

    function CCTP_MAX_FINALITY_THRESHOLD() external pure returns (uint32);

    function cctp() external view returns (address);

    function cctpFacetUSDC() external view returns (address);

    function setCCTPMaxFeeCap(uint256 maxFeeCap) external;

    function setCCTPMintRecipient(uint32 destinationDomain, bytes32 recipient) external;

    function transferUSDCToCCTP(uint256 usdcAmount, uint32 destinationDomain) external;

    function transferUSDCToCCTPWithFee(uint256 usdcAmount, uint256 maxFee, uint32 destinationDomain)
        external;

    function getCCTPMaxFeeCap() external view returns (uint256);

    function toCCTPRateLimitKey() external pure returns (bytes32 key);

    function getCCTPMintRecipient(uint32 destinationDomain) external view returns (bytes32);

    function getCCTPToDomainRateLimitKey(uint32 destinationDomain)
        external
        pure
        returns (bytes32 key);

    /**********************************************************************************************/
    /*** CentrifugeFacet actions                                                                ***/
    /**********************************************************************************************/

    function CENTRIFUGE_FACET_VERSION() external pure returns (string memory);

    function CENTRIFUGE_REQUEST_ID() external pure returns (uint256);

    function setCentrifugeRecipient(uint16 centrifugeId, bytes32 recipient) external;

    function cancelCentrifugeDepositRequest(address token) external;

    function claimCentrifugeCancelDepositRequest(address token) external;

    function cancelCentrifugeRedeemRequest(address token) external;

    function claimCentrifugeCancelRedeemRequest(address token) external;

    function transferSharesCentrifuge(address token, uint128 amount, uint16 centrifugeId)
        external
        payable;

    function getCentrifugeRecipient(uint16 centrifugeId) external view returns (bytes32);

    function getCentrifugeCancelDepositRateLimitKey(address token) external pure returns (bytes32 key);

    function getCentrifugeClaimCancelDepositRateLimitKey(address token) external pure returns (bytes32 key);

    function getCentrifugeCancelRedeemRateLimitKey(address token) external pure returns (bytes32 key);

    function getCentrifugeClaimCancelRedeemRateLimitKey(address token) external pure returns (bytes32 key);

    function getCentrifugeTransferRateLimitKey(address token, uint16 centrifugeId, address spoke)
        external
        pure
        returns (bytes32 key);

    /**********************************************************************************************/
    /*** CurveFacet actions                                                                     ***/
    /**********************************************************************************************/

    function CURVE_FACET_VERSION() external pure returns (string memory);

    function setCurveMaxSlippage(address pool, uint256 maxSlippage) external;

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

    function getCurveMaxSlippage(address pool) external view returns (uint256);

    function getCurveAggregateDepositRateLimitKey(address pool) external pure returns (bytes32 key);

    function getCurveAssetDepositRateLimitKey(address pool, address token)
        external
        pure
        returns (bytes32 key);

    function getCurveSwapRateLimitKey(address pool, address token)
        external
        pure
        returns (bytes32 key);

    function getCurveWithdrawRateLimitKey(address pool) external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** DaiUsdsFacet actions                                                                   ***/
    /**********************************************************************************************/

    function DAI_USDS_FACET_VERSION() external pure returns (string memory);

    function swapUSDSToDAI(uint256 usdsAmount) external;

    function swapDAIToUSDS(uint256 daiAmount) external;

    function daiUSDSFacetDAI() external view returns (address);

    function daiUSDSFacetDAIUSDS() external view returns (address);

    function daiUSDSFacetUSDS() external view returns (address);

    /**********************************************************************************************/
    /*** ERC4626Facet actions                                                                   ***/
    /**********************************************************************************************/

    function ERC4626_FACET_VERSION() external pure returns (string memory);

    function setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets) external;

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

    function maxExchangeRates(address token) external view returns (uint256);

    function getERC4626DepositRateLimitKey(address token, address asset)
        external
        pure
        returns (bytes32 key);

    function getERC4626WithdrawRateLimitKey(address token) external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** ERC7540Facet actions                                                                   ***/
    /**********************************************************************************************/

    function ERC7540_FACET_VERSION() external pure returns (string memory);

    function requestDepositERC7540(address token, uint256 amount) external;

    function claimDepositERC7540(address token) external;

    function requestRedeemERC7540(address token, uint256 shares) external;

    function claimRedeemERC7540(address token) external;

    function getERC7540RequestDepositRateLimitKey(address token, address asset)
        external
        pure
        returns (bytes32 key);

    function getERC7540ClaimDepositRateLimitKey(address token) external pure returns (bytes32 key);

    function getERC7540RequestRedeemRateLimitKey(address token) external pure returns (bytes32 key);

    function getERC7540ClaimRedeemRateLimitKey(address token) external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** FarmFacet actions                                                                      ***/
    /**********************************************************************************************/

    function FARM_FACET_VERSION() external pure returns (string memory);

    function depositToFarm(address farm, uint256 amount) external;

    function claimRewardFromFarm(address farm) external returns (uint256 reward);

    function withdrawFromFarm(address farm, uint256 amount) external returns (uint256 reward);

    function getFarmClaimRewardRateLimitKey(address farm) external pure returns (bytes32 key);

    function getFarmDepositRateLimitKey(address farm, address stakingToken)
        external
        pure
        returns (bytes32 key);

    function getFarmWithdrawRateLimitKey(address farm) external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** LayerZeroFacet actions                                                                 ***/
    /**********************************************************************************************/

    function LAYER_ZERO_FACET_VERSION() external pure returns (string memory);

    function setLayerZeroRecipient(uint32 destinationEndpointId, bytes32 recipient) external;

    function transferTokenLayerZero(address oft, uint256 amount, uint32 destinationEndpointId)
        external
        payable;

    function layerZeroRecipients(uint32 destinationEndpointId) external view returns (bytes32);

    function getLayerZeroTransferRateLimitKey(
        address oft,
        uint32  destinationEndpointId,
        address token
    )
        external
        pure
        returns (bytes32 key);

    /**********************************************************************************************/
    /*** MapleFacet actions                                                                     ***/
    /**********************************************************************************************/

    function MAPLE_FACET_VERSION() external pure returns (string memory);

    function requestMapleRedemption(address mapleToken, uint256 shares) external;

    function cancelMapleRedemption(address mapleToken, uint256 shares) external;

    function getMapleCancelRedeemRateLimitKey(address mapleToken) external pure returns (bytes32 key);

    function getMapleRequestRedeemRateLimitKey(address mapleToken)
        external
        pure
        returns (bytes32 key);

    /**********************************************************************************************/
    /*** MerklFacet actions                                                                     ***/
    /**********************************************************************************************/

    function MERKL_FACET_VERSION() external pure returns (string memory);

    function toggleOperatorMerkl(address distributor, address operator) external;

    function getMerklToggleOperatorRateLimitKey(address distributor, address operator)
        external
        pure
        returns (bytes32 key);

    /**********************************************************************************************/
    /*** OTCFacet actions                                                                       ***/
    /**********************************************************************************************/

    function OTC_FACET_VERSION() external pure returns (string memory);

    function setOTCMaxSlippage(address exchange, uint256 maxSlippage) external;

    function setOTCBuffer(address exchange, address otcBuffer) external;

    function setOTCRechargeRate(address exchange, uint256 rechargeRate18) external;

    function setOTCWhitelistedAsset(address exchange, address asset, bool isWhitelisted) external;

    function otcSend(address exchange, address assetToSend, uint256 amount) external;

    function otcClaim(address exchange, address assetToClaim) external;

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

    function getOTCSwapRateLimitKey(address exchange) external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** PendleFacet actions                                                                    ***/
    /**********************************************************************************************/

    function PENDLE_FACET_VERSION() external pure returns (string memory);

    function redeemPendlePT(address pendleMarket, uint256 pyAmountIn, uint256 minAmountOut)
        external;

    function pendleRouter() external view returns (address);

    function getPendleRedeemRateLimitKey(address pendleMarket, address pt)
        external
        pure
        returns (bytes32 key);

    /**********************************************************************************************/
    /*** PSMFacet actions                                                                       ***/
    /**********************************************************************************************/

    function PSM_FACET_VERSION() external pure returns (string memory);

    function swapUSDSToUSDC(uint256 usdcAmount) external;

    function swapUSDCToUSDS(uint256 usdcAmount) external;

    function psmTo18ConversionFactor() external view returns (uint256);

    function psm() external view returns (address);

    function psmFacetDAI() external view returns (address);

    function psmFacetDAIUSDS() external view returns (address);

    function psmFacetUSDC() external view returns (address);

    function psmFacetUSDS() external view returns (address);

    function psmUSDSToUSDCSwapRateLimitKey() external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** SparkVaultFacet actions                                                                ***/
    /**********************************************************************************************/

    function SPARK_VAULT_FACET_VERSION() external pure returns (string memory);

    function takeFromSparkVault(address sparkVault, uint256 assetAmount) external;

    function getSparkVaultTakeRateLimitKey(address sparkVault) external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** SuperstateFacet actions                                                                ***/
    /**********************************************************************************************/

    function SUPERSTATE_FACET_VERSION() external pure returns (string memory);

    function subscribeSuperstate(uint256 usdcAmount) external;

    function superstateFacetUSDC() external view returns (address);

    function superstateFacetUSTB() external view returns (address);

    function superstateSubscribeRateLimitKey() external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** TransferAssetFacet actions                                                             ***/
    /**********************************************************************************************/

    function TRANSFER_ASSET_FACET_VERSION() external pure returns (string memory);

    function transferAsset(address asset, address destination, uint256 amount) external;

    function getTransferAssetTransferRateLimitKey(address asset, address destination)
        external
        pure
        returns (bytes32 key);

    /**********************************************************************************************/
    /*** UniswapV3Facet actions                                                                 ***/
    /**********************************************************************************************/

    function UNISWAP_V3_FACET_VERSION() external pure returns (string memory);

    function UNISWAP_V3_MAX_TICK_DELTA() external pure returns (uint24);

    function UNISWAP_V3_MIN_TICK() external pure returns (int24);

    function UNISWAP_V3_MAX_TICK() external pure returns (int24);

    function uniswapV3PositionManager() external view returns (address);

    function uniswapV3Router() external view returns (address);

    function setUniswapV3MaxSlippage(address pool, uint256 maxSlippage) external;

    function setUniswapV3PoolMaxTickDelta(address pool, uint24 maxTickDelta) external;

    function setUniswapV3AddLiquidityLowerTickBound(address pool, int24 lowerTickBound) external;

    function setUniswapV3AddLiquidityUpperTickBound(address pool, int24 upperTickBound) external;

    function setUniswapV3TWAPSecondsAgo(address pool, uint32 twapSecondsAgo) external;

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

    function getUniswapV3AggregateDepositRateLimitKey(address pool)
        external
        pure
        returns (bytes32 key);

    function getUniswapV3AssetDepositRateLimitKey(address pool, address token)
        external
        pure
        returns (bytes32 key);

    function getUniswapV3AddLiquidityTickBounds(address pool)
        external
        view
        returns (int24 lower, int24 upper);

    function getUniswapV3MaxSlippage(address pool) external view returns (uint256);

    function getUniswapV3PoolMaxTickDelta(address pool) external view returns (uint24);

    function getUniswapV3SwapRateLimitKey(address pool, address token)
        external
        pure
        returns (bytes32 key);

    function getUniswapV3TWAPSecondsAgo(address pool) external view returns (uint32);

    function getUniswapV3WithdrawRateLimitKey(address pool) external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** UniswapV4Facet actions                                                                 ***/
    /**********************************************************************************************/

    function UNISWAP_V4_FACET_VERSION() external pure returns (string memory);

    function uniswapV4Permit2() external view returns (address);

    function uniswapV4PositionManager() external view returns (address);

    function uniswapV4Router() external view returns (address);

    function setUniswapV4MaxSlippage(bytes32 poolId, uint256 maxSlippage) external;

    function setUniswapV4TickLimits(
        bytes32 poolId,
        int24   tickLowerMin,
        int24   tickUpperMax,
        uint24  maxTickSpacing
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

    function getUniswapV4AggregateDepositRateLimitKey(bytes32 poolId)
        external
        pure
        returns (bytes32 key);

    function getUniswapV4AssetDepositRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

    function uniswapV4MaxSlippages(bytes32 poolId) external view returns (uint256);

    function getUniswapV4SwapRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

    function uniswapV4TickLimits(bytes32 poolId)
        external
        view
        returns (int24 tickLowerMin, int24 tickUpperMax, uint24 maxTickSpacing);

    function getUniswapV4WithdrawRateLimitKey(bytes32 poolId) external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** EthenaFacet actions                                                                    ***/
    /**********************************************************************************************/

    function ETHENA_FACET_VERSION() external pure returns (string memory);

    function ethenaMinter() external view returns (address);

    function ethenaFacetSUSDE() external view returns (address);

    function ethenaFacetUSDC() external view returns (address);

    function ethenaFacetUSDE() external view returns (address);

    function setEthenaDelegatedSigner(address delegatedSigner) external;

    function removeEthenaDelegatedSigner(address delegatedSigner) external;

    function prepareUSDeMint(uint256 usdcAmount) external;

    function prepareUSDeBurn(uint256 usdeAmount) external;

    function cooldownAssetsSUSDe(uint256 usdeAmount) external returns (uint256 cooldownShares);

    function cooldownSharesSUSDe(uint256 susdeAmount) external returns (uint256 cooldownAssets);

    function unstakeSUSDe() external;

    function setEthenaDelegatedSignerRateLimitKey() external pure returns (bytes32 key);

    function removeEthenaDelegatedSignerRateLimitKey() external pure returns (bytes32 key);

    function usdeMintRateLimitKey() external pure returns (bytes32 key);

    function usdeBurnRateLimitKey() external pure returns (bytes32 key);

    function usdeCooldownRateLimitKey() external pure returns (bytes32 key);

    function usdeUnstakeRateLimitKey() external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** USDSFacet actions                                                                      ***/
    /**********************************************************************************************/

    function USDS_FACET_VERSION() external pure returns (string memory);

    function usdsFacetUSDS() external view returns (address);

    function setUSDSVault(address vault) external;

    function mintUSDS(uint256 usdsAmount) external;

    function burnUSDS(uint256 usdsAmount) external;

    function usdsVault() external view returns (address);

    function usdsMintRateLimitKey() external pure returns (bytes32 key);

    function usdsBurnRateLimitKey() external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** WEETHFacet actions                                                                     ***/
    /**********************************************************************************************/

    function WEETH_FACET_VERSION() external pure returns (string memory);

    function weethFacetWEETH() external view returns (address);

    function weethFacetWETH() external view returns (address);

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

    function getWEETHDepositRateLimitKey(address eeth, address liquidityPool)
        external
        pure
        returns (bytes32 key);

    function getWEETHRequestWithdrawRateLimitKey(
        address weethModule,
        address eeth,
        address liquidityPool
    )
        external
        pure
        returns (bytes32 key);

    function getWEETHClaimWithdrawRateLimitKey(address weethModule)
        external
        pure
        returns (bytes32 key);

    /**********************************************************************************************/
    /*** WrapProxyETHFacet actions                                                              ***/
    /**********************************************************************************************/

    function WRAP_PROXY_ETH_FACET_VERSION() external pure returns (string memory);

    function wrapAllProxyETH() external;

    function wrapProxyEthFacetWETH() external view returns (address);

    function wrapAllProxyETHRateLimitKey() external pure returns (bytes32 key);

    /**********************************************************************************************/
    /*** WSTETHFacet actions                                                                    ***/
    /**********************************************************************************************/

    function WSTETH_FACET_VERSION() external pure returns (string memory);

    function wstethFacetWSTETH() external view returns (address);

    function wstethFacetWETH() external view returns (address);

    function wstethWithdrawQueue() external view returns (address);

    function depositToWstETH(uint256 amount) external;

    function requestWithdrawFromWstETH(uint256 amountToRedeem)
        external
        returns (uint256[] memory requestIds);

    function claimWithdrawalFromWstETH(uint256 requestId) external;

    function wstethDepositRateLimitKey() external pure returns (bytes32 key);

    function wstethRequestWithdrawRateLimitKey() external pure returns (bytes32 key);

    function wstethClaimWithdrawRateLimitKey() external pure returns (bytes32 key);

}
