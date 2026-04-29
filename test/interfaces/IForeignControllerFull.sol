// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IController }     from "../../src/interfaces/IController.sol";
import { IRateLimits }     from "../../src/interfaces/IRateLimits.sol";
import { IUniswapV3Facet } from "../../src/facets/uniswap-v3/IUniswapV3Facet.sol";

interface IForeignControllerFull is IController {

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
    /*** LayerZeroFacet actions                                                                 ***/
    /**********************************************************************************************/

    function setLayerZeroRecipient(uint32 destinationEndpointId, bytes32 recipient)
        external;

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
    /*** MerklFacet actions                                                                     ***/
    /**********************************************************************************************/

    function setMerklDistributor(address distributor) external;

    function toggleOperatorMerkl(address operator) external;

    function merklDistributor() external view returns (address);

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
    /*** PSM3Facet actions                                                                      ***/
    /**********************************************************************************************/

    function setPSMDepositRateLimit(
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function setPSMWithdrawRateLimit(
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    function depositPSM(address asset, uint256 amount) external returns (uint256 shares);

    function withdrawPSM(address asset, uint256 maxAmount)
        external
        returns (uint256 assetsWithdrawn);

    function LIMIT_PSM_DEPOSIT() external pure returns (bytes32);

    function LIMIT_PSM_WITHDRAW() external pure returns (bytes32);

    function getPSMDepositRateLimit(address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory);

    function getPSMWithdrawRateLimit(address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory);

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

}
