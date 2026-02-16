# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-06)

**Core value:** Researchers should be able to discover, install, understand, and use epicTreeGUI without prior knowledge of the Rieke Lab system or legacy epoch tree tools.
**Current focus:** Phase 0 - Testing & Validation

## Current Position

Phase: 01 of 4 (Foundation & Legal)
Plan: 3 of 3 in current phase
Status: In progress
Last activity: 2026-02-16 - Completed 01-01-PLAN.md (Repository cleanup)

Progress: [████░░░░░░] ~44% (Phase 0 & 00.1 complete, Phase 01 nearly complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 11
- Average duration: 6.5 min
- Total execution time: 1.33 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 0 (Testing) | 5 | 58min | 12min |
| 00.1 (Bug Fixes) | 4 | 12min | 3min |
| 01 (Foundation) | 2 | 5min | 2.5min |

**Recent Trend:**
- Last 5 plans: 00.1-02 (2min), 00.1-03 (3min), 00.1-04 (4min), 01-02 (2min), 01-01 (3min)
- Trend: Consistent 2-4min execution continues for focused plans
- Phase 01 progress: 2 of 3 plans complete (cleanup + legal files)

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

**From 00.1-01:**
- Simplified .ugm architecture: isSelected flags on epochs are source of truth (mask built only on save/load)
- Auto-load default for LoadUserMetadata: silent if no .ugm exists, prints message when found
- Command window warnings show selection counts to prevent silent data exclusion
- Three-file architecture: .mat (raw data), .ugm (selection state), workspace (active tree)

**From 00.1-02:**
- questdlg for MATLAB compatibility: Use questdlg() vs uiconfirm() for pre-R2020a support
- Close handler updates latest .ugm (not create new) when saving changes
- Combined task implementation: Tasks 1 & 2 implemented atomically due to interdependence

**From 00.1-03:**
- Test isolation with fresh tree: Each test creates fresh tree instance to prevent state leakage
- Anti-pattern documentation in tests: Test suite explicitly documents direct epoch modification anti-pattern
- Graceful test skipping: Tests use assumeTrue/assumeNotEmpty to skip when data unavailable

**From 00.1-04:**
- Comprehensive architecture doc: Created 1082-line SELECTION_STATE_ARCHITECTURE.md covering storage, propagation, persistence, Python integration, and anti-patterns
- Simplified architecture emphasis: Documented one-time mask building (no real-time sync) throughout all docs
- Python integration section: Added scipy.io examples for RetinAnalysis/DataJoint workflows reading .ugm files

**From 01-01:**
- Repository organization: Move legacy code to docs/legacy/, development docs to docs/dev/, organize test scripts into tests/debug/ and tests/verification/
- Clean root directory: Reduce from 60+ items to 11 items (6 files + 5 directories)
- Python code removal: Remove Python pipeline code (new_retinanalysis/, python_export/) as it's not part of the MATLAB tool distribution
- Execution coordination: Some work was done in Plan 01-02 commit (cb86a55) before Plan 01-01 execution, but final state matches requirements

**From 01-02:**
- Use 'The epicTreeGUI Authors' as copyright holder placeholder (standard for collaborative projects)
- Add explicit subdirectories only in install.m (not genpath) to avoid polluting path with test/doc directories
- Include optional path saving with user confirmation in install.m (respects different installation preferences)
- Verify installation by checking which() returns paths from install directory

### Pending Todos

**Test Execution:**
- Run test_selection_state.m in MATLAB environment (25 test cases total)
- Run test_ugm_persistence.m in MATLAB environment
- Verify all tests pass or skip gracefully if data unavailable
- Add test results to TESTING_REPORT.md

### Blockers/Concerns

**BUG-001 (RESOLVED):** Selection state not persisting/propagating
- Root cause: Not a bug in epicTreeTools - test code was modifying returned copies instead of using setSelected() API
- Resolution: Verified correct implementation, added .ugm persistence system
- Completed: 2026-02-15 via Phase 00.1 Plan 01

### Roadmap Evolution

- **Phase 0.1 inserted after Phase 0:** Critical Bug Fixes - Selection State (URGENT)
  - Reason: Phase 0 testing discovered BUG-001 that breaks core filtering functionality
  - Impact: Must fix before documentation phase (Phase 1) since docs would describe broken behavior
  - Status: COMPLETE - All 4 plans finished 2026-02-16 (verification, GUI integration, tests, docs)

## Session Continuity

Last session: 2026-02-16
Stopped at: Completed 01-01-PLAN.md (Repository cleanup)
Resume file: None
Next: Continue Phase 01 - Foundation & Legal (plan 03 remaining: README and quickstart)
