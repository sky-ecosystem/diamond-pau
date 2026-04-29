// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IUSDSFacet
 * @notice PAU facet for minting and burning USDS via the Sky Allocation Vault. Mint draws USDS from
 *         the vault's buffer to the proxy. Burn sends USDS back to the buffer and wipes the debt.
 */
interface IUSDSFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when USDS is burned (wiped) back to the vault.
     * @param  usdsAmount Amount of USDS burned (18-decimal precision).
     */
    event USDSBurn(uint256 usdsAmount);

    /**
     * @notice Emitted when USDS is minted (drawn) from the vault.
     * @param  usdsAmount Amount of USDS minted (18-decimal precision).
     */
    event USDSMint(uint256 usdsAmount);

    /**
     * @notice Emitted when the USDS mint rate limit is updated.
     * @param  key Derived key of the rate limit.
     */
    event USDSMintRateLimitSet(bytes32 indexed key);

    /**
     * @notice Emitted when the vault contract is set.
     * @param  vault Address of the vault contract.
     */
    event USDSVaultSet(address indexed vault);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Burns USDS by transferring it to the vault buffer and wiping debt.
     * @param  usdsAmount Amount of USDS to burn (18-decimal precision).
     */
    function burn(uint256 usdsAmount) external;

    /**
     * @notice Mints USDS by drawing from the vault and transferring from the buffer to the proxy.
     * @param  usdsAmount Amount of USDS to mint (18-decimal precision).
     */
    function mint(uint256 usdsAmount) external;

    /**
     * @notice Sets the USDS mint rate limit.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setMintRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    ) external;

    /**
     * @notice Sets the vault contract.
     * @param  vault Address of the vault contract.
     */
    function setVault(address vault) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key for mint operations. Decreased on mint, increased on burn.
    function LIMIT_MINT() external pure returns (bytes32);

    /**
     * @notice Returns the configured USDS mint rate limit.
     * @return data Rate limit data.
     */
    function mintRateLimit() external view returns (IRateLimits.RateLimitData memory data);

    /// @notice Address of the USDS token contract (immutable).
    function usds() external view returns (address);

    /// @notice Address of the Sky Allocation Vault contract.
    function vault() external view returns (address);

}
