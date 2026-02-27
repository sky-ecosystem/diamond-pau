// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IALMProxy }   from "../interfaces/IALMProxy.sol";
import { IRateLimits } from "../interfaces/IRateLimits.sol";

import { RateLimitHelpers } from "../RateLimitHelpers.sol";

import { ApproveLib }  from "./ApproveLib.sol";

interface IPendleRouterLike {

    function redeemPyToToken(
        address                        receiver,
        address                        YT,
        uint256                        netPyIn,
        PendleLib.TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyInterm);

}

interface IPendleMarket {

    function readTokens() external view returns (address _SY, address _PT, address _YT);

    function isExpired() external view returns (bool);

    function expiry() external view returns (uint256);

}

interface ISY {

    function yieldToken() external view returns (address);

}

interface IYT {

    function pyIndexCurrent() external returns (uint256);

}

library PendleLib {

    enum SwapType {
        NONE,
        KYBERSWAP,
        ODOS,
        // ETH_WETH not used in Aggregator
        ETH_WETH,
        OKX,
        ONE_INCH,
        PARASWAP,
        RESERVE_2,
        RESERVE_3,
        RESERVE_4,
        RESERVE_5
    }

    struct SwapData {
        SwapType swapType;
        address  extRouter;
        bytes    extCalldata;
        bool     needScale;
    }

    struct TokenOutput {
        address  tokenOut;
        uint256  minTokenOut;
        address  tokenRedeemSy;
        address  pendleSwap;
        SwapData swapData;
    }

    bytes32 public constant LIMIT_REDEEM = keccak256("LIMIT_PENDLE_PT_REDEEM");

    struct RedeemPendlePTParams {
        address proxy;
        address rateLimits;
        address pendleMarket;
        address pendleRouter;
        uint256 pyAmountIn;
        uint256 minAmountOut;
    }

    function createEmptySwapData() internal pure returns (SwapData memory emptySwapData) {}

    function createSimpleTokenOutput(address tokenOut, uint256 minTokenOut) internal pure returns (TokenOutput memory simpleTokenOutput) {
        simpleTokenOutput = TokenOutput({
            tokenOut      : tokenOut,
            minTokenOut   : minTokenOut,
            tokenRedeemSy : tokenOut,
            pendleSwap    : address(0),
            swapData      : createEmptySwapData()
        });
    }

    // NOTE: DO NOT use for markets with non-standard SYs, without additional testing
    //       targeting each onboarded non-standard SY market.
    //       (Non-standard SYs: ePENDLE, mPENDLE, aTokens (aUSDC, aUSDT))
    function redeemPendlePT(RedeemPendlePTParams memory params) external {
        require(params.pendleRouter != address(0),              "PendleLib/pendle-router-not-set");
        require(IPendleMarket(params.pendleMarket).isExpired(), "PendleLib/market-not-expired");
        require(params.minAmountOut != 0,                       "PendleLib/min-amount-out-not-set");

        ( address sy, address pt, address yt ) = IPendleMarket(params.pendleMarket).readTokens();

        address tokenOut = ISY(sy).yieldToken();

        uint256 pyIndexCurrent = IYT(yt).pyIndexCurrent();

        // expected to receive full amount, but the buffer is subtracted
        // to avoid reverts due to potential rounding errors
        uint256 minTokenOut = params.pyAmountIn * 1e18 / pyIndexCurrent - 5;

        ApproveLib.approve(pt, params.proxy, params.pendleRouter, params.pyAmountIn);

        uint256 tokenOutAmountBefore = IERC20(tokenOut).balanceOf(address(params.proxy));

        IALMProxy(params.proxy).doCall(
            params.pendleRouter,
            abi.encodeCall(
                IPendleRouterLike.redeemPyToToken, (
                    params.proxy,
                    yt,
                    params.pyAmountIn,
                    createSimpleTokenOutput(tokenOut, minTokenOut)
                )
            )
        );

        uint256 totalTokenOutAmount = IERC20(tokenOut).balanceOf(params.proxy) - tokenOutAmountBefore;

        require(totalTokenOutAmount >= params.minAmountOut, "PendleLib/min-amount-not-met");

        IRateLimits(params.rateLimits).triggerRateLimitDecrease(
            RateLimitHelpers.makeAddressKey(LIMIT_REDEEM, params.pendleMarket),
            totalTokenOutAmount
        );

    }

}
