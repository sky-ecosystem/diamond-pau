// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IAccessControlLike {

    function getRoleMemberCount(bytes32 role) external view returns (uint256);

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

}

interface IALMProxyLike {

    function CONTROLLER() external view returns (bytes32);

}

interface IControllerLike {

    function accessControls() external view returns (address);

    function beacon() external view returns (address);

    function proxy() external view returns (address);

    function rateLimits() external view returns (address);

    function removeIntegrations(bytes32[] calldata ids) external;

    function updateIntegrations(bytes32[] calldata ids) external;

}

interface IRateLimitsLike {

    function CONTROLLER() external view returns (bytes32);

}

/**
 * @notice Identifies one PAU stack: the AccessControls / RateLimits / Controller triple, the
 *         ALMProxy the Controller is wired to, and the shared Beacon the Controller resolves
 *         integrations against. Multiple stacks may share the same `almProxy` and `beacon`.
 *         Spells build this struct from the deployment output (exported addresses).
 */
struct PAUInstance {
    address accessControls;
    address almProxy;
    address beacon;
    address controller;
    address rateLimits;
}

/**
 * @title  PAUInit
 * @notice Initialization library for a deployed PAU stack. Intended to be called by a spell
 *         executing as the governance contract (PauseProxy or SubProxy) that holds
 *         DEFAULT_ADMIN_ROLE on every component.
 *
 * @dev    Internal-functions-only so the compiler inlines the library into the spell action and
 *         every call executes as the governance proxy — there is no separately deployed/linked
 *         library lifecycle to manage. Sanity checks validate the stack's immutable constructor
 *         wiring before any mutable configuration is applied, so reviewers only need to validate
 *         the inputs.
 */
library PAUInit {

    bytes32 internal constant ALLOCATOR_ROLE     = keccak256("ALLOCATOR_ROLE");
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @notice Initializes a PAU stack: grants the Controller its CONTROLLER role on the ALMProxy
     *         and on its RateLimits, and optionally syncs integrations.
     * @dev    When `integrationIds` is empty the `updateIntegrations` call is skipped (the
     *         Controller reverts on an empty array).
     * @param  inst           The PAU stack.
     * @param  integrationIds Integration IDs to sync on the Controller (may be empty).
     */
    function init(PAUInstance memory inst, bytes32[] memory integrationIds) internal {
        IControllerLike controller = IControllerLike(inst.controller);

        // Sanity checks: the Controller's immutable constructor wiring must match the instance.
        require(
            controller.accessControls() == inst.accessControls,
            "PAUInit/controller-access-controls-mismatch"
        );
        require(controller.proxy()      == inst.almProxy,   "PAUInit/controller-proxy-mismatch");
        require(controller.beacon()     == inst.beacon,     "PAUInit/controller-beacon-mismatch");
        require(controller.rateLimits() == inst.rateLimits, "PAUInit/controller-rate-limits-mismatch");

        // Sanity checks: the executing context must be admin on every component.
        require(
            IAccessControlLike(inst.accessControls).hasRole(DEFAULT_ADMIN_ROLE, address(this)),
            "PAUInit/not-access-controls-admin"
        );
        // AccessControls is the sole enumerable component (ALMProxy/RateLimits use non-enumerable
        // AccessControl), so this is the one place we can assert governance is the *only* admin.
        require(
            IAccessControlLike(inst.accessControls).getRoleMemberCount(DEFAULT_ADMIN_ROLE) == 1,
            "PAUInit/access-controls-not-sole-admin"
        );
        require(
            IAccessControlLike(inst.almProxy).hasRole(DEFAULT_ADMIN_ROLE, address(this)),
            "PAUInit/not-alm-proxy-admin"
        );
        require(
            IAccessControlLike(inst.rateLimits).hasRole(DEFAULT_ADMIN_ROLE, address(this)),
            "PAUInit/not-rate-limits-admin"
        );

        // Check that no allocator agents have been added to the AccessControls.
        require(
            IAccessControlLike(inst.accessControls).getRoleMemberCount(ALLOCATOR_ROLE) == 0,
            "PAUInit/allocator-agents-present"
        );

        // Structural wiring: the Controller is CONTROLLER on the ALMProxy and on its RateLimits.
        IAccessControlLike(inst.almProxy).grantRole(
            IALMProxyLike(inst.almProxy).CONTROLLER(),
            inst.controller
        );

        IAccessControlLike(inst.rateLimits).grantRole(
            IRateLimitsLike(inst.rateLimits).CONTROLLER(),
            inst.controller
        );

        if (integrationIds.length > 0) controller.updateIntegrations(integrationIds);
    }

    /**
     * @notice Grants an AdministeredAgent the ALLOCATOR_ROLE on the stack's AccessControls.
     * @dev The caller of this function must be a role admin for `ALLOCATOR_ROLE`
     * @dev Checks the access controls on `inst` matches the controller's
     * @param  inst  The PAU stack.
     * @param  agent The AdministeredAgent to grant.
     */
    function addAllocator(PAUInstance memory inst, address agent) internal {
        require(agent != address(0), "PAUInit/agent-zero-address");

        require(
            IControllerLike(inst.controller).accessControls() == inst.accessControls,
            "PAUInit/controller-access-controls-mismatch"
        );

        IAccessControlLike(inst.accessControls).grantRole(ALLOCATOR_ROLE, agent);
    }

    /**
     * @notice Syncs integrations on the stack's Controller.
     * @param  inst The PAU stack.
     * @param  ids  Integration IDs to sync (must be non-empty).
     */
    function setIntegrations(PAUInstance memory inst, bytes32[] memory ids) internal {
        IControllerLike(inst.controller).updateIntegrations(ids);
    }

    /**
     * @notice Removes integrations from the stack's Controller.
     * @param  inst The PAU stack.
     * @param  ids  Integration IDs to remove (must be non-empty).
     */
    function removeIntegrations(PAUInstance memory inst, bytes32[] memory ids) internal {
        IControllerLike(inst.controller).removeIntegrations(ids);
    }

}
