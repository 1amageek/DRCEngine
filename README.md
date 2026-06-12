# DRCEngine

Design rule checking engine with a protocol-composed backend model. The pure Swift
backends are the core signoff path; Magic is an optional, headless-batch-only
adapter kept for oracle checks and PDK-deck compatibility.

## Modules

| Module | Responsibility |
|---|---|
| `DRCCore` | `DRCRequest` / `DRCResult` / `DRCViolation` models, `DRCBackend` protocol, typed errors |
| `DRCPureSwift` | `PureSwiftDRCBackend` (`pure-swift`) and `LayoutGDSDRCBackend` (`pure-swift-gds`) |
| `DRCParsers` | Magic report parsing into typed violations |
| `DRCAdapters` | Magic batch invocation (`drc.tcl`), tool-gated |
| `DRCPersistence` | DRC artifact persistence |
| `DRCRuntime` | Backend registry and engine composition (`DefaultDRCEngine`) |
| `DRCEngine` | Umbrella module |
| `DRCCLICore` / `drcengine` | Testable CLI core + executable |

## Standard-input backend: `pure-swift-gds`

`LayoutGDSDRCBackend` checks a GDSII file against a `LayoutTechDatabase` JSON rule
deck using the same `LayoutVerify` DRC kernel that drives the layout editor's live
verdicts — the standalone CLI and the editor cannot drift because they share one
kernel. Set `DRCRequest.technologyURL` to select it programmatically.

```bash
# Pure Swift on standard inputs (GDS + tech deck)
drcengine --layout design.gds --tech technology.json

# Explicit backend override; default without --tech is magic
drcengine --layout design.gds --backend pure-swift-gds --tech technology.json
```

## Result convention

`result.success` means the check **ran**. The design verdict (violations or clean)
lives in the diagnostics; only the fold of both counts as a pass. A missing summary
or report is never interpreted as clean.

## Build & test

```bash
swift build
swift test   # Magic-gated suites skip themselves when Magic is absent
```
