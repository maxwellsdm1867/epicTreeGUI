# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-06)

**Core value:** Researchers should be able to discover, install, understand, and use epicTreeGUI without prior knowledge of the Rieke Lab system or legacy epoch tree tools.
**Current focus:** Phase 0 - Testing & Validation

## Current Position

Phase: 0 of 4 (Testing & Validation)
Plan: 4 of TBD in current phase
Status: In progress
Last activity: 2026-02-08 - Completed 00-03-PLAN.md (analysis function validation)

Progress: [███░░░░░░░] ~30% (estimated, Phase 0 scope TBD)

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: 14 min
- Total execution time: 0.95 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 0 (Testing) | 4 | 57min | 14min |

**Recent Trend:**
- Last 5 plans: 00-01 (2min), 00-02 (36min), 00-03 (4min), 00-04 (15min)
- Trend: Variable 2-36min per plan depending on complexity

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Public GitHub release: Make tool available to broader neuroscience community
- Documentation over features: 95% functional, need usability not features
- Defer v1.1 enhancements: Ship complete docs faster than adding features
- Remove old_epochtree/: Legacy reference code not needed for users

**From 00-01:**
- Use absolute paths for test data (simpler than relative path resolution)
- Multi-level tree in tests (enables deeper navigation validation)
- Reset selection state before each test (prevents test interference)

**From 00-02:**
- Use parameterized tests (TestParameter) for testing multiple splitters efficiently
- Graceful H5 data handling with assumeFail() when data unavailable
- Validate no epochs lost: sum of leaf epoch counts must equal total
- Test multi-arg splitters separately (not parameterized)

**From 00-03:**
- Use floating-point tolerance (AbsTol=1e-10) for baseline comparisons to handle numerical precision differences
- Gracefully skip tests for functions requiring specific data types rather than failing hard
- Generate baselines as separate MAT files per function for independent verification
- Document baseline generation extensively to prevent incorrect updates during test failures

**From 00-04:**
- TreeNavigationUtility controls actual GUI checkboxes via widget callbacks (not just setSelected)
- Tests use programmatic interaction without App Testing Framework
- Fresh GUI instance per test avoids state leakage
- Tests access public API only (use highlightCurrentNode to trigger callbacks)

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-02-08
Stopped at: Completed 00-03-PLAN.md (analysis function validation)
Resume file: None
Next: Continue Phase 0 testing as needed
