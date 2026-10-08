// SPDX-License-Identifier: AGPL-3.0-or-later
//
// TransferCallDecoder.sol -- Certora harness: decodes ERC-20 transfer calldata and return data,
// which CVL cannot do on its own

pragma solidity ^0.8.34;

/**
 * @notice Pure helpers called from CVL. They never revert, so a malformed input shows up as a
 *         result rather than as a pruned path.
 */
contract TransferCallDecoder {

    /// @notice Splits calldata of the shape transfer(address,uint256). `wellFormed` is false when
    ///         the length is not 4 + 2 words; the other values are then zero.
    function decodeTransfer(bytes calldata data)
        external
        pure
        returns (bool wellFormed, bytes4 selector, uint256 toWord, uint256 amount)
    {
        if (data.length != 68) return (false, bytes4(0), 0, 0);

        selector = bytes4(data[:4]);
        toWord   = uint256(bytes32(data[4:36]));
        amount   = uint256(bytes32(data[36:68]));

        return (true, selector, toWord, amount);
    }

    /// @notice True exactly when TransferAssetFacet accepts a token's answer: no return data, or a
    ///         single word decoding to true. A word other than 0 or 1 makes abi.decode revert, and
    ///         0 fails the facet's require, so both count as rejected.
    function isAcceptedAnswer(bytes calldata returnData) external pure returns (bool) {
        if (returnData.length == 0) return true;
        if (returnData.length != 32) return false;

        return uint256(bytes32(returnData[:32])) == 1;
    }

}
