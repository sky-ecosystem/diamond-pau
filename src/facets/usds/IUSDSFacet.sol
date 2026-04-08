// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IUSDSFacet
 * @notice DiamondPAU facet for minting and burning USDS via the Sky Allocation Vault.
 *         Mint draws USDS from the vault's buffer to the proxy.
 *         Burn sends USDS back to the buffer and wipes the debt.
 */
interface IUSDSFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when USDS is burned (wiped) back to the vault.
     * @param usdsAmount Amount of USDS burned (18-decimal precision).
     */
    event USDSBurn(uint256 usdsAmount);

    /**
     * @dev   Emitted when USDS is minted (drawn) from the vault.
     * @param usdsAmount Amount of USDS minted (18-decimal precision).
     */
    event USDSMint(uint256 usdsAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Burns USDS by transferring it to the vault buffer and wiping debt.
     * @param usdsAmount Amount of USDS to burn (18-decimal precision).
     */
    function burn(uint256 usdsAmount) external;

    /**
     * @dev   Mints USDS by drawing from the vault and transferring from the buffer to the proxy.
     * @param usdsAmount Amount of USDS to mint (18-decimal precision).
     */
    function mint(uint256 usdsAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for USDS mint operations. Decreased on mint, increased on burn.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_MINT() external pure returns (bytes32);

    /**
     * @dev    Address of the USDS token contract (immutable).
     * @return address The USDS contract address.
     */
    function usds() external view returns (address);

    /**
     * @dev    Address of the Sky Allocation Vault contract (immutable).
     * @return address The vault contract address.
     */
    function vault() external view returns (address);

}
