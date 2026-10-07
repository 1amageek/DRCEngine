# DRC Electrical Context

## Purpose and Scope
Parent: [DRCCore](../DESIGN.md). No children. Own the portable, explicit electrical
semantics requested alongside physical DRC.

## Responsibilities and Boundaries
Own geometric and deviceAwareMOS identities, required wire representation and
declared capability admission. Native mapping belongs to DRCNative; geometry and
device preparation belong to LayoutVerify. Poly-resistor expansion is outside this contract.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [DRCCore](../DESIGN.md) | parent | Request options, backend protocol and typed error | Portable request composition | No LayoutVerify dependency enters Core |
| [DRCNative](../../DRCNative/DESIGN.md) | used by | Mapping and direct admission | Actual standard-mask execution | Device recognition remains lower-owned |
| [DRCAdapters](../../DRCAdapters/DESIGN.md) | used by | Direct external refusal | External process admission | Unsupported context cannot launch |
| [DRCRuntime](../../DRCRuntime/DESIGN.md) | used by | Capability and retained profile truth | Backend dispatch and artifact commitment | Retained profile must equal requested profile |

## Architecture
```text
required options field -> required backend capability -> admit or typed refusal
```

## Contracts and Invariants
DRCElectricalContext is a String Codable value with geometric and deviceAwareMOS.
The DRCOptions constructor defaults to geometric and encodes it explicitly.
Persisted options require the field; missing or unknown values refuse decoding.
Every backend explicitly declares supportedElectricalContexts; there is no default
capability extension. Unsupported context fails before input I/O. Raw mask, rules
and technology are unchanged; a context selects electrical preparation only.
Runtime rejects a returned request that changes the dispatched profile. Existing
request commitments retain this option without changing environment-digest semantics.

## State, Ownership, and Lifecycle
Immutable Sendable values; no shared mutable state or additional lifetime.

## Failure, Concurrency, and Constraints
Unknown or missing wire context is a decoding failure. Unsupported backend context
is DRCError.unsupportedElectricalContext. Existing execution budgets remain caller-owned.

## Verification and Change Impact
[DRCRequestValidationTests](../../../Tests/DRCRuntimeTests/DRCRequestValidationTests.swift)
owns codec refusal and defaults. Direct Native/Magic refusal and Runtime custom
capability tests prove admission; actual Native standard-mask tests prove semantics.
