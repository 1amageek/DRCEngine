# DRC CLI Core

## Purpose and Scope
Parent: [DRCEngine](../../DESIGN.md). No children. Own the testable command-line
frontend used by the `drcengine` executable. This change exposes an explicit
electrical context for a single DRC execution; corpus authority remains unchanged.

## Responsibilities and Boundaries
Parse `--electrical-context geometric|deviceAwareMOS` case-sensitively into
`DRCElectricalContext` and forward it to `DRCRequest.options.electricalContext`.
Omission selects the constructor's geometric default, which remains explicit in
the retained wire representation. Own minimal `--help` output advertising this
contract. Backend capability admission, context mapping, geometry, persistence
and corpus case/oracle semantics belong to their existing owners.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [DRCEngine](../../DESIGN.md) | parent | Public executable composition | Developer and agent entry point | Keep the single-run flag separate from corpus authority |
| [DRCCore](../DRCCore/DESIGN.md) | depends on | Typed context, required wire field and backend capability | Request semantics | No decoder fallback or inferred context |
| [DRCRuntime](../DRCRuntime/DESIGN.md) | depends on | Admission before input I/O and retained request equality | Actual execution | CLI parsing cannot substitute for backend admission |
| [DRCNative](../DRCNative/DESIGN.md) | depends on | Standard-layout native context mapping | Real native success path | Paired MOS geometry qualification is owned by Native tests |

## Architecture
```text
arguments -> typed CLI options -> DRCRequest -> DefaultDRCEngine
--help -----------------------> documented single-run contract
DefaultDRCEngine -> backend -> retained execution report / manifest -> CLI output
```

## Contracts and Invariants
Both accepted values preserve their exact typed meaning through request creation.
Unknown, empty, whitespace-only, missing or option-token values fail explicitly;
the frontend never infers a context from devices, file names or selected backend.
Only the exact `--help` invocation bypasses execution. A help result performs no
input or artifact I/O. The existing geometric corpus path receives no new override.
Unsupported backend/context pairs fail through the runtime's typed capability
gate before input capture, backend execution or artifact creation.

## State, Ownership, and Lifecycle
Parsed values and requests are immutable. Existing output buffering uses its
common `Mutex` owner; this change introduces no shared mutable state. Tests use
the existing serialized CLI suite and its unique temporary-directory helpers.

## Failure, Concurrency, and Constraints
Parser errors retain `DRCCLIError`. Invocation writes the failure to stderr and
returns exit code 1. Completed DRC verdicts retain exit codes 0 or 2. Backend
timeouts, cancellation and resource limits retain their existing owners.

## Verification and Change Impact
[DRCCLIElectricalContextTests](../../Tests/DRCCLICoreTests/DRCCLIElectricalContextTests.swift)
exercise typed parsing, explicit omission, actual invocation refusal, help,
real standard-layout native execution and persisted context/request digests.
The same source bytes, technology and output directory are used for both native
contexts so request-digest differences can be attributed to the declared field.
Existing single-run CLI success/failure/JSON-output and argument-cursor tests
cover unchanged command and artifact behavior. Core tests own strict decoding
and capability validation; Native tests own paired geometric/MOS mask behavior.
Root owns stable build/runtime evidence and package/design index composition.
