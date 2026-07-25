# DRCEngine Remaining Tasks

Updated: 2026-07-26

The current tasks are derived from the executable
`DRCCapabilitySnapshot.openMilestones` contract, not from structure-only
inspection.

## Remaining tasks

| ID | Priority | Owner | Task | Exit criteria |
|---|---|---|---|---|
| DRC-1 | P1 | DRCEngine | Broaden Magic rule import for real-deck cut-count variants and remaining typed materialization families. | Multi-numeric and ambiguous cut-stack cases, required future `templayer` operations, golden foundry cases, skipped-rule diagnostics, and Native/Magic agreement are retained; `--require-complete` passes for the selected supported deck scope. |
| DRC-2 | P1 | DRCEngine and oracle workflow | Produce retained foundry-layout and independent-oracle observations for native antenna lowering/evaluation. | Exact source/profile/native-rule, executable, deck, technology, corpus, comparison, agreement, and artifact digests are retained and accepted as raw ToolQualification inputs. |
| DRC-3 | P2 | DRCEngine | Broaden standard-mask input lanes into larger foundry-oriented coverage. | GDSII/OASIS/CIF/DXF cases cover hierarchy, scale, rule families, malformed input, and native/external equivalence with deterministic budgets. |
| DRC-4 | P2 | DRCEngine | Add larger public-PDK benchmark suites and regression budgets. | Benchmarks define input size, rule mix, latency, memory/allocation targets, deterministic results, and failure thresholds. |
| DRC-5 | P2 | DRCEngine and layout-operation owners | Expand repair-hint normalization to every active diagnostic kind. | Each diagnostic maps to a typed, executable, benchmarked layout operation or an explicit non-executable reason, followed by DRC/LVS verification gates. |
| DRC-6 | P2 | DRCEngine security boundary | Add external trust-root rotation and key IDs for multi-tenant workflows. | Signed artifact verification supports explicit key identity, rotation, revocation/failure behavior, and retained audit evidence without accepting an unknown key. |

## External prerequisites

ToolQualification and the composing flow decide production trust. A native
clean result or committed regression corpus is not foundry qualification.

## Evidence reviewed

- `GOAL_STATUS.md`
- `README.md`
- `Sources/DRCCore/DRCCapabilitySnapshotProvider.swift`
- Native, standard-mask, Magic, antenna, corpus, and repair-hint paths
- `Sources` incomplete-implementation marker scan
