// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ALMProxy }       from "../ALMProxy.sol";
import { AccessControls } from "../AccessControls.sol";
import { Controller }     from "../Controller.sol";
import { RateLimits }     from "../RateLimits.sol";

interface IDiamondPAUFactory {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event DiamondPAUDeployed(
        address indexed admin,
        address         accessControls,
        address         almProxy,
        address         controller,
        address         rateLimits
    );

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct DiamondPAU {
        AccessControls accessControls;
        ALMProxy       almProxy;
        Controller     controller;
        RateLimits     rateLimits;
    }

    /**********************************************************************************************/
    /*** Functions                                                                              ***/
    /**********************************************************************************************/

    function deployDiamondPAU(address admin) external returns (DiamondPAU memory system);

}
