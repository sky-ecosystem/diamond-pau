// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IUSDEFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when assets are cooled down.
     * @param usdeAmount Amount of USDE cooled down.
     * @param shares     Amount of shares received.
     */
    event USDECooldownAssets(uint256 usdeAmount, uint256 shares);

    /**
     * @dev   Event emitted when shares are cooled down.
     * @param susdeAmount Amount of SUSDE cooled down.
     * @param assets      Amount of assets received.
     */
    event USDECooldownShares(uint256 susdeAmount, uint256 assets);

    /**
     * @dev   Event emitted when a USDE burn is prepared.
     * @param usdeAmount Amount of USDE to burn.
     */
    event USDEPrepareBurn(uint256 usdeAmount);

    /**
     * @dev   Event emitted when a USDE mint is prepared.
     * @param usdcAmount Amount of USDC to mint.
     */
    event USDEPrepareMint(uint256 usdcAmount);

    /**
     * @dev   Event emitted when a delegated signer is removed.
     * @param delegatedSigner Delegated signer address.
     */
    event USDERemoveDelegatedSigner(address indexed delegatedSigner);

    /**
     * @dev   Event emitted when a delegated signer is set.
     * @param delegatedSigner Delegated signer address.
     */
    event USDESetDelegatedSigner(address indexed delegatedSigner);

    /**
     * @dev   Event emitted when SUSDE is unstaked.
     * @param assets Amount of assets unstaked.
     */
    event USDEUnstakeSUSDE(uint256 assets);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev    Cooldowns assets.
     * @param  usdeAmount Amount of USDE to cooldown.
     * @return shares     Amount of shares received.
     */
    function cooldownAssets(uint256 usdeAmount) external returns (uint256 shares);

    /**
     * @dev    Cooldowns shares.
     * @param  susdeAmount Amount of SUSDE to cooldown.
     * @return assets      Amount of assets received.
     */
    function cooldownShares(uint256 susdeAmount) external returns (uint256 assets);

    /**
     * @dev   Prepares to burn USDE.
     * @param usdeAmount Amount of USDE to burn.
     */
    function prepareBurn(uint256 usdeAmount) external;

    /**
     * @dev   Prepares to mint USDE.
     * @param usdcAmount Amount of USDC to mint.
     */
    function prepareMint(uint256 usdcAmount) external;

    /**
     * @dev   Removes a delegated signer.
     * @param delegatedSigner Delegated signer address.
     */
    function removeDelegatedSigner(address delegatedSigner) external;

    /**
     * @dev   Sets a delegated signer.
     * @param delegatedSigner Delegated signer address.
     */
    function setDelegatedSigner(address delegatedSigner) external;

    /**
     * @dev Unstakes SUSDE.
     */
    function unstakeSUSDE() external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for USDE burn operations.
     * @return bytes32 Key for USDE burn limit.
     */
    function LIMIT_USDE_BURN() external view returns (bytes32);

    /**
     * @dev    Limit for USDE mint operations.
     * @return bytes32 Key for USDE mint limit.
     */
    function LIMIT_USDE_MINT() external view returns (bytes32);

    /**
     * @dev    Limit for SUSDE cooldown operations.
     * @return bytes32 Key for SUSDE cooldown limit.
     */
    function LIMIT_SUSDE_COOLDOWN() external view returns (bytes32);

    /**
     * @dev    Ethena minter address.
     * @return address Ethena minter address.
     */
    function ethenaMinter() external view returns (address);

    /**
     * @dev    SUSDE contract address.
     * @return address SUSDE contract address.
     */
    function susde() external view returns (address);

    /**
     * @dev    USDC contract address.
     * @return address USDC contract address.
     */
    function usdc() external view returns (address);

    /**
     * @dev    USDE contract address.
     * @return address USDE contract address.
     */
    function usde() external view returns (address);

}
