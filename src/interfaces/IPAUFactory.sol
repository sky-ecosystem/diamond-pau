// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

/**
 * @title  IPAUFactory
 * @notice Factory for deploying individual PAU system components with expected bytecode.
 */
interface IPAUFactory {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when an AccessControls contract is deployed.
     * @param  accessControls Address of the deployed AccessControls contract.
     */
    event AccessControlsDeployed(address indexed accessControls);

    /**
     * @notice Emitted when a Controller contract is deployed.
     * @param  controller     Address of the deployed Controller contract.
     * @param  accessControls Address of the controller's AccessControls contract.
     * @param  proxy          Address of the controller's ALMProxy contract.
     * @param  rateLimits     Address of the controller's RateLimits contract.
     */
    event ControllerDeployed(
        address indexed controller,
        address         accessControls,
        address         proxy,
        address         rateLimits
    );

    /**
     * @notice Emitted when an ALMProxy contract is deployed.
     * @param  almProxy Address of the deployed ALMProxy contract.
     */
    event ALMProxyDeployed(address indexed almProxy);

    /**
     * @notice Emitted when an ALMProxyFreezable contract is deployed.
     * @param  almProxyFreezable Address of the deployed ALMProxyFreezable contract.
     */
    event ALMProxyFreezableDeployed(address indexed almProxyFreezable);

    /**
     * @notice Emitted when a full PAU is deployed.
     * @param  controller Address of the deployed Controller contract.
     */
    event PAUDeployed(address indexed controller);

    /**
     * @notice Emitted when a RateLimits contract is deployed.
     * @param  rateLimits Address of the deployed RateLimits contract.
     */
    event RateLimitsDeployed(address indexed rateLimits);

    /**********************************************************************************************/
    /*** Custom Errors                                                                          ***/
    /**********************************************************************************************/

    /// @notice Thrown when the beacon is the zero address.
    error ZeroBeacon();

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Deploys an AccessControls contract.
     * @param  admin          Address that will be granted admin over the deployed contract.
     * @param  salt           Salt to use for the deployment.
     * @return accessControls Address of the deployed AccessControls contract.
     */
    function deployAccessControls(address admin, bytes32 salt)
        external
        returns (address accessControls);

    /**
     * @notice Deploys a Controller contract.
     * @param  accessControls Address of the controller's AccessControls contract.
     * @param  proxy          Address of the controller's ALMProxy contract.
     * @param  rateLimits     Address of the controller's RateLimits contract.
     * @param  salt           Salt to use for the deployment.
     * @return controller     Address of the deployed Controller contract.
     */
    function deployController(
        address accessControls,
        address proxy,
        address rateLimits,
        bytes32 salt
    )
        external
        returns (address controller);

    /**
     * @notice Deploys an ALMProxy contract.
     * @param  admin    Address that will be granted admin over the deployed contract.
     * @param  salt     Salt to use for the deployment.
     * @return almProxy Address of the deployed ALMProxy contract.
     */
    function deployALMProxy(address admin, bytes32 salt) external returns (address almProxy);

    /**
     * @notice Deploys an ALMProxyFreezable contract.
     * @param  admin             Address that will be granted admin over the deployed contract.
     * @param  salt              Salt to use for the deployment.
     * @return almProxyFreezable Address of the deployed ALMProxyFreezable contract.
     */
    function deployALMProxyFreezable(address admin, bytes32 salt)
        external
        returns (address almProxyFreezable);

    /**
     * @notice Deploys a RateLimits contract.
     * @param  admin      Address that will be granted admin over the deployed contract.
     * @param  salt       Salt to use for the deployment.
     * @return rateLimits Address of the deployed RateLimits contract.
     */
    function deployRateLimits(address admin, bytes32 salt) external returns (address rateLimits);

    /**
     * @notice Deploys a complete PAU system, which includes a Controller and its AccessControls,
     *         ALMProxy and RateLimits contracts.
     * @param  admin      Address that will be granted admin over the deployed contracts.
     * @param  salt       Salt to use for the deployments.
     * @return controller Address of the deployed Controller contract, from which the
     *                    AccessControls, ALMProxy, and RateLimits contracts may be queried.
     */
    function deployPAU(address admin, bytes32 salt) external returns (address controller);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @notice Address of the Beacon that deployed Controllers will sync integrations from
     *         (immutable).
     */
    function beacon() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Getters                                                                      ***/
    /**********************************************************************************************/

    /**
     * @notice Checks if an address is an AccessControls contract.
     * @param  instance   Address to check.
     * @return isInstance True if the address is an AccessControls contract.
     */
    function isAccessControls(address instance) external view returns (bool isInstance);

    /**
     * @notice Checks if an address is an ALMProxy contract.
     * @param  instance   Address to check.
     * @return isInstance True if the address is an ALMProxy contract.
     */
    function isALMProxy(address instance) external view returns (bool isInstance);

    /**
     * @notice Checks if an address is an ALMProxyFreezable contract.
     * @param  instance   Address to check.
     * @return isInstance True if the address is an ALMProxyFreezable contract.
     */
    function isALMProxyFreezable(address instance) external view returns (bool isInstance);

    /**
     * @notice Checks if an address is a Controller contract.
     * @param  instance   Address to check.
     * @return isInstance True if the address is a Controller contract.
     */
    function isController(address instance) external view returns (bool isInstance);

    /**
     * @notice Checks if an address is a RateLimits contract.
     * @param  instance   Address to check.
     * @return isInstance True if the address is a RateLimits contract.
     */
    function isRateLimits(address instance) external view returns (bool isInstance);

}
