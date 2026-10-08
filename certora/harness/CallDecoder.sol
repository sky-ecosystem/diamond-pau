// SPDX-License-Identifier: AGPL-3.0-or-later
//
// CallDecoder.sol -- Certora harness: splits calldata into its selector and first argument words,
// which CVL cannot do on its own

pragma solidity ^0.8.34;

/**
 * @notice Pure helper called from CVL. It never reverts, so malformed calldata shows up as a
 *         result rather than as a pruned path. Words beyond the calldata read as zero; the length
 *         tells whether they were present.
 */
contract CallDecoder {

    function decodeCall(bytes calldata data)
        external
        pure
        returns (uint256 length, bytes4 selector, uint256 word0, uint256 word1, uint256 word2)
    {
        length = data.length;

        if (length >= 4)   selector = bytes4(data[:4]);
        if (length >= 36)  word0    = uint256(bytes32(data[4:36]));
        if (length >= 68)  word1    = uint256(bytes32(data[36:68]));
        if (length >= 100) word2    = uint256(bytes32(data[68:100]));
    }

}
