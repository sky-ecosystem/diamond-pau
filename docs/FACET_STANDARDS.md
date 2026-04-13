# Facet Standards

This document is the canonical reference for writing a new PAU facet. Follow it exactly.
It exists so that an agent given a business requirements template can produce a correct, fully-tested facet without human guidance on structure.

Related docs:
- `FACET_TESTING.md` — testing requirements and patterns
- `FACET_INTEGRATION_TEMPLATE.md` — fill-in template for new integrations

---

## 1. File Structure

```
src/
  facets/
    <protocol>/
      <Protocol>Facet.sol    ← implementation
      I<Protocol>Facet.sol   ← interface
src/
  interfaces/
    facets/
      I<Protocol>Facet.sol   ← symlink or canonical location (check existing facets)
test/
  integration/
    facets/
      <Protocol>Facet.t.sol  ← mock-based integration tests (required)
test/
  mainnet-fork/              ← fork tests if mainnet integration exists
  base-fork/                 ← fork tests if Base integration exists
```

The directory name is lowercase: `src/facets/aave/`, `src/facets/uniswap-v3/`, `src/facets/layer-zero/`.
The contract and file name is PascalCase + "Facet": `AaveFacet.sol`, `UniswapV3Facet.sol`.

---

## 2. Contract Template

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }     from "../../libraries/ApproveLib.sol";
import { makeAddressKey } from "../../libraries/RateLimitHelpers.sol";  // use appropriate helper

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { FacetBase } from "../FacetBase.sol";

import { I<Protocol>Facet } from "./I<Protocol>Facet.sol";

// Inline minimal interfaces for external protocol contracts — only the functions called by this facet.
interface IProtocolLike {
    function externalFunction(address asset, uint256 amount) external;
}

contract <Protocol>Facet is I<Protocol>Facet, FacetBase {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.<Protocol>Facet.v1
    struct FacetStorage {
        // per-facet state here — see section 4
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.<Protocol>Facet.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant FACET_STORAGE_LOCATION = <COMPUTED_SLOT>;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION;
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant override LIMIT_<OPERATION> = keccak256("LIMIT_<PROTOCOL>_<OPERATION>");

    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    // Only include if the facet has immutable protocol addresses.
    // All addresses must be sourced from spark-address-registry at deploy time.
    address public immutable override PROTOCOL_CONTRACT;

    constructor(address protocolContract_) {
        require(protocolContract_ != address(0), "<Protocol>Facet/protocol-contract-zero-address");
        PROTOCOL_CONTRACT = protocolContract_;
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function setParam(address key, uint256 value)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(key != address(0), "<Protocol>Facet/key-zero-address");
        emit <Protocol>ParamSet(key, _getFacetStorage().params[key] = value);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    function deposit(address asset, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        address proxy = _getSharedControllerStorage().proxy;

        _decreaseRateLimit(LIMIT_DEPOSIT, asset, amount);

        // <operation>
        // Emit last, after all state changes and external calls.
        emit <Protocol>Deposit(asset, amount);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function getParam(address key) external view override returns (uint256) {
        return _getFacetStorage().params[key];
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _decreaseRateLimit(bytes32 key, address asset, uint256 amount) internal {
        IRateLimits(_getSharedControllerStorage().rateLimits).triggerRateLimitDecrease(
            makeAddressKey(key, asset),
            amount
        );
    }

    function _increaseRateLimit(bytes32 key, address asset, uint256 amount) internal {
        IRateLimits(_getSharedControllerStorage().rateLimits).triggerRateLimitIncrease(
            makeAddressKey(key, asset),
            amount
        );
    }

}
```

---

## 3. Section Order

Contracts must use the following section headers in this exact order (omit sections that don't apply):

```
/*** Facet Storage Domain   ***/    ← always first if facet has its own storage
/*** Constants              ***/    ← LIMIT_* keys, VERSION, any other constants
/*** Constructor            ***/    ← only if facet has immutables
/*** External Interactive Admin Functions   ***/    ← DEFAULT_ADMIN_ROLE functions
/*** External Interactive Relayer Functions ***/    ← RELAYER_ROLE functions
/*** External Variable Getters ***/                 ← public variable views, if any
/*** External View/Pure Functions ***/              ← read-only functions
/*** Internal Interactive Functions ***/            ← rate limit helpers, etc.
/*** Internal View/Pure Functions ***/              ← internal reads
```

Section header format (fixed width, 96 chars):
```
/**********************************************************************************************/
/*** Section Name                                                                           ***/
/**********************************************************************************************/
```

---

## 4. ERC-7201 Storage

Every facet that stores any per-facet state MUST use an ERC-7201 isolated storage slot.

### Namespace pattern
```
sky.pau.storage.<ContractName>.v1
```
Where `<ContractName>` exactly matches the Solidity contract name (e.g., `AaveFacet`, `UniswapV4Facet`).

### Slot formula
```solidity
// keccak256(abi.encode(uint256(keccak256("sky.pau.storage.<ContractName>.v1")) - 1)) & ~bytes32(uint256(0xff))
bytes32 internal constant FACET_STORAGE_LOCATION = <COMPUTED_VALUE>;
```

Compute the slot before writing the file. Do not guess or copy from another facet. Use:
```bash
cast keccak "sky.pau.storage.<ContractName>.v1" | \
  python3 -c "import sys; v=int(sys.stdin.read().strip(),16); print(hex((v-1) & ~0xff))"
```

### Storage struct naming
Always use the generic names regardless of facet — the namespace in the string is what makes it unique:
- Struct: `FacetStorage`
- Slot constant: `FACET_STORAGE_LOCATION`
- Accessor: `_getFacetStorage()`

### Version tag
Include `uint8 version = 1;` as the first field of every `FacetStorage` struct. This enables migration detection in future upgrades.

### Named mappings
Use Solidity 0.8.26+ named mapping syntax:
```solidity
mapping(address aToken => uint256 maxSlippage) maxSlippages;
```

---

## 5. Access Control

Every external function must have BOTH of the following, in this order:
1. `nonReentrant` (from `FacetBase` via `ReentrancyGuard`)
2. `onlyRole(...)` (from `FacetBase`)

| Function type | Role |
|---|---|
| Relayer operations | `RELAYER_ROLE` |
| Config setters | `DEFAULT_ADMIN_ROLE` |
| View/pure functions | none required |

The order `nonReentrant onlyRole(...)` is mandatory. Never reverse them.

---

## 6. Rate Limits

Every state-changing relayer function that moves value MUST trigger a rate limit.
Outflows use `triggerRateLimitDecrease`. Inflows use `triggerRateLimitIncrease`.
Withdrawals MUST both decrease the WITHDRAW limit AND increase the DEPOSIT limit (restores capacity).

### Limit key naming
```solidity
bytes32 public constant override LIMIT_DEPOSIT  = keccak256("LIMIT_<PROTOCOL>_DEPOSIT");
bytes32 public constant override LIMIT_WITHDRAW = keccak256("LIMIT_<PROTOCOL>_WITHDRAW");
```

All `LIMIT_*` constants are public and exposed via the interface for auditability.

### Key construction helpers (use the correct one for your parameter type)

| Parameter | Helper |
|---|---|
| `address` | `makeAddressKey(key, addr)` |
| `address, address` | `makeAddressAddressKey(key, a, b)` |
| `address, uint16` | `makeAddressUint16Key(key, addr, n)` |
| `address, uint32` | `makeAddressUint32Key(key, addr, n)` |
| `bytes32` | `makeBytes32Key(key, b32)` |
| `uint32` | `makeUint32Key(key, n)` |

The global rate limit (across all markets for a protocol) uses just `LIMIT_*` directly without a key helper.

---

## 7. Approvals

Use `ApproveLib.approve(token, proxy, spender, amount)` — never set approvals inline.
`ApproveLib` correctly handles existing allowances, resetting to zero first where required (e.g., USDT-style tokens).

---

## 8. External Calls

All value-moving calls to external protocols MUST go through the ALM proxy:
```solidity
IALMProxy(proxy).doCall(target, abi.encodeCall(IProtocol.function, (args)));
```

Return values from `doCall` must be decoded with `abi.decode`:
```solidity
uint256 result = abi.decode(
    IALMProxy(proxy).doCall(target, abi.encodeCall(...)),
    (uint256)
);
```

The proxy is always read from shared storage — never from a facet immutable:
```solidity
address proxy = _getSharedControllerStorage().proxy;
```

---

## 9. Minimal Inline Interfaces

Define only the protocol functions called by this facet, in the facet file itself.
Do not import external protocol contracts. Do not add unused functions.

```solidity
interface IProtocolLike {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}
```

---

## 10. Constructor Immutables

Use constructor-injected immutables (not hardcoded constants) for all protocol contract addresses.
All values MUST be sourced from `spark-address-registry` at deploy time.
Every constructor argument must have a zero-address guard:

```solidity
constructor(address protocolContract_) {
    require(protocolContract_ != address(0), "<Protocol>Facet/protocol-contract-zero-address");
    PROTOCOL_CONTRACT = protocolContract_;
}
```

All immutables must be exposed as public `view` functions in the interface.

---

## 11. Events

One event per meaningful state change and per relayer operation. Events are emitted LAST — after all state changes and external calls.

### Naming
Prefix all events with the protocol domain name:
```solidity
event AaveDeposit(address indexed aToken, uint256 amount);
event AaveMaxSlippageSet(address indexed aToken, uint256 maxSlippage);
event AaveWithdraw(address indexed aToken, uint256 amountWithdrawn);
```

### Indexed parameters
Index address parameters. Do not index value parameters unless there is an explicit need to filter by them.

### NatSpec on events
Every event must have a `@notice` and a `@param` for each parameter.

---

## 12. Error Strings

Use string require errors for input validation in the format:
```
"<ContractName>/<kebab-case-description>"
```

Example: `"AaveFacet/aToken-zero-address"`, `"CurveFacet/invalid-indices"`

Custom errors (e.g., `error InvalidFacet(address facet)`) are preferred for errors that carry structured data or are expected to be caught programmatically. Never mix both styles for the same condition.

---

## 13. Interface (`I<Protocol>Facet.sol`)

The interface must:
1. Extend `IFacetBase`
2. Declare all events with full NatSpec (`@notice`, `@param` per param)
3. Declare all public functions with full NatSpec (`@notice`, `@param`, `@return`)
4. Declare all `LIMIT_*` constants with `@notice`
5. Declare `VERSION` with `@notice`
6. Declare all constructor immutables as `external view` functions if they exist
7. Group with section headers in this order: Events, Interactive Functions, Variables, View/Pure Functions

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  I<Protocol>Facet
 * @notice PAU facet for <one sentence description>.
 */
interface I<Protocol>Facet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    // ... events with NatSpec

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    // ... admin and relayer functions

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    // ... LIMIT_* constants, VERSION, immutables

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    // ... getters

}
```

---

## 14. VERSION

Every facet must declare:
```solidity
string public constant override VERSION = "1.0.0";
```
Bump the version when storage layout changes.

---

## 15. Wiring and Integration ID

When registering the facet in the Beacon, use a stable uppercase snake-case integration ID:
```
"AAVE_FACET"
"UNISWAP_V3_FACET"
"GROVE_BASIN_FACET"
```

Wires map the Controller-facing selector (namespaced, e.g. `setAaveMaxSlippage`) to the facet-internal selector (generic, e.g. `setMaxSlippage`). This naming convention keeps the Controller's external API self-documenting while keeping facet implementations portable.

---

## 16. What NOT to Do

- Do not hardcode protocol contract addresses as `constant`. Use constructor immutables.
- Do not call external protocols directly from the facet. Use `IALMProxy.doCall`.
- Do not set token approvals inline. Use `ApproveLib.approve`.
- Do not emit events before state changes or external calls.
- Do not omit `nonReentrant` on any external function.
- Do not omit a rate limit call in any relayer function that moves value.
- Do not share an ERC-7201 namespace string with any other facet.
- Do not skip zero-address checks on constructor arguments or admin setters that take addresses.
- Do not add unused imports or interfaces.
- Do not write a facet without a corresponding test file (`test/integration/facets/<Protocol>Facet.t.sol`).
