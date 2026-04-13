# Facet Pre-Launch Security Checklist

This checklist must be completed before any new facet integration is deployed to mainnet.
Every question must have a documented answer. "Yes" is not always the right answer — the goal is to force explicit reasoning about each risk before deployment, not to block launches.

A completed checklist lives alongside the integration spec in `docs/integrations/<Protocol>Integration.md`.

---

## How to Use

For each question:
- Answer **YES**, **NO**, or **N/A**
- Write 1–3 sentences explaining WHY
- If the answer is a risk, document the mitigation

All HIGH and CRITICAL risks must be resolved or explicitly accepted (with sign-off) before mainnet deployment.

---

## 1. Relayer Compromise

**Q: If the relayer role is completely compromised, can funds exit the system?**

_Answer:_ TODO

_Guidance:_ The relayer can trigger operations but cannot move funds to arbitrary addresses — all outflows are constrained by rate limits and destination is controlled by the ALMProxy's ACL. Document exactly which functions the relayer can call, what the worst-case outflow is per rate limit window, and whether the freezer can halt operations before the window resets.

---

**Q: What is the maximum value extractable by a malicious relayer in a single transaction? In a single rate-limit window?**

_Answer:_ TODO

_Guidance:_ Enumerate the rate limit configs for this facet and calculate the worst-case drain. This number should be acceptable given the protocol's risk tolerance.

---

**Q: Can a relayer call functions in a sequence that bypasses individual rate limits but exceeds intended exposure?**

_Answer:_ TODO

_Guidance:_ Check cross-facet interactions. E.g. deposit to protocol A, withdraw from protocol A, deposit to protocol B — does this chain allow more exposure than any single limit permits?

---

## 2. Admin Compromise

**Q: If the admin role is completely compromised, what can an attacker do?**

_Answer:_ TODO

_Guidance:_ Admin can change config (maxSlippage, recipients, poolParams, etc.) but cannot directly move funds. Document what a malicious config change enables and how quickly damage could occur before detection.

---

**Q: Can an admin set a parameter that would allow a relayer to drain funds on the next transaction?**

_Answer:_ TODO

_Guidance:_ E.g. setting maxSlippage to 0 (disabled), setting a mint recipient to attacker address, setting maxExchangeRate to an extreme value. Document each admin setter and its worst-case misconfiguration.

---

## 3. External Protocol Risk

**Q: If the external protocol (e.g. Aave pool) is paused or bricked, are funds stuck?**

_Answer:_ TODO

_Guidance:_ Can the ALMProxy still withdraw? Is there an emergency exit path that doesn't go through this facet?

---

**Q: If the external protocol is exploited and drained, what is the PAU's exposure?**

_Answer:_ TODO

_Guidance:_ State the maximum deposited amount (rate limit cap) and whether the protocol has insurance/backstop mechanisms.

---

**Q: Does the external protocol make any callbacks into the caller? Could this re-enter the Controller?**

_Answer:_ TODO

_Guidance:_ Check for ERC-777 hooks, flash loan callbacks, or any `receive()` calls. The Controller has a reentrancy guard — verify it covers the callback path.

---

**Q: Does this integration interact with an oracle? If so, what happens if the oracle is manipulated or stale?**

_Answer:_ TODO

_Guidance:_ Document oracle dependency, staleness threshold, and whether the slippage check is sufficient protection against oracle manipulation.

---

## 4. Rate Limit Coverage

**Q: Is every function that moves value covered by a rate limit?**

_Answer:_ TODO

_Guidance:_ List every relayer function and its rate limit key. Confirm none are missing.

---

**Q: Do withdraw operations correctly restore deposit capacity?**

_Answer:_ TODO

_Guidance:_ Withdrawals should call `_increaseRateLimit(LIMIT_DEPOSIT, ...)`. If they don't, the deposit limit permanently decreases over time and eventually locks the integration.

---

**Q: Are rate limit keys unique and collision-free across all facets?**

_Answer:_ TODO

_Guidance:_ Confirm no two facets use the same `keccak256` key string. Cross-reference against all existing `LIMIT_*` constants in the codebase.

---

## 5. Storage Safety

**Q: Is the ERC-7201 storage slot unique — no collision with any other facet or the Controller/Beacon?**

_Answer:_ TODO

_Guidance:_ Show the computed slot value and confirm it does not appear in any other facet's `FACET_STORAGE_LOCATION`. Use `grep -r "FACET_STORAGE_LOCATION" src/`.

---

**Q: If this facet is replaced with a new version, is the storage layout forward-compatible?**

_Answer:_ TODO

_Guidance:_ New fields can only be appended to the struct, never inserted or reordered. Confirm the `version` tag is set and document the current struct layout.

---

## 6. Access Control

**Q: Does every external function have both `nonReentrant` and `onlyRole(...)` in the correct order?**

_Answer:_ TODO

_Guidance:_ Paste the function signatures and confirm the modifier order: `nonReentrant` before `onlyRole`.

---

**Q: Are there any functions that should be role-restricted but aren't?**

_Answer:_ TODO

_Guidance:_ Review all `external` and `public` functions. View functions do not need role restriction — everything else does.

---

## 7. Deployment

**Q: Are all constructor arguments sourced from `spark-address-registry`? Are any hardcoded?**

_Answer:_ TODO

---

**Q: Is there a deployment script? Does it include self-validating assertions?**

_Answer:_ TODO

_Guidance:_ The deployment script should revert the entire transaction if any assertion fails (e.g. wrong address, wrong role, wrong rate limit config).

---

**Q: Has the migration of any prior state been accounted for? (maxSlippages, recipients, poolParams, etc.)**

_Answer:_ TODO

---

## 8. Testing

**Q: Do all integration tests pass on the current `dev` branch?**

_Answer:_ TODO — run `forge test --match-path test/integration/facets/<Protocol>Facet.t.sol`

---

**Q: Do fork tests pass against live mainnet state?**

_Answer:_ TODO — run `forge test --match-path test/mainnet-fork/<Protocol>.t.sol --fork-url $ETH_RPC_URL`

---

**Q: Has Sparky reviewed the diff and signed off with no unresolved findings?**

_Answer:_ TODO

---

## Sign-Off

| Role | Name | Date | Notes |
|---|---|---|---|
| Spec author | | | |
| Security reviewer (Sparky) | | | |
| Merge owner | | | |

<!-- TODO: expand this checklist as new risk patterns are discovered.
     Every postmortem and audit finding should be considered for a new question here.
     Candidates to add:
     - Slippage manipulation via flashloan sandwich
     - Selector collision with other active integrations
     - Cross-chain address aliasing risks
     - Handling of fee-on-transfer tokens
     - Behavior on protocol upgrade (proxy admin change on external contract)
     - Gas griefing via large return data from external call
-->
