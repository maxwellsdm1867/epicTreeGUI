# Phase 0: Testing & Validation - Context

**Gathered:** 2026-02-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Verify all analysis functions and critical workflows work correctly with real data before proceeding to documentation. This phase establishes confidence that the tool functions as intended through automated testing and validation.

</domain>

<decisions>
## Implementation Decisions

### Test coverage scope
- **Primary goal:** Validate correctness, not just prove nothing breaks
- **Critical function categories to validate:**
  - Analysis functions (getMeanResponseTrace, getResponseAmplitudeStats, getCycleAverageResponse, getLinearFilterAndPrediction, MeanSelectedNodes)
  - Tree navigation (childAt, parentAt, getAllEpochs, leafNodes, childBySplitValue)
  - Data extraction (getSelectedData, getResponseMatrix)
  - All 14+ splitter functions
- **Analysis validation depth:** Claude's discretion - choose validation approach based on function complexity (mix of output format validation and correctness checks)
- **GUI testing:** Yes - write automated GUI tests, not just backend validation
- **Command-line testing utility:**
  - Build testing utility for keyboard/command-line tree navigation
  - Scope: Testing utility only (lives in tests/ directory)
  - Must provide programmatic access to:
    - Navigate tree structure (move to different nodes)
    - Control checkbox selection state (not just setSelected() - actual GUI checkboxes)
    - Test tree interaction without manual clicking
  - Reference: `/Users/maxwellsdm/Documents/GitHub/epicTreeGUI/tests/test_selection_navigation.m`
- **MCP MATLAB Server:** Always use MCP MATLAB tools for testing (mcp__matlab__run_matlab_test_file, mcp__matlab__evaluate_matlab_code, etc.) - NOT bash matlab commands

### Test data strategy
- **Primary data source:** Real experiment data (actual exported neurophysiology data)
- **Test data bundling:** Yes - commit test data file to repository
- **Path handling:** Hardcoded relative path (e.g., 'test_data/sample_data.mat' from repo root)
- **Data preparation workflow:**
  - Pre-Phase 0 setup: User provides H5 file → convert to MAT using RetinAnalysis → commit .mat file
  - Check existing loading mechanism to understand how data is loaded
  - Move CLAUDE.md to `.claude/` directory for proper organization

### Bug handling approach
- **Default action when bugs found:** Fix AND document
- **Bug documentation:** Both test report (TESTING_REPORT.md) AND detailed git commit messages
- **Issues beyond bugs:** Phase 0 testing should also identify:
  - Performance problems (slow operations, memory issues, inefficient algorithms)
  - Design inconsistencies (API inconsistencies, naming mismatches, pattern violations)
- **Non-bug issue handling:** Fix AND document (same as bugs - address immediately)

### Validation success criteria
- **Phase 0 completion focus:** Automated tests only (manual testing comes later)
- **Success threshold:** No test failures (tests can be incomplete, but nothing that runs should fail)
- **Baseline for future:** Yes - capture current behavior as baseline
- **Baseline capture method:** Golden outputs (save output files from test runs as reference files)

### Claude's Discretion
- Analysis function validation depth (choose between format checks vs correctness validation per function)
- Exact test organization and structure
- Specific golden output format and comparison logic
- Test utility API design details

</decisions>

<specifics>
## Specific Ideas

- Command-line testing utility for easier interaction with tree during validation
- Use MCP MATLAB server tools exclusively (not bash commands)
- Golden output files for baseline behavior capture
- TESTING_REPORT.md to track all bugs, performance issues, and design inconsistencies found

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 00-testing-validation*
*Context gathered: 2026-02-07*
