// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IPAUFactory } from "./interfaces/IPAUFactory.sol";

import { AccessControls }    from "./AccessControls.sol";
import { ALMProxy }          from "./ALMProxy.sol";
import { ALMProxyFreezable } from "./ALMProxyFreezable.sol";
import { Controller }        from "./Controller.sol";
import { RateLimits }        from "./RateLimits.sol";

contract PAUFactory is IPAUFactory {

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    address public immutable override beacon;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address beacon_) {
        require((beacon = beacon_) != address(0), ZeroBeacon());
    }

    /**********************************************************************************************/
    /*** External Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function deployAccessControls(address admin) external override returns (address accessControls) {
        accessControls = address(new AccessControls(admin));
        emit AccessControlsDeployed(accessControls);
    }

    function deployController(address accessControls, address proxy, address rateLimits)
        external
        override
        returns (address controller)
    {
        controller = address(new Controller(accessControls, beacon, proxy, rateLimits));
        emit ControllerDeployed(controller, accessControls, proxy, rateLimits);
    }

    function deployProxy(address admin) external override returns (address proxy) {
        proxy = address(new ALMProxy(admin));
        emit ProxyDeployed(proxy);
    }

    function deployProxyFreezable(address admin)
        external
        override
        returns (address proxyFreezable)
    {
        proxyFreezable = address(new ALMProxyFreezable(admin));
        emit ProxyFreezableDeployed(proxyFreezable);
    }

    function deployRateLimits(address admin) external override returns (address rateLimits) {
        rateLimits = address(new RateLimits(admin));
        emit RateLimitsDeployed(rateLimits);
    }

}
