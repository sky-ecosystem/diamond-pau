// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED ST-2: slot constant copied from SharedControllerStorage — aliases the shared
// accessControls/proxy/rateLimits pointers while the namespace claims CleanFacet.
contract CleanFacet {
    /// @custom:storage-location erc7201:sky.pau.storage.CleanFacet.v1
    struct FacetStorage { address accessControls; address proxy; address rateLimits; }

    bytes32 internal constant FACET_STORAGE_LOCATION =
        0x77adf60bdbfedf206f8b8310f3d364080b7f61dcc0e46caac13c29bb1eb5cc00;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }
}
