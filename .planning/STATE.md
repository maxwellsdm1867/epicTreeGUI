# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-06)

**Core value:** Researchers should be able to discover, install, understand, and use epicTreeGUI without prior knowledge of the Rieke Lab system or legacy epoch tree tools.
**Current focus:** Phase 0 - Testing & Validation

## Current Position

Phase: 0 of 4 (Testing & Validation)
Plan: 5 of 5 in current phase
Status: Phase complete
Last activity: 2026-02-08 - Completed 00-05-PLAN.md (end-to-end workflow testing and report finalization)

Progress: [████░░░░░░] ~40% (Phase 0 complete, ready for Phase 1)

## Performance Metrics

**Velocity:**
- Total plans completed: 5
- Average duration: 12 min
- Total execution time: 0.97 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 0 (Testing) | 5 | 58min | 12min |

**Recent Trend:**
- Last 5 plans: 00-01 (2min), 00-02 (36min), 00-03 (4min), 00-04 (15min), 00-05 (1min)
- Trend: Variable 1-36min per plan depending on complexity
- Phase 0 complete with average 12min/plan

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

**From 00-05:**
- WorkflowTest validates complete researcher workflows (not just isolated functions)
- Integration tests verify load→build→analyze pipelines work end-to-end
- TESTING_REPORT.md serves as Phase 0's primary deliverable
- Test suite ready for execution but not yet run (requires MATLAB environment)

### Pending Todos

None - Phase 0 complete.

### Blockers/Concerns

**BUG-001 (CRITICAL):** Selection state not persisting/propagating
- Phase 0.1 inserted to fix before proceeding to documentation
- See BUGS_FOUND_PHASE0.md for full analysis

### Roadmap Evolution

- **Phase 0.1 inserted after Phase 0:** Critical Bug Fixes - Selection State (URGENT)
  - Reason: Phase 0 testing discovered BUG-001 that breaks core filtering functionality
  - Impact: Must fix before documentation phase (Phase 1) since docs would describe broken behavior
  - Status: Not planned yet

## Session Continuity

Last session: 2026-02-08
Stopped at: Completed 00-05-PLAN.md (end-to-end workflow testing and TESTING_REPORT.md finalization)
Resume file: None
Next: Phase 0 complete - ready to begin Phase 1 (Documentation & Core Examples)
