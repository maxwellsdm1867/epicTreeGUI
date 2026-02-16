# Phase 1: Foundation & Legal - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the repository legally releasable with a working installation path. Deliverables: MIT LICENSE, professional README, clean root directory (<5 loose files), install.m for path setup, one working example with bundled sample data. User onboarding tutorials and comprehensive docs are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Repo cleanup strategy
- Move `old_epochtree/` to `docs/legacy/` (preserve as reference, out of the way)
- Root files: README.md, LICENSE, CITATION.cff, CHANGELOG.md, install.m, .gitignore — standard open-source layout
- Move all other markdown files into `docs/`
- Remove `new_retinanalysis/` entirely — Python pipeline code is not part of this MATLAB tool
- Move all scattered test files into `tests/`

### README tone & content
- Tone: Academic professional — formal, precise language, like a methods paper
- Identity: "A MATLAB GUI for browsing and analyzing neurophysiology epoch data" — tool-first, not migration-first
- Quick start example: Load → Build tree → Extract data with getSelectedData → Analyze (programmatic workflow, not GUI launch)
- Legacy mention: Brief one-line note that it replaces the legacy Java epoch tree system — helps existing users find it, doesn't dominate
- Reference file `riekesuitworkflow.md` describes the old workflow — use for context when writing README

### Example & sample data
- Bundle trimmed real data (small subset of real experiment epochs, authentic but minimal)
- Sample data location: `examples/data/` — examples are self-contained
- Bundled example demonstrates full analysis workflow: load → build → select → getSelectedData → plot mean trace
- Example should be end-to-end science, not just tree navigation

### Claude's Discretion
- Path referencing approach in example scripts (relative to script vs relative to project root)
- install.m implementation details
- Exact README section ordering and formatting
- Which specific epochs to extract for sample data
- CITATION.cff content (standard academic metadata)

</decisions>

<specifics>
## Specific Ideas

- `riekesuitworkflow.md` at repo root describes the legacy Rieke Lab workflow — use as reference for README context and the "replaces legacy system" mention
- Sample data should be small enough to commit directly (<10 MB per EXAM-03 requirement)
- The quick start should show the programmatic power: building tree with splitters, extracting filtered data, producing a scientific result

</specifics>

<deferred>
## Deferred Ideas

- Migration guide from legacy epochTreeGUI — Phase 3
- Detailed tutorials and multiple example scripts — Phase 2
- Screenshots in README — Phase 4

</deferred>

---

*Phase: 01-foundation-legal*
*Context gathered: 2026-02-15*
