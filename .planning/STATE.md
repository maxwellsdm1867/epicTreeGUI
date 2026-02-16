# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-06)

**Core value:** Researchers should be able to discover, install, understand, and use epicTreeGUI without prior knowledge of the Rieke Lab system or legacy epoch tree tools.
**Current focus:** Phase 05 - DataJoint Integration + Analysis Porting

## Current Position

Phase: 05 (DataJoint Integration - Export .mat from DataJoint Query Results)
Plan: 02 of 2 COMPLETE
Status: Phase 05 complete (pending human verification); epicAnalysis class ported; DataJoint trace display fixed
Last activity: 2026-02-16 - Completed Flask endpoint, UI button, tags in export; human verification pending

Progress: [███████░░░] ~70% (Phase 0, 00.1, 01, 05 complete; epicAnalysis ported; DJ trace fix)

## Performance Metrics

**Velocity:**
- Total plans completed: 14
- Average duration: 5.8 min
- Total execution time: 1.86 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 0 (Testing) | 5 | 58min | 12min |
| 00.1 (Bug Fixes) | 4 | 12min | 3min |
| 01 (Foundation) | 3 | 10min | 3.3min |
| 05 (DataJoint) | 2 | 9min | 4.5min |

**Recent Trend:**
- Last 5 plans: 01-01 (3min), 01-02 (2min), 01-03 (5min), 05-01 (4min), 05-02 (5min)
- Trend: Integration plans (endpoint + UI + tags) efficient at 5min
- Phase 05 complete: Both plans done, pending human verification

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

**From 01-03:**
- Use Python + scipy.io for sample data generation (MATLAB not available via CLI)
- Create concise public README (112 lines) replacing verbose dev README (471 lines)
- Programmatic quickstart workflow (not GUI-based) for reproducible analysis
- Auto-run install.m in examples to ensure dependencies available
- Bundled sample data: 24 epochs, 364 KB, no H5 dependency (embedded response data)

**From 05-01:**
- scipy.io.savemat format='5' for maximum MATLAB compatibility (not v7.3 HDF5)
- Flatten nested JSON parameters to single-level dicts with underscore separators
- Store h5_path references only (no embedded waveform data) for small .mat files
- MEA experiments raise ValueError (single-cell patch only per Phase 05 scope)
- Animal/Preparation metadata merged into cell properties (9-to-5 level flattening)
- TDD RED-GREEN-REFACTOR cycle with 33 tests (26 unit + 7 integration)

**From 05-02:**
- Tags extracted at every hierarchy level using extract_tags() helper (strips DB-internal fields)
- Tags stored as [{user, tag}] in .mat file at experiment, cell, epoch_group, epoch_block, epoch levels
- Lazy import of export_mat inside Flask handler (doesn't need to be present at Flask startup)
- Blob responseType for axios binary .mat download (with blob-to-text error parsing)

**From epicAnalysis porting (2026-02-16):**
- Merged RFAnalysis + RFAnalysis2 into single `epicAnalysis.RFAnalysis()` with per-epoch statistics
- Ported 7 legacy functions: RFAnalysis, detectSpikes, baselineCorrect, differenceOfGaussians, singleGaussian, halfMaxSize, defaultParams
- All static methods under epicAnalysis class (namespace isolation, no naming conflicts)
- Plot color wrapping via `mod()` for >8 conditions
- 10 tests passing with real ExpandingSpots data (13 spot sizes, CenterSize=162.2)

**From DataJoint trace display fix (2026-02-16):**
- NAS_DATA_DIR and NAS_ANALYSIS_DIR now configurable via env vars (fallback to original hardcoded paths)
- Added path existence validation in get_trace_binary() and get_data_generic() with clear FileNotFoundError
- Added h5_path validation before dataset access (KeyError with descriptive message)

### Pending Todos

**Test Execution:**
- Run test_selection_state.m in MATLAB environment (25 test cases total)
- Run test_ugm_persistence.m in MATLAB environment
- Verify all tests pass or skip gracefully if data unavailable
- Add test results to TESTING_REPORT.md

**DataJoint Integration:**
- Verify end-to-end export in browser (human gate — Task 3 of 05-02)
- Design UGM mask import endpoint for DataJoint (send selection state back)
- Consider splitOnTag splitter for filtering epochs by DataJoint tags

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
- **Phase 5 added:** DataJoint integration — export .mat from DataJoint query results
  - Reason: Need intermediate layer to export DataJoint query results to epicTreeGUI standard .mat format
  - Approach: Add Flask endpoint (/results/export-mat) to SamarjitK/datajoint web app
  - DataJoint repo cloned at /Users/maxwellsdm/Documents/GitHub/datajoint, deps installed

## Session Continuity

Last session: 2026-02-16
Stopped at: Phase 05 complete (all code done, human verification pending)
Resume file: None
Next steps:
- Human verification: Start DataJoint app, run query, click "Export to epicTree", load in MATLAB
- Continue to Phase 2 (User Onboarding) after verification
- Design UGM mask import endpoint for DataJoint Tags table

### New Files Created This Session
- `src/analysis/epicAnalysis.m` — Static class with RFAnalysis, detectSpikes, baselineCorrect, DOG/Gaussian fitting, halfMaxSize
- `tests/test_epicAnalysis.m` — 10 tests, all passing with real H5 data

### Files Modified This Session (DataJoint repo)
- `datajoint/next-app/api/helpers/utils.py` — NAS_DATA_DIR/NAS_ANALYSIS_DIR configurable via env vars
- `datajoint/next-app/api/helpers/query.py` — Path validation in get_trace_binary() and get_data_generic()
