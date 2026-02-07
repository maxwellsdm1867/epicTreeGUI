# Testing Patterns

**Analysis Date:** 2026-02-06

## Test Framework

**Runner:**
- MATLAB built-in test execution via `run tests/test_*.m` scripts (no test framework)
- No xUnit, unittest, or pytest equivalent
- MCP MATLAB server for executing tests with proper environment (CLAUDE.md requirement)

**Assertion Library:**
- Built-in MATLAB `assert()` function for test conditions
- Custom error checking with `if ~condition; error(...); end`
- Manual result tracking with struct-based test logs

**Run Commands:**
```bash
# From epicTreeGUI directory:
run tests/test_tree_navigation.m              # Test tree navigation API
run tests/test_gui_display_data.m             # Test GUI display + data retrieval
run tests/test_splitters.m                    # Test tree splitting functions
run tests/test_legacy_pattern.m               # Test pre-built tree GUI pattern
run tests/test_exact_legacy_pattern.m         # Test exact legacy workflow
run tests/test_selection_navigation.m         # Test selection state management
run tests/test_robust_splits.m                # Test split robustness
run tests/test_data_loading.m                 # Test data loading
run tests/test_h5_lazy_loading.m              # Test H5 lazy loading (requires real data)
```

## Test File Organization

**Location:**
- All test scripts in `/Users/maxwellsdm/Documents/GitHub/epicTreeGUI/tests/` directory
- Co-located with source (not in separate `test/` directory - all test files in `tests/`)
- Test scripts are MATLAB scripts (not functions), executed with `run`

**Naming:**
- Pattern: `test_*.m` (test scripts use lowercase prefix)
- Examples: `test_tree_navigation.m`, `test_gui_display_data.m`, `test_splitters.m`
- Clear names describing what is tested

**Structure:**
```
tests/
├── test_tree_navigation.m              # Core tree API
├── test_gui_display_data.m             # GUI + data integration
├── test_splitters.m                    # Split functionality
├── test_selection_navigation.m         # Selection state
├── test_legacy_pattern.m               # Pre-built tree pattern
├── test_exact_legacy_pattern.m         # Exact Java legacy match
├── test_data_loading.m                 # Data loading
├── test_h5_lazy_loading.m              # H5 file loading
├── test_robust_splits.m                # Edge cases
├── test_epoch_display.m                # Epoch rendering
└── ...
```

## Test Structure

**Suite Organization:**
```matlab
%% Test Tree Navigation and Controlled Access
% This script tests the epicTreeTools navigation patterns per riekesuitworkflow.md
%
% Tests:
%   1. Load data and build tree with splitters
%   2. Navigate DOWN: childAt, childrenLength, leafNodes
%   3. Navigate UP: parent, parentAt, depth, pathFromRoot
%   4. Controlled access: putCustom, getCustom, hasCustom
%   5. Full workflow: navigate + analyze + store + query
%
% Run this from epicTreeGUI directory:
%   cd /Users/maxwellsdm/Documents/GitHub/epicTreeGUI
%   run tests/test_tree_navigation.m

clear; clc;
fprintf('\n========================================\n');
fprintf('  EPICTREETOOLS NAVIGATION TEST\n');
fprintf('========================================\n\n');

%% Add paths
baseDir = fileparts(fileparts(mfilename('fullpath')));
if isempty(baseDir)
    baseDir = '/Users/maxwellsdm/Documents/GitHub/epicTreeGUI';
end
addpath(genpath(fullfile(baseDir, 'src')));
fprintf('Base dir: %s\n', baseDir);
fprintf('Added src path\n\n');

%% Test 1: Create test data
fprintf('1. CREATING TEST DATA\n');
fprintf('   -----------------\n');
try
    testData = struct();
    % ... setup code ...
    fprintf('   Created %d cells, %d protocols\n', 3, 3);
    fprintf('   [PASS]\n\n');
catch ME
    fprintf('   [FAIL] %s\n\n', ME.message);
    return;
end

%% Test 2: Build tree
fprintf('2. BUILD TREE WITH SPLITTERS\n');
fprintf('   -------------------------\n');
try
    tree = epicTreeTools(testData);
    tree.buildTree({'cellInfo.type', 'blockInfo.protocol_name'});
    fprintf('   Built tree with splitters\n');
    fprintf('   [PASS]\n\n');
catch ME
    fprintf('   [FAIL] %s\n\n', ME.message);
    return;
end
```

**Patterns:**
1. **Section headers** with `%%` for visual separation
2. **Clear section descriptions** in comments at start
3. **Path setup** at start with `addpath(genpath(...))`
4. **Try-catch per test** with PASS/FAIL reporting
5. **Early return on failure** (don't continue if test fails)
6. **Print summary** at end

## Mocking

**Framework:**
- No mocking framework (no unittest.mock or Mockito equivalent in MATLAB)
- Synthetic test data creation instead of mocking

**Patterns:**
Create synthetic data matching expected structure:

```matlab
% Create synthetic test data (mimics DATA_FORMAT_SPECIFICATION.md)
testData = struct();
testData.format_version = '1.0';
testData.metadata = struct('created_date', datestr(now), 'data_source', 'test');
testData.experiments = {};

% Create one experiment
exp = struct();
exp.id = 1;
exp.exp_name = '2025-01-25_Test';
exp.cells = {};

% Create cells with data
cellTypes = {'OnP', 'OffP', 'OnM'};
for c = 1:length(cellTypes)
    cell = struct();
    cell.id = c;
    cell.type = cellTypes{c};
    cell.epoch_groups = {};

    % Create epochs
    for ct = 1:length(contrasts)
        for rep = 1:3
            epoch = struct();
            epoch.id = epochCounter;
            epoch.parameters = struct('contrast', contrasts(ct));
            epoch.responses = struct();
            epoch.responses(1).device_name = 'Amp1';
            epoch.responses(1).data = randn(1, 10000) * contrasts(ct);
            epoch.responses(1).sample_rate = 10000;
            % ...
        end
    end
end
```

**What to Mock:**
- Complex dependencies: Create minimal synthetic structs
- External data: Use test data fixtures stored in `/Users/maxwellsdm/Documents/epicTreeTest/analysis/`
- GUI components: Create figure/axes in tests when needed

**What NOT to Mock:**
- Core logic (epicTreeTools, getSelectedData) - test real implementations
- File I/O (loadEpicTreeData) - test with real test data
- Data structures (epoch structs) - use synthetic but structurally accurate data

## Fixtures and Factories

**Test Data:**

From `test_tree_navigation.m:29-109`:
```matlab
function testData = createSyntheticData()
    % Synthetic data matching DATA_FORMAT_SPECIFICATION
    testData = struct();
    testData.format_version = '1.0';
    testData.experiments = {};

    exp = struct();
    exp.cells = {};

    cellTypes = {'OnP', 'OffP', 'OnM'};
    for c = 1:length(cellTypes)
        cell = struct();
        cell.type = cellTypes{c};
        cell.epoch_groups = {};
        exp.cells{end+1} = cell;
    end

    testData.experiments{1} = exp;
end
```

**Real Test Data Location:**
- Primary: `/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat`
- H5 files: `/Users/maxwellsdm/Documents/epicTreeTest/h5/`
- Used for integration tests requiring real data structure and lazy loading

**Fixture Pattern:**
- Synthetic data created in test setup (no shared fixtures file)
- Real data loaded with `loadEpicTreeData()` when available
- Tests skip gracefully if real data missing: `if hasRealData; ... else; fprintf('[SKIP] ...\n'); end`

## Coverage

**Requirements:** Not enforced
- No code coverage measurement configured
- No coverage reports or CI gates
- Manual verification of important paths (tree navigation, data access, selection)

**View Coverage:**
- Not applicable (no coverage tools integrated)
- Manual approach: Review test files for what paths are exercised

## Test Types

**Unit Tests:**
- **Scope**: Individual function behavior
- **Approach**: Call function with synthetic data, verify outputs with `assert()`
- **Example** (`test_tree_navigation.m:130-158`):
  ```matlab
  try
      % Test childrenLength
      n = tree.childrenLength();
      fprintf('   tree.childrenLength() = %d\n', n);
      assert(n == 3, 'Expected 3 cell types');

      % Test childAt
      firstChild = tree.childAt(1);
      fprintf('   tree.childAt(1).splitValue = "%s"\n', string(firstChild.splitValue));
      assert(~isempty(firstChild), 'childAt(1) should not be empty');

      fprintf('   [PASS]\n\n');
  catch ME
      fprintf('   [FAIL] %s\n\n', ME.message);
      return;
  end
  ```

**Integration Tests:**
- **Scope**: Multi-component workflows
- **Approach**: Build full tree, navigate, get data, verify end-to-end correctness
- **Example** (`test_gui_display_data.m:59-157`):
  ```matlab
  % Create tree with data
  tree = epicTreeTools(testData);
  tree.buildTree({'cellInfo.type', 'blockInfo.protocol_name'});

  % Verify structure
  nChildren = tree.childrenLength();
  assert(nChildren == 3, 'Should have 3 cell types');

  % Navigate and check data
  for i = 1:tree.childrenLength()
      childNode = tree.childAt(i);
      nodeEpochs = childNode.epochCount();
      assert(nodeEpochs > 0, 'Each child should have epochs');
  end
  ```

**E2E Tests:**
- **Framework**: Not formally defined (could be added)
- **Current approach**: Legacy pattern tests simulate full workflows
  - `test_legacy_pattern.m`: Build tree → Launch GUI → Select nodes → Get data
  - `test_exact_legacy_pattern.m`: Matches Java epochTreeGUI workflow exactly

## Common Patterns

**Async Testing:**
Not applicable (MATLAB is single-threaded)

**Error Testing:**
```matlab
try
    % Try something that should fail
    tree.buildTree({});  % Empty splitters should error or warn
    assert(false, 'Should have thrown error');
catch ME
    fprintf('   Expected error caught: %s\n', ME.message);
    assert(contains(ME.message, 'expected text'), 'Error message should mention...');
    fprintf('   [PASS]\n');
end
```

**Setup and Teardown:**
Not formally used. Pattern instead:
```matlab
%% Test A1: Create and test
try
    % Create figure for this test
    testFig = figure('Visible', 'off', 'Name', 'Test GUI');
    testAxes = axes('Parent', testFig);

    % ... test code ...

    % Clean up
    close(testFig);

    fprintf('   [PASS]\n');
catch ME
    fprintf('   [FAIL] %s\n', ME.message);
    if exist('testFig', 'var') && ishandle(testFig)
        close(testFig);  % Cleanup in catch block
    end
end
```

**Test Results Tracking:**
```matlab
% Initialize tracking struct
testResults = struct('passed', 0, 'failed', 0, 'tests', {{}});

% In each test
testResults.passed = testResults.passed + 1;
testResults.tests{end+1} = {testName, 'PASS', ''};

% Or on failure
testResults.failed = testResults.failed + 1;
testResults.tests{end+1} = {testName, 'FAIL', ME.message};

% Print summary
fprintf('\n========================================================\n');
fprintf('TEST SUMMARY: %d passed, %d failed\n', testResults.passed, testResults.failed);
for i = 1:length(testResults.tests)
    result = testResults.tests{i};
    fprintf('  %s: %s\n', result{1}, result{2});
    if ~isempty(result{3})
        fprintf('    -> %s\n', result{3});
    end
end
```

## Running Tests with MCP MATLAB Server

Per CLAUDE.md requirements:

**When to use MCP tools instead of Bash:**
- Running test files: Use `mcp__matlab__run_matlab_test_file` with absolute path
- Executing scripts: Use `mcp__matlab__run_matlab_file` with absolute path
- Evaluating code: Use `mcp__matlab__evaluate_matlab_code` with project path
- Static analysis: Use `mcp__matlab__check_matlab_code` with script path

**Example (correct approach):**
```
Run: mcp__matlab__run_matlab_test_file
  script_path: /Users/maxwellsdm/Documents/GitHub/epicTreeGUI/tests/test_tree_navigation.m
```

**Not this (incorrect):**
```
bash: matlab -batch "run /Users/.../tests/test_tree_navigation.m"
```

---

*Testing analysis: 2026-02-06*
