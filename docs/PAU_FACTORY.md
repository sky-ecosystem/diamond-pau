# PAU Factory

This document describes the `PAUFactory` contract, the centralized governance contract for deploying and managing DiamondPAU system instances.

## Purpose

PAUFactory serves two roles:

1. **Atomic deployment** of complete PAU systems (ALMProxy, RateLimits, AccessControls, Controller) via a single `deploy()` call.
2. **Global facet validation registry** that determines which facet contracts are allowed to be wired into any Controller deployed by this factory.

## Roles

| Role | Description |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Admin of the factory. Can manage role assignments. |
| `FACET_VALIDATOR_ROLE` | Can approve or revoke facets via `setValidFacet` / `setValidFacets`. |

## Deployment

`deploy(address admin)` atomically creates and configures a full PAU system:

1. Create ALMProxy and RateLimits with the factory as initial admin.
2. Create AccessControls with the passed `admin`.
3. Create Controller with all dependencies and a reference back to the factory.
4. Grant `CONTROLLER` role to the Controller on both ALMProxy and RateLimits.
5. Grant `DEFAULT_ADMIN_ROLE` to the passed `admin` on ALMProxy and RateLimits.
6. Revoke the factory's own `DEFAULT_ADMIN_ROLE` on ALMProxy and RateLimits, so the factory cannot control deployed systems after setup.
7. Emit `PAUDeployed` event with all deployed addresses.

## ValidFacet Registry

The factory maintains a global allowlist of facet contracts via the `isValidFacet` mapping.

- `setValidFacet(address facet, bool valid)`: Approve or revoke a single facet. Requires `FACET_VALIDATOR_ROLE`.
- `setValidFacets(address[] facets, bool[] valid)`: Batch version.

Facets must be non-zero addresses with deployed code, otherwise the call reverts.

### Relationship to Controller

The Controller stores the factory address in its ERC-7201 storage. On every `addWire` or `addWires` call, the Controller checks `IPAUFactory(factory).isValidFacet(facet)` and reverts if the facet is not approved. This means only governance-approved facets can be wired into any Controller deployed by this factory.

## Security Considerations

- **`FACET_VALIDATOR_ROLE` is high-trust.** Approved facets execute via `delegatecall` in the Controller's context, giving them full access to Controller storage and the ability to call the ALMProxy.
- **Validation is checked at wire-time only.** Revoking a facet after it has been wired does not automatically unwire it. An admin must explicitly call `removeWire` or `removeAllWiresFor`.
- **Factory self-revokes after deployment.** The factory revokes its own admin roles on ALMProxy and RateLimits at the end of `deploy()`, preventing the factory from controlling deployed systems.
