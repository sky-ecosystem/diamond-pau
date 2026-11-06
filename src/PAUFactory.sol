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

    mapping (address instance => bool isInstance) public override isAccessControls;
    mapping (address instance => bool isInstance) public override isALMProxy;
    mapping (address instance => bool isInstance) public override isALMProxyFreezable;
    mapping (address instance => bool isInstance) public override isController;
    mapping (address instance => bool isInstance) public override isRateLimits;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address beacon_) {
        require((beacon = beacon_) != address(0), ZeroBeacon());
    }

    /**********************************************************************************************/
    /*** External Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function deployAccessControls(address admin, bytes32 salt)
        public
        override
        returns (address accessControls)
    {
        accessControls = address(new AccessControls{ salt: _getSalt(msg.sender, salt) }(admin));

        isAccessControls[accessControls] = true;

        emit AccessControlsDeployed(accessControls);
    }

    function deployController(
        address accessControls,
        address proxy,
        address rateLimits,
        bytes32 salt
    )
        public
        override
        returns (address controller)
    {
        controller =
            address(
                new Controller{ salt: _getSalt(msg.sender, salt) }(
                    accessControls,
                    beacon,
                    proxy,
                    rateLimits
                )
            );

        isController[controller] = true;

        emit ControllerDeployed(controller, accessControls, proxy, rateLimits);
    }

    function deployALMProxy(address admin, bytes32 salt)
        public
        override
        returns (address almProxy)
    {
        almProxy = address(new ALMProxy{ salt: _getSalt(msg.sender, salt) }(admin));

        isALMProxy[almProxy] = true;

        emit ALMProxyDeployed(almProxy);
    }

    function deployALMProxyFreezable(address admin, bytes32 salt)
        external
        override
        returns (address almProxyFreezable)
    {
        almProxyFreezable =
            address(new ALMProxyFreezable{ salt: _getSalt(msg.sender, salt) }(admin));

        isALMProxyFreezable[almProxyFreezable] = true;

        emit ALMProxyFreezableDeployed(almProxyFreezable);
    }

    function deployRateLimits(address admin, bytes32 salt)
        public
        override
        returns (address rateLimits)
    {
        rateLimits = address(new RateLimits{ salt: _getSalt(msg.sender, salt) }(admin));

        isRateLimits[rateLimits] = true;

        emit RateLimitsDeployed(rateLimits);
    }

    function deployPAU(address admin, bytes32 salt) external override returns (address controller) {
        address accessControls = deployAccessControls(admin, salt);
        address almProxy       = deployALMProxy(admin, salt);
        address rateLimits     = deployRateLimits(admin, salt);

        controller = deployController(accessControls, almProxy, rateLimits, salt);

        emit PAUDeployed(controller);
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _getSalt(address account, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, salt));
    }

}
