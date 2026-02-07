# Phase 0: Testing & Validation - Research

**Researched:** 2026-02-07
**Domain:** MATLAB automated testing, GUI testing, baseline/golden output testing
**Confidence:** HIGH

## Summary

This research covers implementing automated testing for a MATLAB neurophysiology data analysis tool (epicTreeGUI). The project needs comprehensive test coverage for analysis functions, tree navigation, data extraction, GUI interactions, and 14+ splitter functions. The standard approach uses MATLAB's built-in testing frameworks (class-based unit tests for backend, App Testing Framework for GUI) combined with baseline testing for capturing golden outputs.

MATLAB provides three testing approaches: script-based (basic), function-based (xUnit-style with constraints), and class-based (full framework with fixtures and parameterization). For this project, class-based tests are recommended due to the need for setup/teardown, fixture management, and parameterized testing across multiple data conditions. The App Testing Framework (`matlab.uitest.TestCase`) enables programmatic GUI interaction testing. Baseline testing using `verifyEqualsBaseline()` allows capturing current behavior as reference files for regression testing.

**Primary recommendation:** Use class-based tests (`matlab.unittest.TestCase`) for all backend validation, extend with `matlab.uitest.TestCase` for GUI tests, implement baseline tests with MAT files for golden outputs, and execute all tests via MCP MATLAB server tools (not bash commands).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Primary goal:** Validate correctness, not just prove nothing breaks
- **Critical function categories to validate:**
  - Analysis functions (getMeanResponseTrace, getResponseAmplitudeStats, getCycleAverageResponse, getLinearFilterAndPrediction, MeanSelectedNodes)
  - Tree navigation (childAt, parentAt, getAllEpochs, leafNodes, childBySplitValue)
  - Data extraction (getSelectedData, getResponseMatrix)
  - All 14+ splitter functions
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
- **Primary data source:** Real experiment data (actual exported neurophysiology data)
- **Test data bundling:** Yes - commit test data file to repository
- **Path handling:** Hardcoded relative path (e.g., 'test_data/sample_data.mat' from repo root)
- **Data preparation workflow:**
  - Pre-Phase 0 setup: User provides H5 file → convert to MAT using RetinAnalysis → commit .mat file
  - Check existing loading mechanism to understand how data is loaded
  - Move CLAUDE.md to `.claude/` directory for proper organization
- **Default action when bugs found:** Fix AND document
- **Bug documentation:** Both test report (TESTING_REPORT.md) AND detailed git commit messages
- **Issues beyond bugs:** Phase 0 testing should also identify:
  - Performance problems (slow operations, memory issues, inefficient algorithms)
  - Design inconsistencies (API inconsistencies, naming mismatches, pattern violations)
- **Non-bug issue handling:** Fix AND document (same as bugs - address immediately)
- **Phase 0 completion focus:** Automated tests only (manual testing comes later)
- **Success threshold:** No test failures (tests can be incomplete, but nothing that runs should fail)
- **Baseline for future:** Yes - capture current behavior as baseline
- **Baseline capture method:** Golden outputs (save output files from test runs as reference files)

### Claude's Discretion
- Analysis function validation depth (choose between format checks vs correctness validation per function)
- Exact test organization and structure
- Specific golden output format and comparison logic
- Test utility API design details

### Deferred Ideas (OUT OF SCOPE)
None - discussion stayed within phase scope

</user_constraints>

## Standard Stack

The established testing libraries for MATLAB testing in 2026:

### Core Testing Framework
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| matlab.unittest.TestCase | Built-in (R2013a+) | Class-based unit testing | Industry standard for MATLAB testing, provides full framework functionality |
| matlab.uitest.TestCase | Built-in (R2017b+) | GUI/App testing | Official framework for testing uifigure-based apps, subclasses TestCase |
| matlab.perftest | Built-in (R2016a+) | Performance measurement | Standard for performance regression testing |

### Supporting Utilities
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| matlabtest.parameters.matfileBaseline | Built-in (MATLAB Test) | Baseline testing with MAT files | Capturing golden outputs for regression testing |
| inputParser | Built-in | Parameter validation in tests | Parsing test configuration options |
| matlab.unittest.fixtures | Built-in | Test fixtures | Setup/teardown for file operations, path management |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Class-based tests | Script-based tests | Scripts simpler but lack fixtures, parameterization, setup/teardown |
| Class-based tests | Function-based tests | Functions provide constraints but lack full framework features |
| MAT file baseline | Custom JSON/CSV baseline | MAT files native to MATLAB, preserve data types perfectly |

**Installation:**
All libraries are built-in to MATLAB (no installation required). Baseline testing requires MATLAB Test toolbox (check with `ver('matlab-test')`).

## Architecture Patterns

### Recommended Test Organization
```
tests/
├── unit/                          # Unit tests for individual functions
│   ├── AnalysisFunctionsTest.m   # Class-based tests for analysis functions
│   ├── TreeNavigationTest.m      # Tree navigation methods
│   ├── DataExtractionTest.m      # getSelectedData, getResponseMatrix
│   └── SplitterFunctionsTest.m   # All 14+ splitter functions
├── integration/                   # Integration tests
│   ├── TreeBuildingTest.m        # End-to-end tree building
│   └── WorkflowTest.m            # Complete analysis workflows
├── gui/                           # GUI automated tests
│   ├── TreeBrowserTest.m         # Tree visualization and interaction
│   └── EpochViewerTest.m         # Epoch display panel
├── utilities/                     # Test utilities
│   └── TreeNavigationUtility.m   # Command-line tree navigator
├── baselines/                     # Golden output files
│   ├── getMeanResponseTrace_baseline.mat
│   ├── getResponseAmplitudeStats_baseline.mat
│   └── ...
└── test_data/                     # Test data files (committed)
    └── sample_data.mat            # Real neurophysiology data
```

### Pattern 1: Class-Based Unit Test
**What:** Test class inheriting from `matlab.unittest.TestCase`
**When to use:** All function validation (analysis, navigation, extraction)
**Example:**
```matlab
% Source: Official MATLAB documentation
classdef AnalysisFunctionsTest < matlab.unittest.TestCase

    properties (TestParameter)
        % Parameterized test data
        recordingType = {'exc', 'inh', 'extracellular'};
    end

    properties
        TestData
        TestTree
    end

    methods (TestClassSetup)
        % Runs once before all tests
        function loadTestData(testCase)
            dataPath = fullfile('test_data', 'sample_data.mat');
            testCase.TestData = load(dataPath);
            testCase.TestTree = epicTreeTools(testCase.TestData);
        end
    end

    methods (TestMethodSetup)
        % Runs before each test
        function setupTree(testCase)
            testCase.TestTree.buildTree({'cellInfo.type'});
        end
    end

    methods (Test)
        function testGetMeanResponseTrace(testCase, recordingType)
            % Test getMeanResponseTrace with different recording types
            node = testCase.TestTree.childAt(1);
            result = getMeanResponseTrace(node, 'Amp1', ...
                'RecordingType', recordingType);

            % Verify output structure
            testCase.verifyClass(result, 'struct');
            testCase.verifyTrue(isfield(result, 'mean'));
            testCase.verifyTrue(isfield(result, 'SEM'));
            testCase.verifyEqual(size(result.mean, 1), 1);

            % Verify non-empty for valid data
            if ~isempty(node.getAllEpochs(true))
                testCase.verifyNotEmpty(result.mean);
            end
        end
    end
end
```

### Pattern 2: Baseline Test for Golden Outputs
**What:** Capture current function output as reference for regression testing
**When to use:** Complex analysis functions with numeric outputs
**Example:**
```matlab
% Source: https://www.mathworks.com/help/matlab-test/ug/create-baseline-tests-for-matlab-code.html
classdef BaselineAnalysisTest < matlab.unittest.TestCase

    properties (TestParameter)
        meanTrace = matlabtest.parameters.matfileBaseline(...
            fullfile('tests', 'baselines', 'getMeanResponseTrace_baseline.mat'), ...
            VariableName='meanTrace')
        peakStats = matlabtest.parameters.matfileBaseline(...
            fullfile('tests', 'baselines', 'getResponseAmplitudeStats_baseline.mat'), ...
            VariableName='stats')
    end

    methods (Test)
        function testMeanResponseTraceBaseline(testCase, meanTrace)
            % Load test data
            tree = loadTestTree();
            node = tree.childAt(1);

            % Compute result
            result = getMeanResponseTrace(node, 'Amp1');

            % Compare against baseline
            testCase.verifyEqualsBaseline(result.mean, meanTrace, ...
                'AbsTol', 1e-10);
        end
    end
end
```

### Pattern 3: GUI Test with App Testing Framework
**What:** Programmatic GUI interaction and verification
**When to use:** Testing tree browser, selection checkboxes, epoch viewer
**Example:**
```matlab
% Source: https://www.mathworks.com/help/matlab/matlab_prog/overview-of-app-testing-framework.html
classdef TreeBrowserTest < matlab.uitest.TestCase

    properties
        App
    end

    methods (TestMethodSetup)
        function launchApp(testCase)
            % Build tree
            tree = loadTestTree();

            % Launch GUI
            testCase.App = epicTreeGUI(tree);

            % Add teardown to close GUI
            testCase.addTeardown(@() close(testCase.App.figure));
        end
    end

    methods (Test)
        function testTreeExpansion(testCase)
            % Get graphical tree
            graphTree = testCase.App.treeBrowser.graphTree;

            % Verify initial state
            testCase.verifyTrue(graphTree.isExpanded);

            % Programmatically collapse
            graphTree.collapse();
            testCase.verifyFalse(graphTree.isExpanded);
        end

        function testCheckboxSelection(testCase)
            % Get tree node
            tree = testCase.App.tree;
            node = tree.childAt(1);

            % Verify initial selection state
            isSelected = node.getCustom('isSelected');
            testCase.verifyTrue(isSelected);

            % Programmatically toggle checkbox
            % (Implementation depends on graphicalTree API)
            node.putCustom('isSelected', false);
            testCase.verifyFalse(node.getCustom('isSelected'));
        end
    end
end
```

### Pattern 4: Parameterized Splitter Tests
**What:** Test all splitter functions systematically
**When to use:** Validating 14+ splitter functions
**Example:**
```matlab
classdef SplitterFunctionsTest < matlab.unittest.TestCase

    properties (TestParameter)
        splitterFunction = {
            @epicTreeTools.splitOnExperimentDate,
            @epicTreeTools.splitOnCellType,
            @epicTreeTools.splitOnProtocol,
            @epicTreeTools.splitOnContrast,
            @epicTreeTools.splitOnTemporalFrequency,
            % ... all 14+ splitters
        };
    end

    methods (Test)
        function testSplitterReturnType(testCase, splitterFunction)
            % Load test epoch
            tree = loadTestTree();
            epochs = tree.getAllEpochs(false);

            if ~isempty(epochs)
                epoch = epochs{1};

                % Call splitter
                value = splitterFunction(epoch);

                % Verify returns scalar (string, numeric, or logical)
                testCase.verifyTrue(isscalar(value) || ischar(value) || isstring(value));
            end
        end

        function testTreeBuildWithSplitter(testCase, splitterFunction)
            % Build tree with splitter
            tree = loadTestTree();
            tree.buildTreeWithSplitters({splitterFunction});

            % Verify tree structure
            testCase.verifyGreaterThanOrEqual(tree.childrenLength(), 1);

            % Verify all epochs accounted for
            originalCount = length(tree.allEpochs);
            leafNodes = tree.leafNodes();
            totalEpochs = 0;
            for i = 1:length(leafNodes)
                totalEpochs = totalEpochs + length(leafNodes{i}.epochList);
            end
            testCase.verifyEqual(totalEpochs, originalCount);
        end
    end
end
```

### Anti-Patterns to Avoid
- **Script-based tests without classes:** Lack setup/teardown, fixtures, parameterization - harder to maintain
- **Testing implementation details:** Don't test private methods or internal state - test public API only
- **Hardcoded paths without fixtures:** Use `matlab.unittest.fixtures.PathFixture` or relative paths from test file location
- **Manual GUI testing only:** Automated GUI tests catch regressions; manual testing alone is insufficient
- **Not using teardown:** Always clean up (close figures, delete temp files) to prevent test interference

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test runner | Custom script that calls tests | `runtests()` or TestRunner | Built-in runner handles setup/teardown, reporting, parallel execution |
| Assertion library | Custom `if ~cond, error()` checks | `verifyEqual`, `verifyClass`, `verifyTrue` | Qualifications provide better diagnostics, tolerance handling, failure modes |
| Test fixtures | Manual setup/teardown in each test | `matlab.unittest.fixtures.*` | Fixtures handle common patterns (paths, files, current folder) with proper cleanup |
| GUI interaction | Mouse/keyboard simulation | `matlab.uitest.TestCase` methods | Framework ensures app locking, handles timing, provides reliable gesture API |
| Baseline comparison | Custom file diff logic | `verifyEqualsBaseline()` | Handles MAT file creation, update workflows, tolerance specification |
| Parameterized tests | Copying test methods | TestParameter properties | Declarative, runs all combinations, better reporting |
| Test data loading | Load in every test | TestClassSetup or shared fixtures | Load once, reuse across tests, faster execution |

**Key insight:** MATLAB's testing framework has matured over 10+ years. Custom solutions miss edge cases (tolerance handling, array size mismatches, NaN comparisons, cleanup on errors, parallel test execution safety).

## Common Pitfalls

### Pitfall 1: GUI Testing with GUIDE-based Apps
**What goes wrong:** App Testing Framework (`matlab.uitest.TestCase`) only supports uifigure-based apps (App Designer), not GUIDE
**Why it happens:** epicTreeGUI appears to use traditional figure() not uifigure()
**How to avoid:**
- Check GUI creation code - if using `figure()` instead of `uifigure()`, App Testing Framework won't work
- Alternatives: Programmatic testing via GUI object properties and methods (e.g., `gui.tree.childAt(1)`)
- For checkbox testing, access underlying graphicalTree/epicGraphicalTree API directly
**Warning signs:** `matlab.uitest.TestCase` methods fail with "unsupported component" errors

### Pitfall 2: Test Independence with Shared Tree State
**What goes wrong:** Tests modify shared tree object (selection state, custom properties), causing subsequent tests to fail
**Why it happens:** Tree nodes are handle objects - modifications persist across tests
**How to avoid:**
- Use TestMethodSetup to rebuild tree before each test
- Or deep copy tree in setup: `testCase.TestTree = copy(originalTree)` (if copy method exists)
- Never rely on test execution order
**Warning signs:** Tests pass individually but fail when run as suite; tests fail randomly

### Pitfall 3: Baseline Files Don't Exist on First Run
**What goes wrong:** Baseline tests fail because .mat files don't exist yet
**Why it happens:** Baseline workflow requires manual approval of first output
**How to avoid:**
- First run ALWAYS fails - this is expected
- MATLAB provides hyperlinks: "Create baseline from recorded test data"
- Click link to save current output as baseline
- Document this in test README
- Don't commit baselines until manually verified correct
**Warning signs:** All baseline tests fail on CI/new checkout with "file not found"

### Pitfall 4: H5 Lazy Loading in Tests
**What goes wrong:** Tests fail with "H5 file not found" even though MAT data loads correctly
**Why it happens:** Real data uses lazy loading - response data stored in H5, not MAT file
**How to avoid:**
- Test data workflow must include BOTH .mat and .h5 files
- Or bundle test data with responses pre-loaded into MAT file (no H5 dependency)
- Configure epicTreeConfig('h5_dir') in TestClassSetup
- Pass h5_file parameter to getSelectedData() in tests
**Warning signs:** Tree builds fine, but data extraction returns empty matrices

### Pitfall 5: MCP MATLAB Server vs Bash Execution
**What goes wrong:** Running tests via bash `matlab -batch` doesn't connect to GUI, loses MCP context
**Why it happens:** User constraint specifies using MCP MATLAB server tools exclusively
**How to avoid:**
- ALWAYS use `mcp__matlab__run_matlab_test_file` for test execution
- NEVER use `bash matlab -batch runtests(...)`
- MCP tools connect to existing MATLAB session with GUI visible
- Provides better debugging, output capture, error reporting
**Warning signs:** Tests run but GUI interactions fail; MCP tools unavailable in CI

### Pitfall 6: Tolerance in Numeric Comparisons
**What goes wrong:** Tests fail due to floating-point precision differences (OS, MATLAB version)
**Why it happens:** Numeric computations have inherent precision limits
**How to avoid:**
- Use `verifyEqual(actual, expected, 'AbsTol', 1e-10)` for doubles
- Use `verifyEqual(actual, expected, 'RelTol', 1e-6)` for relative comparisons
- Baseline tests: specify tolerance in `verifyEqualsBaseline()`
- Document expected precision in test comments
**Warning signs:** Tests fail with tiny differences (1e-15); tests fail on different machines

### Pitfall 7: Analysis Function Validation Depth
**What goes wrong:** Unclear whether to validate output format only or verify correctness
**Why it happens:** User constraint gives Claude discretion on validation depth
**How to avoid:**
- **Simple functions** (getSelectedData, tree navigation): Validate format + basic correctness
- **Complex analysis** (getMeanResponseTrace, getLinearFilterAndPrediction): Format validation + baseline comparison, not full correctness proofs
- **Heuristic:** If ground truth is unclear, use baselines; if ground truth is known (e.g., epochCount), verify exactly
**Warning signs:** Tests take too long (over-validating); tests miss bugs (under-validating)

## Code Examples

Verified patterns from official sources:

### Running Tests Programmatically
```matlab
% Source: https://www.mathworks.com/help/matlab/matlab-unit-test-framework.html
% Run all tests in directory
results = runtests('tests/unit');

% Run specific test class
results = runtests('AnalysisFunctionsTest');

% Run with coverage report (requires MATLAB Test)
import matlab.unittest.TestRunner
import matlab.unittest.plugins.CodeCoveragePlugin

runner = TestRunner.withTextOutput;
runner.addPlugin(CodeCoveragePlugin.forFolder('src'));
results = runner.run(testsuite('tests/unit'));

% Filter tests by tag
suite = testsuite('tests');
suite = suite.selectIf(HasTag('fast'));
results = runtests(suite);
```

### Test Utility for Command-Line Navigation
```matlab
% Source: User requirement from CONTEXT.md
% tests/utilities/TreeNavigationUtility.m
classdef TreeNavigationUtility < handle
    % Command-line utility for testing tree navigation and selection
    %
    % Usage:
    %   util = TreeNavigationUtility(gui);
    %   util.navigateToNode('OnP', 'SingleSpot');
    %   util.toggleCheckbox(true);
    %   util.selectAll();
    %   data = util.extractData('Amp1');

    properties
        GUI           % epicTreeGUI handle
        CurrentNode   % Current node in tree
    end

    methods
        function obj = TreeNavigationUtility(gui)
            % Create utility attached to GUI instance
            obj.GUI = gui;
            obj.CurrentNode = gui.tree;  % Start at root
        end

        function navigateToChild(obj, index)
            % Navigate to child by index
            obj.CurrentNode = obj.CurrentNode.childAt(index);
        end

        function navigateToNode(obj, varargin)
            % Navigate to node by splitValues path
            % Example: navigateToNode('OnP', 'SingleSpot')
            obj.CurrentNode = obj.GUI.tree;
            for i = 1:length(varargin)
                obj.CurrentNode = obj.CurrentNode.childBySplitValue(varargin{i});
                if isempty(obj.CurrentNode)
                    error('Node not found: %s', varargin{i});
                end
            end
        end

        function toggleCheckbox(obj, selected)
            % Programmatically set checkbox state
            % This needs to interact with actual GUI checkbox
            % (not just setSelected() - must trigger GUI update)
            graphNode = obj.findGraphicalNode(obj.CurrentNode);
            if ~isempty(graphNode) && isfield(graphNode, 'checkBox')
                graphNode.checkBox.setValue(selected);
            end
            obj.CurrentNode.putCustom('isSelected', selected);
        end

        function selectAll(obj)
            % Select current node and all descendants
            obj.CurrentNode.setSelected(true, true);
        end

        function data = extractData(obj, streamName)
            % Extract data from current node
            [data, ~, ~] = getSelectedData(obj.CurrentNode, streamName, obj.GUI.h5File);
        end

        function printTree(obj)
            % Print tree structure from current node
            obj.printNode(obj.CurrentNode, 0);
        end
    end

    methods (Access = private)
        function graphNode = findGraphicalNode(obj, treeNode)
            % Find corresponding graphical node in GUI
            % (Implementation depends on epicGraphicalTree structure)
            graphNode = [];  % Placeholder
        end

        function printNode(obj, node, depth)
            indent = repmat('  ', 1, depth);
            fprintf('%s%s (%d epochs)\n', indent, string(node.splitValue), node.epochCount());
            for i = 1:node.childrenLength()
                obj.printNode(node.childAt(i), depth + 1);
            end
        end
    end
end
```

### Test Setup with Data Loading
```matlab
% Source: Best practice pattern
methods (TestClassSetup)
    function loadTestData(testCase)
        % Add paths
        addpath(genpath('src'));

        % Load test data (relative path from repo root)
        dataPath = fullfile('test_data', 'sample_data.mat');
        testCase.verifyTrue(isfile(dataPath), ...
            'Test data not found. Run setup script first.');

        data = load(dataPath);
        testCase.TestData = data;

        % Configure H5 directory
        h5Dir = fullfile('test_data', 'h5');
        epicTreeConfig('h5_dir', h5Dir);

        % Build tree
        testCase.TestTree = epicTreeTools(testCase.TestData);
    end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Script-based tests | Class-based tests with fixtures | R2013a (2013) | Better organization, setup/teardown, parameterization |
| Manual assertions (`if ~cond, error()`) | Qualification methods (`verifyEqual`) | R2013a | Better diagnostics, tolerance handling, soft failures |
| No GUI testing | App Testing Framework | R2017b (2017) | Automated GUI regression testing possible |
| Custom baseline logic | `verifyEqualsBaseline()` | MATLAB Test | Standardized workflow for capturing/updating baselines |
| Sequential test execution | Parallel test execution | R2018a | Faster test suites with `runtests(suite, 'UseParallel', true)` |

**Deprecated/outdated:**
- **xUnit third-party framework:** Built-in framework now comprehensive, xUnit no longer needed
- **Manual test runners:** `runtests()` provides reporting, filtering, parallel execution
- **GUIDE GUI testing:** App Testing Framework only supports uifigure (App Designer), not GUIDE

## Open Questions

Things that couldn't be fully resolved:

1. **epicTreeGUI figure type (figure vs uifigure)**
   - What we know: Code shows `figure(...)` in constructor, not `uifigure(...)`
   - What's unclear: Whether App Testing Framework (`matlab.uitest.TestCase`) will work
   - Recommendation: Investigate GUI creation code; if traditional figure(), use programmatic API testing instead of App Testing Framework

2. **Checkbox testing implementation**
   - What we know: Requirement is to test "actual GUI checkboxes" not just `setSelected()`
   - What's unclear: graphicalTree/epicGraphicalTree checkbox API not researched
   - Recommendation: Examine `src/gui/graphicalCheckBox.m`, `epicGraphicalTree.m` to understand checkbox object model before planning tests

3. **Test data preparation workflow**
   - What we know: Need real data, user provides H5 → convert to MAT → commit
   - What's unclear: Whether to bundle H5 files or pre-load responses into MAT to avoid H5 dependency
   - Recommendation: Check test data size; if small (<10MB), bundle both MAT+H5; if large, pre-load responses into MAT for tests only

4. **MCP MATLAB Server tools availability in CI**
   - What we know: MCP tools required for test execution per user constraint
   - What's unclear: Whether MCP server can run in CI environment or only local development
   - Recommendation: Phase 0 focuses on automated tests (local execution); document CI requirements for later phases

## Sources

### Primary (HIGH confidence)
- [MATLAB Unit Testing Framework Overview](https://www.mathworks.com/help/matlab/matlab-unit-test-framework.html)
- [Class-Based Unit Tests](https://www.mathworks.com/help/matlab/matlab_prog/class-based-unit-tests.html)
- [App Testing Framework](https://www.mathworks.com/help/matlab/matlab_prog/overview-of-app-testing-framework.html)
- [Create Baseline Tests for MATLAB Code](https://www.mathworks.com/help/matlab-test/ug/create-baseline-tests-for-matlab-code.html)
- [Types of Code Coverage for MATLAB Source Code](https://www.mathworks.com/help/matlab/matlab_prog/types-of-code-coverage-for-matlab-source-code.html)

### Secondary (MEDIUM confidence)
- [MATLAB MCP Core Server](https://www.mathworks.com/products/matlab-mcp-core-server.html) - MCP testing tools (2026)
- [Property Validation Functions](https://www.mathworks.com/help/matlab/matlab_oop/property-validator-functions.html)
- [Test Planning and Strategies](https://www.mathworks.com/help/sltest/gs/plan-your-test.html)

### Codebase Analysis (HIGH confidence)
- `/Users/maxwellsdm/Documents/GitHub/epicTreeGUI/CLAUDE.md` - Project structure and MCP requirements
- `/Users/maxwellsdm/Documents/GitHub/epicTreeGUI/tests/test_selection_navigation.m` - Existing test pattern
- `/Users/maxwellsdm/Documents/GitHub/epicTreeGUI/tests/test_tree_navigation_realdata.m` - Real data test example
- `/Users/maxwellsdm/Documents/GitHub/epicTreeGUI/src/analysis/*.m` - Analysis function APIs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official MATLAB built-in frameworks well-documented
- Architecture: HIGH - Class-based patterns are established best practice since 2013
- Pitfalls: HIGH - Based on official docs and common MATLAB testing issues
- GUI Testing: MEDIUM - Need to verify figure vs uifigure type; App Testing Framework may not apply
- MCP Tools: MEDIUM - 2026 feature, less established than core testing framework
- Baseline Testing: HIGH - Official MATLAB Test feature with clear documentation

**Research date:** 2026-02-07
**Valid until:** 60 days (stable domain - testing frameworks change slowly)
