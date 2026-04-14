// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }     from "../../libraries/ApproveLib.sol";
import { makeAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { FacetBase } from "../FacetBase.sol";

import { IAaveFacet } from "./IAaveFacet.sol";

interface IATokenWithPoolLike {

    function POOL() external view returns (address);

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

}

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

}

interface IPoolLike {

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16  referralCode,
        address onBehalfOf
    ) external;

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
        external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

}

contract AaveFacet is IAaveFacet, FacetBase {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.AaveFacet.v1
    struct FacetStorage {
        mapping (address aToken => uint256 maxSlippage) maxSlippages;  // 1e18 precision
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.AaveFacet.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant FACET_STORAGE_LOCATION =
        0x0d8c22a02210da5b8462182c9dc7f9ba6d9489bc70d480a9fc933c236c44b100;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant override LIMIT_BORROW   = keccak256("LIMIT_AAVE_BORROW");
    bytes32 public constant override LIMIT_DEPOSIT  = keccak256("LIMIT_AAVE_DEPOSIT");
    bytes32 public constant override LIMIT_REPAY    = keccak256("LIMIT_AAVE_REPAY");
    bytes32 public constant override LIMIT_WITHDRAW = keccak256("LIMIT_AAVE_WITHDRAW");

    uint256 internal constant VARIABLE_RATE_MODE = 2;

    string public constant override VERSION = "1.1.0";

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function setCollateral(address aToken, bool useAsCollateral)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(aToken != address(0), "AaveFacet/aToken-zero-address");

        IALMProxy(_getSharedControllerStorage().proxy).doCall(
            IATokenWithPoolLike(aToken).POOL(),
            abi.encodeCall(
                IPoolLike.setUserUseReserveAsCollateral,
                (IATokenWithPoolLike(aToken).UNDERLYING_ASSET_ADDRESS(), useAsCollateral)
            )
        );

        emit AaveCollateralSet(aToken, useAsCollateral);
    }

    function setMaxSlippage(address aToken, uint256 maxSlippage)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(aToken != address(0), "AaveFacet/aToken-zero-address");

        emit AaveMaxSlippageSet(aToken, _getFacetStorage().maxSlippages[aToken] = maxSlippage);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    function borrow(address aToken, uint256 amount, uint256 minHealthFactor)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        require(minHealthFactor >= 1e18, "AaveFacet/invalid-min-health-factor");

        _decreaseRateLimit(LIMIT_BORROW, aToken, amount);

        address proxy      = _getSharedControllerStorage().proxy;
        address pool       = IATokenWithPoolLike(aToken).POOL();
        address underlying = IATokenWithPoolLike(aToken).UNDERLYING_ASSET_ADDRESS();

        uint256 balanceBefore = IERC20Like(underlying).balanceOf(proxy);

        // Borrow underlying from Aave pool on behalf of the proxy.
        IALMProxy(proxy).doCall(
            pool,
            abi.encodeCall(IPoolLike.borrow,(underlying, amount, VARIABLE_RATE_MODE, 0, proxy))
        );

        uint256 received = IERC20Like(underlying).balanceOf(proxy) - balanceBefore;

        require(received >= amount, "AaveFacet/borrow-amount-too-low");

        ( , , , , , uint256 healthFactor ) = IPoolLike(pool).getUserAccountData(proxy);

        require(healthFactor >= minHealthFactor, "AaveFacet/health-factor-too-low");

        emit AaveBorrow(aToken, amount, healthFactor);
    }

    function deposit(address aToken, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        address proxy = _getSharedControllerStorage().proxy;

        _decreaseRateLimit(LIMIT_DEPOSIT, aToken, amount);

        uint256 maxSlippage = _getFacetStorage().maxSlippages[aToken];

        require(maxSlippage != 0, "AaveFacet/max-slippage-not-set");

        address underlying = IATokenWithPoolLike(aToken).UNDERLYING_ASSET_ADDRESS();
        address pool       = IATokenWithPoolLike(aToken).POOL();

        // Approve underlying to Aave pool from the proxy (assumes the proxy has enough underlying).
        ApproveLib.approve(underlying, proxy, pool, amount);

        uint256 aTokenBalance = IERC20Like(aToken).balanceOf(proxy);

        // Deposit underlying into Aave pool, proxy receives aTokens.
        IALMProxy(proxy).doCall(
            pool,
            abi.encodeCall(IPoolLike.supply, (underlying, amount, proxy, 0))
        );

        uint256 newATokens = IERC20Like(aToken).balanceOf(proxy) - aTokenBalance;

        require(newATokens >= amount * maxSlippage / 1e18, "AaveFacet/slippage-too-high");

        emit AaveDeposit(aToken, amount);
    }

    function repay(address aToken, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 amountRepaid)
    {
        address proxy      = _getSharedControllerStorage().proxy;
        address underlying = IATokenWithPoolLike(aToken).UNDERLYING_ASSET_ADDRESS();
        address pool       = IATokenWithPoolLike(aToken).POOL();

        // Approve underlying to Aave pool from the proxy.
        // NOTE: If `amount` is `type(uint256).max` for full repayment,
        //       this will approve unlimited `underlying` tokens.
        ApproveLib.approve(underlying, proxy, pool, amount);

        // Repay debt on behalf of the proxy, decode actual amount repaid.
        amountRepaid = abi.decode(
            IALMProxy(proxy).doCall(
                pool,
                abi.encodeCall(IPoolLike.repay, (underlying, amount, VARIABLE_RATE_MODE, proxy))
            ),
            (uint256)
        );

        require(amountRepaid <= amount, "AaveFacet/repay-amount-too-high");

        _decreaseRateLimit(LIMIT_REPAY,  aToken, amountRepaid);
        _increaseRateLimit(LIMIT_BORROW, aToken, amountRepaid);

        emit AaveRepay(aToken, amountRepaid);
    }

    function withdraw(address aToken, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 amountWithdrawn)
    {
        address proxy = _getSharedControllerStorage().proxy;

        // Withdraw underlying from Aave pool, decode resulting amount withdrawn.
        // Assumes proxy has adequate aTokens.
        amountWithdrawn = abi.decode(
            IALMProxy(proxy).doCall(
                IATokenWithPoolLike(aToken).POOL(),
                abi.encodeCall(
                    IPoolLike.withdraw,
                    (IATokenWithPoolLike(aToken).UNDERLYING_ASSET_ADDRESS(), amount, proxy)
                )
            ),
            (uint256)
        );

        _decreaseRateLimit(LIMIT_WITHDRAW, aToken, amountWithdrawn);
        _increaseRateLimit(LIMIT_DEPOSIT,  aToken, amountWithdrawn);

        emit AaveWithdraw(aToken, amountWithdrawn);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function getMaxSlippage(address aToken) external view override returns (uint256) {
        return _getFacetStorage().maxSlippages[aToken];
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _decreaseRateLimit(bytes32 key, address aToken, uint256 amount) internal {
        IRateLimits(_getSharedControllerStorage().rateLimits).triggerRateLimitDecrease(
            makeAddressKey(key, aToken),
            amount
        );
    }

    function _increaseRateLimit(bytes32 key, address aToken, uint256 amount) internal {
        IRateLimits(_getSharedControllerStorage().rateLimits).triggerRateLimitIncrease(
            makeAddressKey(key, aToken),
            amount
        );
    }

}
