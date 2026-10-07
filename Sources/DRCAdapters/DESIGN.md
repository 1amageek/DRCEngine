# DRCAdapters

## Purpose and Scope
Parent: [DRCEngine](../../DESIGN.md). Own direct external tool admission and execution.
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

## Architecture
```text
request -> capability admission -> external process
```

## Contracts and Invariants
Magic declares geometric only and refuses MOS context before file capture or process launch. No ignored electrical policy is forwarded as successful execution.

## State, Ownership, and Lifecycle
Context and capability are immutable values. Admission introduces no shared mutable
state, resources or target-dependent isolation. Existing execution owners retain lifecycle.

## Failure, Concurrency, and Constraints
Unsupported context is typed refusal; no inference, decoder fallback or success
substitution is introduced. Existing cancellation and resource limits remain in force.

## Verification and Change Impact
MagicDRCAdapterTests owns pre-I/O refusal and existing process behavior.
Test owners: [Native](../../Tests/DRCNativeTests), [Runtime](../../Tests/DRCRuntimeTests),
[Adapters](../../Tests/DRCAdaptersTests). Changes require direct backend and Runtime admission proof.
