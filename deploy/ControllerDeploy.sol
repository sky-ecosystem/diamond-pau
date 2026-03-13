// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { AccessControlRegistry } from "../src/AccessControlRegistry.sol";
import { ALMProxy }              from "../src/ALMProxy.sol";
import { ForeignController }     from "../src/ForeignController.sol";
import { MainnetController }     from "../src/MainnetController.sol";
import { ParameterRegistry }     from "../src/ParameterRegistry.sol";
import { RateLimits }            from "../src/RateLimits.sol";

import { ControllerInstance } from "./ControllerInstance.sol";

library ForeignControllerDeploy {

    function deployController(
        address admin,
        address almProxy,
        address rateLimits,
        address accessControlRegistry,
        address parameterRegistry,
        address psm,
        address usdc,
        address cctp
    )
        internal
        returns (address controller)
    {
        controller = address(new ForeignController({
            admin_                 : admin,
            proxy_                 : almProxy,
            rateLimits_            : rateLimits,
            accessControlRegistry_ : accessControlRegistry,
            parameterRegistry_     : parameterRegistry,
            psm_                   : psm,
            usdc_                  : usdc,
            cctp_                  : cctp
        }));
    }

    function deployFull(
        address admin,
        address psm,
        address usdc,
        address cctp
    )
        internal
        returns (ControllerInstance memory instance)
    {
        instance.accessControlRegistry = address(new AccessControlRegistry(admin));

        address[] memory admins = new address[](1);

        admins[0] = admin;

        instance.parameterRegistry = address(new ParameterRegistry(admins));

        instance.almProxy   = address(new ALMProxy(admin));
        instance.rateLimits = address(new RateLimits(admin));

        instance.controller = address(new ForeignController({
            admin_                 : admin,
            proxy_                 : instance.almProxy,
            rateLimits_            : instance.rateLimits,
            accessControlRegistry_ : instance.accessControlRegistry,
            parameterRegistry_     : instance.parameterRegistry,
            psm_                   : psm,
            usdc_                  : usdc,
            cctp_                  : cctp
        }));
    }

}

library MainnetControllerDeploy {

    function deployController(
        address admin,
        address almProxy,
        address rateLimits,
        address accessControlRegistry,
        address parameterRegistry,
        address vault,
        address psm,
        address daiUsds,
        address cctp
    )
        internal
        returns (address controller)
    {
        controller = address(new MainnetController({
            admin_                 : admin,
            proxy_                 : almProxy,
            rateLimits_            : rateLimits,
            accessControlRegistry_ : accessControlRegistry,
            parameterRegistry_     : parameterRegistry,
            vault_                 : vault,
            psm_                   : psm,
            daiUsds_               : daiUsds,
            cctp_                  : cctp
        }));
    }

    function deployFull(
        address admin,
        address vault,
        address psm,
        address daiUsds,
        address cctp
    )
        internal
        returns (ControllerInstance memory instance)
    {
        instance.accessControlRegistry = address(new AccessControlRegistry(admin));

        address[] memory admins = new address[](1);

        admins[0] = admin;
    
        instance.parameterRegistry = address(new ParameterRegistry(admins));

        instance.almProxy   = address(new ALMProxy(admin));
        instance.rateLimits = address(new RateLimits(admin));

        instance.controller = address(new MainnetController({
            admin_                 : admin,
            proxy_                 : instance.almProxy,
            rateLimits_            : instance.rateLimits,
            accessControlRegistry_ : instance.accessControlRegistry,
            parameterRegistry_     : instance.parameterRegistry,
            vault_                 : vault,
            psm_                   : psm,
            daiUsds_               : daiUsds,
            cctp_                  : cctp
        }));
    }

}
