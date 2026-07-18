# DRCEngine Requirements

## Required boundary

- Depend on `CircuiteFoundation` for engine, evidence, artifact, provenance,
  diagnostics, and design-object contracts.
- Expose `DRCExecuting` and make `DefaultDRCEngine` conform directly.
- Keep DRC-specific result, waiver, ARC, corpus assessment, and raw evidence models intact.
- Retain domain diagnostics and digest-bearing artifact records without a
  projection wrapper.
- Preserve fail-closed behavior for missing antenna rules and unassessed
  foundry references. ToolQualification owns trust and qualification decisions.

## Non-goals

- `CircuiteFoundation` does not become a DRC rule database.
- DRC does not claim that native rules equal a foundry deck.
- DRC does not own project state, approvals, or flow orchestration.

## Verification

`swift build` must pass in the package checkout. Targeted DRC tests should
continue to cover native rules, ARC, external adapters, persistence, waiver
gates, and artifact integrity.
