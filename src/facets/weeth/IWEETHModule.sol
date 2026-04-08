// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    IAccessControlEnumerable
} from "../../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

interface IWEETHModule is IAccessControlEnumerable {

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev    Claims a withdrawal.
     * @param  requestId   Request ID.
     * @return ethReceived Amount of ETH received.
     */
    function claimWithdrawal(uint256 requestId) external returns (uint256 ethReceived);

    /**
     * @dev   Initializes the WEETH module.
     * @param admin_    Admin address.
     * @param almProxy_ ALM proxy address.
     */
    function initialize(address admin_, address almProxy_) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    ALM proxy address.
     * @return address ALM proxy address.
     */
    function almProxy() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Receives an ERC721 token.
     * @param  operator Operator address.
     * @param  from     From address.
     * @param  tokenId  Token ID.
     * @param  data     Data.
     * @return bytes4   Selector.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        returns (bytes4);

    /**
     * @dev    Supports an interface.
     * @param  interfaceId Interface ID.
     * @return bool Result.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

}
