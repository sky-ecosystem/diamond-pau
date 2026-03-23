// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IALMProxy }    from "../interfaces/IALMProxy.sol";
import { IAaveFacet }   from "../interfaces/facets/IAaveFacet.sol";
import { IParameters }  from "../interfaces/IParameters.sol";
import { IRateLimits }  from "../interfaces/IRateLimits.sol";

import { ApproveLib }                                  from "./ApproveLib.sol";
import { FacetBase }                                   from "./FacetBase.sol";
import { addressToKeyComponent, combineKeyComponents } from "../ParameterKeys.sol";
import { ParameterHelpers }                            from "../ParameterHelpers.sol";
import { makeAddressKey }                              from "../RateLimitHelpers.sol";

interface IATokenWithPoolLike {

    function POOL() external view returns(address);

    function UNDERLYING_ASSET_ADDRESS() external view returns(address);

}

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

}

interface IPoolLike {

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16  referralCode
    )
        external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

}

contract AaveFacet is IAaveFacet, FacetBase {

    string public constant DOMAIN              = "sky.pau.aave";
    string public constant MAX_SLIPPAGE_PREFIX = "maxSlippage";

    bytes32 public constant LIMIT_DEPOSIT  = keccak256("LIMIT_AAVE_DEPOSIT");
    bytes32 public constant LIMIT_WITHDRAW = keccak256("LIMIT_AAVE_WITHDRAW");

    function setMaxSlippage(address aToken, uint256 maxSlippage)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(aToken != address(0), "AaveFacet/aToken-zero-address");

        IParameters(_getControllerStorage().parameters).set(
            _getMaxSlippageKey(aToken),
            ParameterHelpers.fromUint256(maxSlippage)
        );

        emit MaxSlippageSet(aToken, maxSlippage);
    }

    function deposit(
        address aToken,
        uint256 amount
    )
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        ControllerStorage storage $ = _getControllerStorage();

        _decreaseRateLimit($.rateLimits, LIMIT_DEPOSIT, aToken, amount);

        uint256 maxSlippage = ParameterHelpers.toUint256(
            IParameters($.parameters).get(_getMaxSlippageKey(aToken))
        );

        require(maxSlippage != 0, "AaveFacet/max-slippage-not-set");

        address underlying = IATokenWithPoolLike(aToken).UNDERLYING_ASSET_ADDRESS();
        address pool       = IATokenWithPoolLike(aToken).POOL();

        // Approve underlying to Aave pool from the proxy (assumes the proxy has enough underlying).
        ApproveLib.approve(underlying, $.proxy, pool, amount);

        uint256 aTokenBalance = IERC20Like(aToken).balanceOf($.proxy);

        // Deposit underlying into Aave pool, proxy receives aTokens
        IALMProxy($.proxy).doCall(
            pool,
            abi.encodeCall(IPoolLike.supply, (underlying, amount, $.proxy, 0))
        );

        uint256 newATokens = IERC20Like(aToken).balanceOf($.proxy) - aTokenBalance;

        require(newATokens >= amount * maxSlippage / 1e18, "AaveFacet/slippage-too-high");
    }

    function withdraw(address aToken, uint256 amount)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 amountWithdrawn)
    {
        ControllerStorage storage $ = _getControllerStorage();

        address pool = IATokenWithPoolLike(aToken).POOL();

        // Withdraw underlying from Aave pool, decode resulting amount withdrawn.
        // Assumes proxy has adequate aTokens.
        amountWithdrawn = abi.decode(
            IALMProxy($.proxy).doCall(
                pool,
                abi.encodeCall(
                    IPoolLike.withdraw,
                    (IATokenWithPoolLike(aToken).UNDERLYING_ASSET_ADDRESS(), amount, $.proxy)
                )
            ),
            (uint256)
        );

        _decreaseRateLimit($.rateLimits, LIMIT_WITHDRAW, aToken, amountWithdrawn);
        _increaseRateLimit($.rateLimits, LIMIT_DEPOSIT,  aToken, amountWithdrawn);
    }

    function maxSlippages(address aToken) external view returns (uint256) {
        return ParameterHelpers.toUint256(
            IParameters(_getControllerStorage().parameters).get(_getMaxSlippageKey(aToken))
        );
    }

    function _getMaxSlippageKey(address aToken) internal pure returns (string memory) {
        return combineKeyComponents(
            combineKeyComponents(DOMAIN, MAX_SLIPPAGE_PREFIX),
            addressToKeyComponent(aToken)
        );
    }

    function _decreaseRateLimit(address rateLimits, bytes32 key, address aToken, uint256 amount)
        internal
    {
        IRateLimits(rateLimits).triggerRateLimitDecrease(makeAddressKey(key, aToken), amount);
    }

    function _increaseRateLimit(address rateLimits, bytes32 key, address aToken, uint256 amount)
        internal
    {
        IRateLimits(rateLimits).triggerRateLimitIncrease(makeAddressKey(key, aToken), amount);
    }

}
