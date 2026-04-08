// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IUSDEFacet
 * @notice DiamondPAU facet for interacting with Ethena's USDe ecosystem.
 *         Supports minting/burning USDe via the Ethena minter, staking/unstaking
 *         sUSDe, and managing the sUSDe cooldown process.
 */
interface IUSDEFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when a USDe cooldown is initiated by asset amount.
     * @param usdeAmount Amount of USDe queued for cooldown.
     * @param shares     Amount of sUSDe shares locked.
     */
    event USDECooldownAssets(uint256 usdeAmount, uint256 shares);

    /**
     * @dev   Emitted when a USDe cooldown is initiated by share amount.
     * @param susdeAmount Amount of sUSDe shares queued for cooldown.
     * @param assets      Amount of USDe assets that will be received.
     */
    event USDECooldownShares(uint256 susdeAmount, uint256 assets);

    /**
     * @dev   Emitted when a USDe burn is prepared by approving USDe to the Ethena minter.
     * @param usdeAmount Amount of USDe approved for burning.
     */
    event USDEPrepareBurn(uint256 usdeAmount);

    /**
     * @dev   Emitted when a USDe mint is prepared by approving USDC to the Ethena minter.
     * @param usdcAmount Amount of USDC approved for minting (6-decimal precision).
     */
    event USDEPrepareMint(uint256 usdcAmount);

    /**
     * @dev   Emitted when a delegated signer is removed from the Ethena minter.
     * @param delegatedSigner Address of the removed delegated signer.
     */
    event USDERemoveDelegatedSigner(address indexed delegatedSigner);

    /**
     * @dev   Emitted when a delegated signer is set on the Ethena minter.
     * @param delegatedSigner Address of the delegated signer.
     */
    event USDESetDelegatedSigner(address indexed delegatedSigner);

    /**
     * @dev   Emitted when sUSDe is unstaked after the cooldown period.
     * @param assets Amount of USDe assets received from unstaking.
     */
    event USDEUnstakeSUSDE(uint256 assets);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev    Initiates sUSDe cooldown by specifying a USDe asset amount.
     * @param  usdeAmount Amount of USDe to cooldown.
     * @return shares     Amount of sUSDe shares locked in cooldown.
     */
    function cooldownAssets(uint256 usdeAmount) external returns (uint256 shares);

    /**
     * @dev    Initiates sUSDe cooldown by specifying a share amount.
     * @param  susdeAmount Amount of sUSDe shares to cooldown.
     * @return assets      Amount of USDe assets queued for withdrawal.
     */
    function cooldownShares(uint256 susdeAmount) external returns (uint256 assets);

    /**
     * @dev   Prepares a USDe burn by approving USDe to the Ethena minter.
     *        The actual burn is executed off-chain by the delegated signer.
     * @param usdeAmount Amount of USDe to approve for burning.
     */
    function prepareBurn(uint256 usdeAmount) external;

    /**
     * @dev   Prepares a USDe mint by approving USDC to the Ethena minter.
     *        The actual mint is executed off-chain by the delegated signer.
     * @param usdcAmount Amount of USDC to approve for minting (6-decimal precision).
     */
    function prepareMint(uint256 usdcAmount) external;

    /**
     * @dev   Removes a delegated signer from the Ethena minter for the proxy.
     * @param delegatedSigner Address of the delegated signer to remove.
     */
    function removeDelegatedSigner(address delegatedSigner) external;

    /**
     * @dev   Sets a delegated signer on the Ethena minter for the proxy.
     * @param delegatedSigner Address of the delegated signer to set.
     */
    function setDelegatedSigner(address delegatedSigner) external;

    /**
     * @dev Unstakes sUSDe after the cooldown period, receiving USDe.
     */
    function unstakeSUSDE() external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for USDe burn operations.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_USDE_BURN() external view returns (bytes32);

    /**
     * @dev    Rate limit key for USDe mint operations.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_USDE_MINT() external view returns (bytes32);

    /**
     * @dev    Rate limit key for sUSDe cooldown operations.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_SUSDE_COOLDOWN() external view returns (bytes32);

    /**
     * @dev    Address of the Ethena minter contract (immutable).
     * @return address The Ethena minter contract address.
     */
    function ethenaMinter() external view returns (address);

    /**
     * @dev    Address of the sUSDe (staked USDe) token contract (immutable).
     * @return address The sUSDe contract address.
     */
    function susde() external view returns (address);

    /**
     * @dev    Address of the USDC token contract (immutable).
     * @return address The USDC contract address.
     */
    function usdc() external view returns (address);

    /**
     * @dev    Address of the USDe token contract (immutable).
     * @return address The USDe contract address.
     */
    function usde() external view returns (address);

}
