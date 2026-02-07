# Codebase Concerns

**Analysis Date:** 2026-02-06

## Tech Debt

### 1. Incomplete Analysis Function Suite
**Files:** `src/analysis/getMeanResponseTrace.m`, `src/analysis/getLinearFilterAndPrediction.m`, `src/analysis/getCycleAverageResponse.m`, `src/analysis/getResponseAmplitudeStats.m`

**Issue:** Analysis functions exist but are not fully tested with real data. Many contain placeholder parameter handling and incomplete stimulus reconstruction paths.

**Impact:**
- Analysis workflows from legacy system (RFAnalysis, LSTA, SpatioTemporalModel) depend on these utilities
- Current implementation may silently fail or produce incorrect results on real data
- 50+ legacy analysis functions still need adaptation from old_epochtree/

**Fix approach:**
- Systematically test each analysis function against real data (use `/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat`)
- Verify stimulus reconstruction and response alignment for drifting grating and noise stimulus protocols
- Create unit tests for edge cases (empty data, variable epoch lengths, missing response streams)
- Document which legacy functions have been ported vs. still need work

---

### 2. Hardcoded Data Paths and Configuration
**Files:** `src/config/getH5FilePath.m`, `epicTreeGUI.m` (lines 92-100), `src/loadEpicTreeData.m`

**Issue:** H5 file paths are constructed using hardcoded experiment name logic. Configuration assumes specific directory structure. No validation of file existence before attempting load.

**Impact:**
- Code breaks if experiment directory structure changes
- H5 file loading fails silently with confusing error messages
- Configuration system is minimal (epicTreeConfig.m is stub)

**Fix approach:**
- Implement robust configuration system with fallback paths
- Add file validation before attempting load operations
- Create detailed error messages for common path failures
- Document expected directory structure in epicTreeConfig.m

---

### 3. Legacy Code Dependency (old_epochtree/)
**Files:** `old_epochtree/` directory (20+ MB, Java-based reference code)

**Issue:** Legacy Java-based code remains in repository as reference. This creates path pollution issues (e.g., BUGFIX_TREE_GUI.md documents brace indexing errors caused by old graphicalTree.m shadowing new implementation).

**Impact:**
- Test scripts must explicitly remove old_epochtree from path (fragile setup)
- New developers easily load wrong version of classes
- Old analysis code is not MATLAB-native and uses different data structures
- Dead code maintenance burden

**Fix approach:**
- Move old_epochtree/ to separate archive repository or tag in git
- Create migration guide for porting old analysis functions
- Document which old code patterns are replaced by new equivalents
- Add startup.m check to warn if old code is in path

---

## Known Bugs

### 1. Variable-Length Epoch Data Not Robustly Handled
**Files:** `src/getResponseMatrix.m` (lines 94-100), `src/getSelectedData.m`

**Symptoms:** When epochs have variable length response data:
- Data gets padded with zeros silently
- Truncation happens without user notification
- Analysis functions may produce misleading results on padded data

**Trigger:** Loading data from H5 files where recordings have different lengths, or from experiments with variable stimulus/tail times

**Workaround:** Inspect response matrix dimensions before analysis. Add check:
```matlab
[data, epochs, fs] = getSelectedData(node, 'Amp1');
nUnique = length(unique(cellfun(@length, {epochs.responses})));
if nUnique > 1, warning('Variable response lengths detected'); end
```

**Fix approach:**
- Validate response length consistency during load
- Raise error instead of silently padding
- Document expected response length equivalence requirement

---

### 2. Stream Name Matching is Case-Sensitive and Fragile
**Files:** `src/getResponseMatrix.m` (line 118 helper), `src/getSelectedData.m`, all analysis functions

**Symptoms:**
- `getResponseMatrix(epochs, 'Amp1')` succeeds but `getResponseMatrix(epochs, 'amp1')` returns empty
- Wrong stream name produces warnings instead of errors
- No autocomplete or validation for valid stream names

**Trigger:** User specifies slightly different stream name than exported data

**Workaround:** Inspect first epoch to find exact stream names:
```matlab
ep = tree.allEpochs{1};
cellfun(@(r) r.device_name, ep.responses)
```

**Fix approach:**
- Case-insensitive stream matching with 'IgnoreCase' flag
- Return list of available streams if requested stream not found
- Add validation method: `validStreamNames = tree.getAvailableStreams()`

---

### 3. Epoch Flattening Creates Detached References
**Files:** `src/tree/epicTreeTools.m` (lines 656-700 extractAllEpochs method)

**Symptoms:**
- When tree is reorganized via buildTree(), individual epochs lose parent hierarchy references
- Fields like `epoch.expInfo`, `epoch.groupInfo`, `epoch.blockInfo` may become stale
- Analysis functions relying on parent information can fail

**Trigger:** Accessing parent experiment metadata from flattened epoch list

**Workaround:** Store parent info in root node's custom property before flattening

**Fix approach:**
- Maintain bidirectional references during flattening
- Document which parent references are guaranteed vs. optional
- Add integrity check: `tree.validateParentReferences()`

---

## Security Considerations

### 1. H5 File Path Injection Risk
**Files:** `src/loadH5ResponseData.m`, `src/getResponseMatrix.m`

**Risk:** H5 file paths come from epoch struct fields (`h5_path`) which could theoretically be corrupted/modified. No path validation before HDF5 operations.

**Current mitigation:**
- Path is constructed from epoch metadata (which comes from export)
- File system access limitations prevent traversal attacks

**Recommendations:**
- Add path validation using `isfile()` before hdf5read()
- Verify H5 path is within expected data directory
- Log all H5 file access attempts

---

### 2. Struct Field Access Without Validation
**Files:** Multiple - all analysis functions, data extraction functions

**Risk:** Code uses `epoch.field` pattern without checking `isfield()` first. Corrupted export files or schema changes could cause crashes or access wrong fields.

**Current mitigation:**
- Data comes from controlled export process
- MATLAB 's `.` notation returns empty for missing fields (doesn't error)

**Recommendations:**
- Use helper function `safeGetField()` for critical paths
- Add data validation at load time: `validateEpochStructure(epoch)`
- Document required vs. optional fields in DATA_FORMAT_SPECIFICATION.md

---

## Performance Bottlenecks

### 1. Tree Building is O(N * M) for Nested Splits
**Files:** `src/tree/epicTreeTools.m` (buildTreeWithSplittersRecursive method, ~100 lines)

**Problem:** For each split level, all epochs are re-scanned and grouped. With 5 split levels and 2000 epochs:
- Level 1: 2000 comparisons
- Level 2: 2000 comparisons per level-1 group
- Total: ~250,000 comparisons for a 5-level tree

**Cause:** `groupBySplitter()` iterates all epochs to build groups at each level

**Current typical performance:** Tree with 2000 epochs, 5 levels: ~1-2 seconds (acceptable for one-time operation)

**Improvement path:**
- Cache split results if same splitter used twice
- Pre-sort epochs by splitKey before recursive splitting
- For large datasets (>10k epochs), implement lazy tree building

---

### 2. Large Response Matrices in Memory
**Files:** `src/getResponseMatrix.m` (pre-allocates full matrix, line 80)

**Problem:** Loading 1000 epochs × 100,000 samples = 100M element matrix = 800 MB (for double precision). Multiple analyses on same node create memory copies.

**Current typical performance:** 1915 epochs × 30,000 samples = 1.8 GB peak memory

**Improvement path:**
- Implement on-demand H5 loading instead of full matrix
- Add chunked processing option for large datasets
- Cache mean/median traces instead of full matrix for statistical analysis

---

### 3. GUI Tree Rendering Unoptimized for Large Leaf Counts
**Files:** `src/gui/epicGraphicalTree.m` (graphicalTree rendering)

**Problem:** With 1000+ leaf nodes (individual epochs), GUI may lag when expanding branches. Each leaf node creates graphics objects.

**Improvement path:**
- Lazy load leaf nodes (don't render until expanded)
- Implement virtual scrolling for large node lists
- Cache rendered nodes

---

## Fragile Areas

### 1. Splitter Function Interface Inconsistency
**Files:** `src/tree/epicTreeTools.m` (lines 1542-1900 contain 20+ splitter functions)

**Why fragile:**
- Splitters return different types: sometimes string, sometimes numeric, sometimes cell array
- Some splitters return concatenated strings (e.g., "RGC\ON-parasol"), others single values
- No type checking in `groupBySplitter()` - relies on struct key conversion

**Safe modification:**
- Add pre/post validation in buildTreeWithSplitters: validate all splitters return consistent types
- Create splitValidator function that checks return value type and format
- Add tests for each built-in splitter against both synthetic and real data

**Test coverage:** Splitters are tested minimally - only basic case in test_splitters.m

---

### 2. Data Format Version Compatibility
**Files:** `src/loadEpicTreeData.m` (lines 44-56 version check)

**Why fragile:**
- Only checks format_version == '1.0'
- If export format changes, loader has no migration path
- No schema validation beyond presence checks

**Safe modification:**
- Create explicit schema validator in separate function
- Add migration functions for format_version transitions
- Store schema version separate from data version

---

### 3. Custom Property Access Pattern
**Files:** `src/tree/epicTreeTools.m` (putCustom/getCustom, lines 468-520)

**Why fragile:**
- Custom properties stored in struct field dynamically
- No type checking on values stored
- Old code accessing `.custom.fieldname` directly bypasses controlled access

**Safe modification:**
- Make `custom` property private (SetAccess=private already done, good)
- Add getter/setter validation for known keys
- Document list of standard custom keys in class

---

## Scaling Limits

### 1. Single-Experiment Limit
**Current capacity:** Tree structure designed for single .mat file (single experiment)

**Limit:** With ~2000 epochs per experiment, tree handles this well. No support for combining multiple experiments into single browser.

**Scaling path:**
- Implement multi-experiment root node that loads multiple .mat files
- Create experiment-level grouping above current root

---

### 2. Response Stream Count
**Current capacity:** Handles 5-10 response streams (Amp1, Amp2, Cell, Frame Monitor, etc.)

**Limit:** If >20 streams per epoch, response struct array becomes unwieldy

**Scaling path:**
- Switch to cell array of responses with device_name lookup
- Implement lazy-load for response streams

---

## Dependencies at Risk

### 1. MATLAB Compatibility Range
**Risk:** Code uses MATLAB R2019a+ syntax but no version check

**Current indicators:**
- Uses string arrays (R2016b+)
- Uses inputParser (R2007b+)
- Uses class handle semantics (assumed R2008a+)

**Recommendation:** Add version check at startup:
```matlab
matlabVersion = version('-release');
if str2double(matlabVersion(1:4)) < 2019
    error('MATLAB R2019a or later required');
end
```

---

### 2. HDF5 Toolbox Optional Dependency
**Files:** `src/loadH5ResponseData.m`

**Risk:** Uses hdf5read() which requires HDF5 support. May not be available on all MATLAB installations.

**Current mitigation:** Function gracefully falls back to inline data if H5 file unavailable

**Recommendation:** Document as optional dependency. Provide warning in loadEpicTreeData when H5 files referenced but toolbox unavailable.

---

## Missing Critical Features

### 1. No Error Recovery in Data Loading
**Problem:** If .mat file is corrupted or partially exported, loadEpicTreeData() gives cryptic error

**Blocks:** Users cannot debug data export issues

**Recommendation:**
- Add data validation pass after load
- Report which epochs are malformed
- Provide partial load option (skip corrupted epochs)

---

### 2. No Data Export/Serialization
**Problem:** Analysis results computed with putCustom() cannot be saved

**Blocks:** Results don't persist across sessions

**Recommendation:**
- Implement tree serialization to .mat file
- Create results export to CSV/HDF5

---

### 3. Limited Stimulus Information
**Problem:** Stimulus data (waveforms, parameters) minimally documented in data format

**Blocks:** Stimulus reconstruction for advanced analyses (LSTA, SpatioTemporalModel) incomplete

**Recommendation:**
- Expand STIMULUS_FORMAT section in DATA_FORMAT_SPECIFICATION.md
- Add stimulus validation in loadEpicTreeData()
- Create stimulus reconstruction helper functions

---

## Test Coverage Gaps

### 1. Real Data Integration Tests
**What's not tested:** Analysis functions on actual real data with real response streams

**Files affected:** All src/analysis/*.m

**Risk:** Analysis outputs may be mathematically correct but practically wrong (e.g., wrong baseline, wrong units)

**Priority:** HIGH - these are user-facing results

**Solution:** Create integration test suite:
- Use `/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat`
- Run each analysis function
- Visually verify outputs (PSTH shape, baseline values, etc.)
- Document expected ranges for each analysis

---

### 2. Error Condition Handling
**What's not tested:** How code behaves with:
- Empty epoch lists
- Single epoch (can't compute statistics)
- Missing response streams
- Variable-length responses

**Files affected:** src/getSelectedData.m, src/getResponseMatrix.m, all analysis functions

**Priority:** HIGH - errors should fail gracefully with helpful messages

**Solution:** Add error condition tests to each function's test file

---

### 3. GUI Interaction Tests
**What's not tested:**
- Clicking nodes in large trees (1000+ nodes)
- Selecting/deselecting multiple nodes
- Switching between split organizations
- Loading different file formats

**Files affected:** epicTreeGUI.m, src/gui/epicGraphicalTree.m

**Priority:** MEDIUM - mostly works but edge cases unknown

---

## Data Format Inconsistencies

### 1. Parameter Field Aliasing (parameters vs. protocolSettings)
**Issue:** Code supports both field names but behavior is inconsistent

**Files:**
- `src/tree/epicTreeTools.m` getNestedValue() (automatic aliasing)
- Splitter functions that access parameters directly

**Risk:** If epoch has both fields with different values, behavior is undefined

**Solution:**
- Normalize to single field during load in loadEpicTreeData()
- Validate that both don't have conflicting values
- Document standard field name in DATA_FORMAT_SPECIFICATION.md

---

### 2. Response Data Access Inconsistency
**Issue:** Response data can be accessed two ways:
1. `epoch.responses` - cell array of response structs
2. `epoch.response` - direct numeric array (legacy)

**Files:** getResponseMatrix.m uses approach 1, some old code expects approach 2

**Risk:** Code using wrong approach silently fails or gets wrong data

**Solution:** Standardize on single approach. Deprecate old approach with warning.

---

## Documentation Concerns

### 1. Incomplete Data Format Specification
**Issue:** DATA_FORMAT_SPECIFICATION.md documents basic structure but has gaps:
- Stimulus format incomplete (marked TODO)
- Response metadata (units, physical meaning) not documented
- Analysis parameter conventions not specified

**Impact:** Export code and analysis functions work around missing specs

**Solution:** Complete all sections. Use real epoch struct as example.

---

### 2. Missing Migration Guide
**Issue:** No documentation on how to convert old legacy code to new system

**Impact:** Users trying to port custom analysis functions don't know patterns

**Solution:** Create MIGRATION_GUIDE.md with examples:
- Old Java-based tree → new epicTreeTools
- Old getResponseMatrix → new getSelectedData
- Old custom splitter → new function handle pattern

---

## Maintenance Concerns

### 1. Massive Documentation Debt
**Files:** 25+ .md files at repo root (2000+ lines of documentation scattered across files)

**Issue:** Documentation is extensive but scattered, redundant, and hard to navigate

**Files:** README.md, QUICK_START.md, CLAUDE.md, USAGE_PATTERNS.md, EPOCH_TREE_SYSTEM_COMPREHENSIVE_GUIDE.md, etc.

**Risk:** Conflicting information, outdated docs not updated when code changes

**Solution:**
- Consolidate into single source of truth
- Move to docs/ directory with clear structure
- Generate from docstrings where possible
- Add CI check to keep docs in sync with code

---

### 2. Test File Organization Issues
**Files:** 20 test files at repo root (test_*.m)

**Issue:** No clear pattern for which tests to run. Some are stale (test_blank_gui_fix.m, test_renamed.m)

**Risk:** New developers unsure which tests are current vs. legacy

**Solution:**
- Move test_*.m → tests/ directory (partially done)
- Document test hierarchy in tests/README.md
- Mark stale tests as archived

---

---

*Concerns audit: 2026-02-06*
