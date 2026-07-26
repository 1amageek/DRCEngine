# DRCEngine Remaining Tasks

Updated: 2026-07-26

The current package-owned tasks are derived from the executable
`DRCCapabilitySnapshot.openMilestones` contract and verified implementation
paths, not from structure-only inspection.

## Remaining tasks

| ID | Priority | Owner | Task | Exit criteria |
|---|---|---|---|---|
| DRC-3 | P2 | DRCEngine | Broaden standard-mask input lanes into larger foundry-oriented coverage. | GDSII/OASIS/CIF/DXF cases cover hierarchy, scale, rule families, malformed input, and native/external equivalence with deterministic budgets. |
| DRC-4 | P2 | DRCEngine | Add larger public-PDK benchmark suites and regression budgets. | Benchmarks define input size, rule mix, latency, memory/allocation targets, deterministic results, and failure thresholds. |
| DRC-5 | P2 | DRCEngine and layout-operation owners | Expand repair-hint normalization to every active diagnostic kind. | Each diagnostic maps to a typed, executable, benchmarked layout operation or an explicit non-executable reason, followed by DRC/LVS verification gates. |
| DRC-6 | P2 | DRCEngine security boundary | Add external trust-root rotation and key IDs for multi-tenant workflows. | Signed artifact verification supports explicit key identity, rotation, revocation/failure behavior, and retained audit evidence without accepting an unknown key. |

## External prerequisites

| Former ID | Owner | Required evidence |
|---|---|---|
| DRC-2 | DRC oracle workflow | Retained foundry layout plus an independently identified Magic/foundry oracle observation binding source/profile/native rule, executable, deck, technology, corpus, comparison, agreement, and artifact digests. |

ToolQualification and the composing flow decide production trust. A native
clean result or committed regression corpus is not foundry qualification.

## Completed P1 tasks

| ID | Completed | Evidence |
|---|---|---|
| DRC-1 | 2026-07-26 | Generic Magic import handles explicit and inferred cut stacks, prefix/suffix counts, multi-stack/multi-numeric declarations, and fail-closed ambiguous count/stack cases. Typed dependency-ordered `templayer` materialization covers and/or/and-not/xor/grow/grow-min/shrink/bloat-all/bridge/close/boundary/mask-hints, selected supported scopes pass `--require-complete`, and retained golden fixtures exercise positive and negative behavior. |

## Evidence reviewed

- `GOAL_STATUS.md`
- `README.md`
- `Sources/DRCCore/DRCCapabilitySnapshotProvider.swift`
- Native, standard-mask, Magic, antenna, corpus, and repair-hint paths
- `Sources` incomplete-implementation marker scan
