// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED S-6: imports a protocol ABI from lib/ instead of a minimal I<X>Like shim.
import { IPool } from "../../../lib/aave-v3-core/contracts/interfaces/IPool.sol";

contract CleanFacet {
    IPool internal pool;
}
