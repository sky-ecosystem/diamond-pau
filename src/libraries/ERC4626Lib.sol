// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IALMProxy }     from "../interfaces/IALMProxy.sol";
import { IERC4626Facet } from "../interfaces/facets/IERC4626Facet.sol";
import { IParameters }   from "../interfaces/IParameters.sol";
import { IRateLimits }   from "../interfaces/IRateLimits.sol";

import { ApproveLib }                                  from "./ApproveLib.sol";
import { FacetBase }                                   from "./FacetBase.sol";
import { addressToKeyComponent, combineKeyComponents } from "../ParameterKeys.sol";
import { ParameterHelpers }                            from "../ParameterHelpers.sol";
import { makeAddressKey }                              from "../RateLimitHelpers.sol";

interface IERC4626Like {

    function deposit(uint256 amount, address receiver) external returns (uint256 shares);

    function withdraw(uint256 assets, address receiver, address owner)
        external
        returns (uint256 shares);

    function redeem(uint256 shares, address receiver, address owner)
        external
        returns (uint256 assets);

    function asset() external view returns (address);

}

contract ERC4626Facet is IERC4626Facet, FacetBase {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    string public constant DOMAIN                   = "sky.pau.erc4626";
    string public constant MAX_EXCHANGE_RATE_PREFIX = "maxExchangeRate";

    bytes32 public constant LIMIT_DEPOSIT  = keccak256("LIMIT_4626_DEPOSIT");
    bytes32 public constant LIMIT_WITHDRAW = keccak256("LIMIT_4626_WITHDRAW");

    uint256 public constant EXCHANGE_RATE_PRECISION = 1e36;

    /**********************************************************************************************/
    /*** External interactive functions                                                         ***/
    /**********************************************************************************************/

    function setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(token != address(0), "ERC4626Facet/token-zero-address");

        uint256 exchangeRate = _getExchangeRate(shares, maxExpectedAssets);

        IParameters(_getControllerStorage().parameters).set(
            _getMaxExchangeRateKey(token),
            ParameterHelpers.fromUint256(exchangeRate)
        );

        emit MaxExchangeRateSet(token, exchangeRate);
    }

    function deposit(address token, uint256 amount, uint256 minSharesOut)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 shares)
    {
        ControllerStorage storage $ = _getControllerStorage();

        _decreaseRateLimit($.rateLimits, LIMIT_DEPOSIT, token, amount);

        // Approve asset to token from the proxy (assumes the proxy has enough of the asset).
        ApproveLib.approve(IERC4626Like(token).asset(), $.proxy, token, amount);

        // Deposit asset into the token, proxy receives token shares, decode the resulting shares.
        shares = abi.decode(
            IALMProxy($.proxy).doCall(
                token,
                abi.encodeCall(IERC4626Like.deposit, (amount, $.proxy))
            ),
            (uint256)
        );

        require(shares >= minSharesOut, "ERC4626Facet/min-shares-out-not-met");

        uint256 maxExchangeRate = ParameterHelpers.toUint256(
            IParameters($.parameters).get(_getMaxExchangeRateKey(token))
        );

        require(
            _getExchangeRate(shares, amount) <= maxExchangeRate,
            "ERC4626Facet/exchange-rate-too-high"
        );
    }

    function withdraw(address token, uint256 amount, uint256 maxSharesIn)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 shares)
    {
        ControllerStorage storage $ = _getControllerStorage();

        _decreaseRateLimit($.rateLimits, LIMIT_WITHDRAW, token, amount);

        // Withdraw asset from a token, decode resulting shares.
        // Assumes proxy has adequate token shares.
        shares = abi.decode(
            IALMProxy($.proxy).doCall(
                token,
                abi.encodeCall(IERC4626Like.withdraw, (amount, $.proxy, $.proxy))
            ),
            (uint256)
        );

        require(shares <= maxSharesIn, "ERC4626Facet/shares-burned-too-high");

        _increaseRateLimit($.rateLimits, LIMIT_DEPOSIT, token, amount);
    }

    function redeem(address token, uint256 shares, uint256 minAssetsOut)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 assets)
    {
        ControllerStorage storage $ = _getControllerStorage();

        // Redeem shares for assets from the token, decode the resulting assets.
        // Assumes proxy has adequate token shares.
        assets = abi.decode(
            IALMProxy($.proxy).doCall(
                token,
                abi.encodeCall(IERC4626Like.redeem, (shares, $.proxy, $.proxy))
            ),
            (uint256)
        );

        require(assets >= minAssetsOut, "ERC4626Facet/min-assets-out-not-met");

        _decreaseRateLimit($.rateLimits, LIMIT_WITHDRAW, token, assets);
        _increaseRateLimit($.rateLimits, LIMIT_DEPOSIT,  token, assets);
    }

    /**********************************************************************************************/
    /*** External view/pure functions                                                           ***/
    /**********************************************************************************************/

    function maxExchangeRates(address token) external view returns (uint256) {
        return ParameterHelpers.toUint256(
            IParameters(_getControllerStorage().parameters).get(_getMaxExchangeRateKey(token))
        );
    }

    /**********************************************************************************************/
    /*** Internal interactive functions                                                         ***/
    /**********************************************************************************************/

    function _decreaseRateLimit(address rateLimits, bytes32 key, address token, uint256 amount)
        internal
    {
        IRateLimits(rateLimits).triggerRateLimitDecrease(makeAddressKey(key, token), amount);
    }

    function _increaseRateLimit(address rateLimits, bytes32 key, address token, uint256 amount)
        internal
    {
        IRateLimits(rateLimits).triggerRateLimitIncrease(makeAddressKey(key, token), amount);
    }

    /**********************************************************************************************/
    /*** Internal View/Pure functions                                                           ***/
    /**********************************************************************************************/

    function _getExchangeRate(uint256 shares, uint256 assets) internal pure returns (uint256) {
        // Return 0 for zero assets first, to handle the valid case of 0 shares and 0 assets.
        if (assets == 0) return 0;

        // Zero shares with non-zero assets is invalid (infinite exchange rate).
        require(shares > 0, "ERC4626Facet/zero-shares");

        return (EXCHANGE_RATE_PRECISION * assets) / shares;
    }

    function _getMaxExchangeRateKey(address token) internal pure returns (string memory) {
        return combineKeyComponents(
            combineKeyComponents(DOMAIN, MAX_EXCHANGE_RATE_PREFIX),
            addressToKeyComponent(token)
        );
    }

}
