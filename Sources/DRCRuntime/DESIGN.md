# DRCRuntime

## Purpose and Scope
Parent: [DRCEngine](../../DESIGN.md). Compose declared backend capability, request binding and retained evidence.
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
| [DRCNative](../DRCNative/DESIGN.md) | depends on | Native profile mapping | Actual execution composition | Capability declaration must match execution |
| [DRCAdapters](../DRCAdapters/DESIGN.md) | depends on | Direct external admission | Existing external backend lane | Unsupported policy fails before I/O |

## Architecture
```text
request -> capability admission -> bound inputs -> backend -> retained profile check -> artifact commitment
```

## Contracts and Invariants
Admission precedes input capture and backend dispatch. Returned request electrical context must equal dispatched context. Existing request digest commits the required options field; environment digest retains its existing meaning. Corpus remains geometric.

## State, Ownership, and Lifecycle
Context and capability are immutable values. Admission introduces no shared mutable
state, resources or target-dependent isolation. Existing execution owners retain lifecycle.

## Failure, Concurrency, and Constraints
Unsupported context is typed refusal; no inference, decoder fallback or success
substitution is introduced. Existing cancellation and resource limits remain in force.

## Verification and Change Impact
DefaultDRCEngineTests owns incapable custom refusal and capable custom retained-profile mismatch. Native tests own actual persisted execution.
Test owners: [Native](../../Tests/DRCNativeTests), [Runtime](../../Tests/DRCRuntimeTests),
[Adapters](../../Tests/DRCAdaptersTests). Changes require direct backend and Runtime admission proof.
