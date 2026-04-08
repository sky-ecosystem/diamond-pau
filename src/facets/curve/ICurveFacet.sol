// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface ICurveFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event CurveAddLiquidity(
        address indexed pool,
        uint256         shares,
        uint256         valueDeposited,
        uint256[]       depositAmounts
    );

    /**
     * @dev   Event emitted when max slippage is set.
     * @param pool        Pool address.
     * @param maxSlippage Max slippage allowed.
     */
    event CurveMaxSlippageSet(address indexed pool, uint256 maxSlippage);

    event CurveRemoveLiquidity(
        address indexed pool,
        uint256         lpBurnAmount,
        uint256         valueWithdrawn,
        uint256[]       withdrawnTokens
    );

    event CurveSwap(
        address indexed pool,
        uint256 indexed inputIndex,
        uint256 indexed outputIndex,
        uint256         amountIn,
        uint256         amountOut
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev    Adds liquidity to a pool.
     * @param  pool           Pool address.
     * @param  depositAmounts Amounts of tokens to deposit.
     * @param  minLpAmount    Minimum amount of LP tokens to receive.
     * @return shares         Amount of LP tokens received.
     */
    function addLiquidity(address pool, uint256[] calldata depositAmounts, uint256 minLpAmount)
        external
        returns (uint256 shares);

    /**
     * @dev    Removes liquidity from a pool.
     * @param  pool               Pool address.
     * @param  lpBurnAmount       Amount of LP tokens to burn.
     * @param  minWithdrawAmounts Minimum amounts of tokens to withdraw.
     * @return withdrawnTokens    Amounts of tokens withdrawn.
     */
    function removeLiquidity(
        address            pool,
        uint256            lpBurnAmount,
        uint256[] calldata minWithdrawAmounts
    )
        external
        returns (uint256[] memory withdrawnTokens);

    /**
     * @dev   Sets max slippage for a pool.
     * @param pool        Pool address.
     * @param maxSlippage Max slippage allowed.
     */
    function setMaxSlippage(address pool, uint256 maxSlippage) external;

    /**
     * @dev    Swaps tokens in a pool.
     * @param  pool         Pool address.
     * @param  inputIndex   Index of the input token.
     * @param  outputIndex  Index of the output token.
     * @param  amountIn     Amount of input tokens to swap.
     * @param  minAmountOut Minimum amount of output tokens to receive.
     * @return amountOut    Amount of output tokens received.
     */
    function swap(
        address pool,
        uint256 inputIndex,
        uint256 outputIndex,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        returns (uint256 amountOut);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for deposit operations.
     * @return bytes32 Key for deposit limit.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Limit for swap operations.
     * @return bytes32 Key for swap limit.
     */
    function LIMIT_SWAP() external pure returns (bytes32);

    /**
     * @dev    Limit for withdraw operations.
     * @return bytes32 Key for withdraw limit.
     */
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Gets max slippage for a pool.
     * @param  pool        Pool address.
     * @return maxSlippage Max slippage allowed.
     */
    function getMaxSlippage(address pool) external view returns (uint256);

}
