# DRCNative

## Purpose and Scope
Parent: [DRCEngine](../../DESIGN.md). Map explicitly selected electrical context to the existing native layout owner while preserving original physical mask and technology.
Children: None.

## Responsibilities and Boundaries
Existing module responsibilities remain governed by the parent package contract;
the detailed change scope here is its electrical-context integration boundary.
Layout geometry, device recognition and physical rule semantics remain lower-owner contracts.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [DRCEngine](../../DESIGN.md) | parent | Existing package responsibilities | Unchanged module responsibilities remain defined by package composition | This change owns only context integration |
| [ElectricalContext](../DRCCore/ElectricalContext/DESIGN.md) | depends on | Explicit profile and capability admission | Single authority for portable context semantics | No policy inference or legacy decoding |
| [DRCRuntime](../DRCRuntime/DESIGN.md) | used by | Dispatch and retained profile truth | Actual execution composition | Capability declaration must match execution |
| [LayoutVerify](../../../semiconductor-layout/Sources/LayoutVerify/DESIGN.md) | depends on | Explicit device preparation and full-mask rules | Existing native geometry owner | Raw mask and technology remain unchanged |

## Architecture
```text
options context -> LayoutElectricalContext -> full-mask DRC + prepared electrical snapshot
```

## Contracts and Invariants
LayoutGDSDRCBackend supports geometric and deviceAwareMOS for standard masks and LayoutDocument JSON. NativeDRCBackend rectangle JSON supports geometric only. Both direct public run paths admit capability before input I/O. Device preparation failures remain blocking diagnostics.

## State, Ownership, and Lifecycle
Context and capability are immutable values. Admission introduces no shared mutable
state, resources or target-dependent isolation. Existing execution owners retain lifecycle.

## Failure, Concurrency, and Constraints
Unsupported context is typed refusal; no inference, decoder fallback or success
substitution is introduced. Existing cancellation and resource limits remain in force.

## Verification and Change Impact
LayoutGDSDRCBackendTests owns same-GDS paired profiles, real metal bypass, unsupported preparation and persisted native execution. NativeDRCBackendTests owns direct refusal.
Test owners: [Native](../../Tests/DRCNativeTests), [Runtime](../../Tests/DRCRuntimeTests),
[Adapters](../../Tests/DRCAdaptersTests). Changes require direct backend and Runtime admission proof.
