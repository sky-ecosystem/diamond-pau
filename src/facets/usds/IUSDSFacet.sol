// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IUSDSFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event USDSBurn(uint256 usdsAmount);

    event USDSMint(uint256 usdsAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Burns USDS.
     * @param usdsAmount Amount of USDS to burn.
     */
    function burn(uint256 usdsAmount) external;

    /**
     * @dev   Mints USDS.
     * @param usdsAmount Amount of USDS to mint.
     */
    function mint(uint256 usdsAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for mint operations.
     * @return bytes32 Key for mint limit.
     */
    function LIMIT_MINT() external pure returns (bytes32);

    /**
     * @dev    USDS contract address.
     * @return address USDS contract address.
     */
    function usds() external view returns (address);

    /**
     * @dev    Vault contract address.
     * @return address Vault contract address.
     */
    function vault() external view returns (address);

}
