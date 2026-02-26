// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC7540 } from "../../lib/forge-std/src/interfaces/IERC7540.sol";

import { IERC20 }   from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import { ERC20Lib } from "./ERC20Lib.sol";

import { IALMProxy }   from "../interfaces/IALMProxy.sol";
import { IRateLimits } from "../interfaces/IRateLimits.sol";

import { makeAddressKey } from "../RateLimitHelpers.sol";

import { ApproveLib } from "./ApproveLib.sol";

library ERC7540Lib {

    bytes32 public constant LIMIT_7540_DEPOSIT = keccak256("LIMIT_7540_DEPOSIT");
    bytes32 public constant LIMIT_7540_REDEEM  = keccak256("LIMIT_7540_REDEEM");

    function deposit(
        address proxy,
        address rateLimits,
        address token,
        uint256 amount
    )
        external
    {
        IRateLimits(rateLimits).triggerRateLimitDecrease(
            makeAddressKey(LIMIT_7540_DEPOSIT, token),
            amount
        );

        // Note that whitelist is done by rate limits
        IERC20 asset = IERC20(IERC7540(token).asset());

        // Approve asset to vault from the proxy (assumes the proxy has enough of the asset).
        ERC20Lib.approve(IALMProxy(proxy), address(asset), token, amount);

        // Submit deposit request by transferring assets
        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(
                IERC7540(token).requestDeposit,
                (
                    amount,
                    address(proxy),
                    address(proxy)
                )
            )
        );
    }

    function claimDeposit(
        address proxy,
        address rateLimits,
        address token
    )
        external
    {
        _rateLimitExists(rateLimits, makeAddressKey(LIMIT_7540_DEPOSIT, token));

        uint256 shares = IERC7540(token).maxMint(address(proxy));

        // Claim shares from the vault to the proxy
        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(IERC4626(token).mint, (shares, address(proxy)))
        );
    }

    function requestRedeem(
        address proxy,
        address rateLimits,
        address token,
        uint256 shares
    )
        external
    {
        IRateLimits(rateLimits).triggerRateLimitDecrease(
            makeAddressKey(LIMIT_7540_REDEEM, token),
            IERC7540(token).convertToAssets(shares)
        );

        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(
                IERC7540(token).requestRedeem,
                (shares, address(proxy), address(proxy))
            )
        );
    }

    function claimRedeem(
        address proxy,
        address rateLimits,
        address token
    )
        external
    {
         _rateLimitExists(rateLimits, makeAddressKey(LIMIT_7540_REDEEM, token));

        uint256 assets = IERC7540(token).maxWithdraw(address(proxy));

        // Claim assets from the vault to the proxy
        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(
                IERC7540(token).withdraw,
                (assets, address(proxy), address(proxy))
            )
        );
    }

    function _rateLimitExists(address rateLimits, bytes32 key) internal view {
        require(
            IRateLimits(rateLimits).getRateLimitData(key).maxAmount > 0,
            "MC/invalid-action"
        );
    }

}
