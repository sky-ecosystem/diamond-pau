// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IController } from "../../src/interfaces/IController.sol";

interface IControllerFull is IController {

    /**********************************************************************************************/
    /*** ERC4626 actions                                                                        ***/
    /**********************************************************************************************/

    function maxExchangeRates(address token) external view returns (uint256);

    function setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets) external;

}
