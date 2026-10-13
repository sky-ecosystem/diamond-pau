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

    /// @notice True exactly when a token's answer to approve or transfer counts as success for
    ///         callers that accept no return data or a single word decoding to true. A word other
    ///         than 0 or 1 makes abi.decode revert, and 0 is false, so both count as rejected.
    function isAcceptedAnswer(bytes calldata returnData) external pure returns (bool) {
        if (returnData.length == 0) return true;
        if (returnData.length != 32) return false;

        return uint256(bytes32(returnData[:32])) == 1;
    }

    /// @notice True when the answer is a single word other than 0 or 1, which abi.decode rejects
    ///         as a bool (a revert, rather than a false answer).
    function isInvalidBool(bytes calldata returnData) external pure returns (bool) {
        return returnData.length == 32 && uint256(bytes32(returnData[:32])) > 1;
    }

    /// @notice Hash of the dynamic `bytes` second argument, as in f(uint256, bytes).
    ///         `wellFormed` is false when its offset or length points outside the calldata.
    function bytesArgHash(bytes calldata data) external pure returns (bool wellFormed, bytes32 hash) {
        if (data.length < 68) return (false, bytes32(0));

        uint256 offset = uint256(bytes32(data[36:68]));

        if (offset > data.length) return (false, bytes32(0));

        uint256 lengthStart = 4 + offset;

        if (data.length < 32 || lengthStart > data.length - 32) return (false, bytes32(0));

        uint256 length    = uint256(bytes32(data[lengthStart:lengthStart + 32]));
        uint256 dataStart = lengthStart + 32;

        if (length > data.length - dataStart) return (false, bytes32(0));

        return (true, keccak256(data[dataStart:dataStart + length]));
    }

}
