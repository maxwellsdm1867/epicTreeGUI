# Coding Conventions

**Analysis Date:** 2026-02-06

## Naming Patterns

**Files:**
- Lowercase with camelCase for new functions: `getSelectedData.m`, `loadEpicTreeData.m`, `getMeanResponseTrace.m`
- Class files: PascalCase: `epicTreeGUI.m`, `epicTreeTools.m`, `graphicalTree.m`
- Splitter functions: `split[Criterion].m` pattern (e.g., `splitOnCellType.m`, `splitOnExperimentDate.m`, `splitOnRGCSubtype.m`)
- All files are `.m` (MATLAB source files)

**Functions:**
- camelCase with descriptive verbs: `getSelectedData()`, `buildTree()`, `setSelected()`, `childBySplitValue()`
- Public functions start with descriptive action: `get*`, `set*`, `build*`, `load*`
- Private methods start with underscore: (not used in this codebase, but convention would be `_private`)
- Static methods in classes accessed via class name: `epicTreeTools.splitOnCellType()`, `epicTreeTools.getNestedValue()`

**Variables:**
- Lowercase/camelCase for scalars: `nEpochs`, `sampleRate`, `fs`, `response`, `userData`
- Single letter indices for loops: `i`, `j`, `k` (standard MATLAB convention)
- Struct field names: lowercase_with_underscores: `device_name`, `split_key`, `epoch_list`, `cell_type`
- Boolean variables: isProperty or hasProperty: `isSelected`, `isLeaf`, `isExample`, `isExpanded`
- Array/collection variables: plural nouns: `epochs`, `children`, `responses`, `leaves`

**Types/Classes:**
- Struct type indicators: suffix indicates role: `Node` for tree nodes, `Data` for data containers, `Info` for metadata
- Class properties documented inline: `% Properties` section with type hints in comments

## Code Style

**Formatting:**
- No enforced code style tool detected (no ESLint config, .prettierrc, or MATLAB Code Analyzer config)
- Convention: 4-space indentation (observed throughout codebase)
- Line length: Practical limit around 100-120 chars (some lines exceed 150 chars)
- Comments use leading `%` with space: `% This is a comment`

**Linting:**
- No linting config files found (no `.mlintignore`, MATLAB Code Analyzer rules, or checkstyle configs)
- Code follows standard MATLAB practices but no automated style enforcement
- Type checking: None (MATLAB is dynamically typed)

**Indentation & Whitespace:**
- 4 spaces per indent level (consistent across all source files)
- Blank lines separate logical sections (especially between methods and major blocks)
- No trailing whitespace
- Consistent formatting with related operators and assignments

## Import Organization

**Order:**
Not applicable to MATLAB (no import statements). Functions are accessed by:
1. Functions in same directory (auto-available)
2. addpath() declarations at script start to add `src/` directory tree
3. Static method calls via class: `epicTreeTools.splitOnCellType()`
4. Function handles passed as parameters: `@epicTreeTools.getNestedValue`

**Path Aliases:**
- No path aliases configured
- Convention: Add paths with `addpath(genpath(fullfile(baseDir, 'src')))` in test scripts
- See `tests/test_tree_navigation.m:25` for pattern

## Error Handling

**Patterns:**
- Explicit validation at function start with `if` statements (not assertions in production code)
- Warning messages use `warning(messageID, format, args)` format
- Example from `loadEpicTreeData.m:55`: `warning('Data format version %s may not be fully compatible', format_version)`
- Error messages use `error(messageID, format, args)` format (includes identifier for programmatic catching)
- Example from `epicTreeGUI.m:128`: `error('Input must be an epicTreeTools object...')`
- Early returns with empty/default values when optional data missing
- Silent fallback to defaults rather than throwing (e.g., in `epicTreeGUI.m:106` missing H5 file triggers warning, not error)

**Try-Catch:**
- Used for optional operations (e.g., config loading in `epicTreeGUI.m:92-119`)
- Catches ME and logs with `ME.message` or `ME.identifier`
- Example: `catch ME; warning('Error getting H5 config: %s', ME.message); end`

**Null/Empty Checks:**
- Explicit `if isempty(value)` or `if ~isempty(value)` (never implicit truthiness)
- Special case: `if nargin < 3` for optional parameters (not `if exist('param'...)`)
- Example from `getSelectedData.m:48-50`: Check optional parameter with `nargin < 3`

## Logging

**Framework:** Built-in MATLAB `fprintf()` for console output (no logging framework)

**Patterns:**
- Progress/status: `fprintf('Loading...\n')` with simple format strings
- Structured info: Separator lines with `fprintf('========\n')`
- Warnings: `warning(messageID, 'Message: %s', value)`
- Verbose output in scripts, minimal in functions

**Examples:**
- From `loadEpicTreeData.m:35`: `fprintf('Loading EpicTree data from: %s\n', filename)`
- From `test_tree_navigation.m:16-18`: Section headers with fprintf and underlines
- Analysis functions return structs instead of printing (callers decide output)

## Comments

**When to Comment:**
- Class-level documentation: Comprehensive docstrings at class start
- Function-level documentation: MATLAB doc format starting line 1
- Complex algorithms: Explain "why", not "what" (code explains what)
- Edge cases: Document non-obvious behaviors
- Non-obvious variable meanings: e.g., `preTime = 0` comment explaining units

**JSDoc/TSDoc:**
Not applicable (MATLAB uses different doc format). Instead:

**MATLAB Documentation Format (Used throughout):**
```matlab
function output = functionName(input1, input2)
% FUNCTIONNAME One-line summary
%
% Longer description explaining purpose and usage patterns
%
% Usage:
%   output = functionName(input1, input2, 'NameValue', value)
%
% Inputs:
%   input1 - Description with type info
%   input2 - Description (optional: can be string or numeric)
%
% Outputs:
%   output - Description with structure info
%
% Example:
%   result = functionName(data, 'param', 'value');
%
% See also: relatedFunction1, relatedFunction2
```

**Examples:**
- `getSelectedData.m:1-45`: Complete doc format with usage, inputs, outputs, examples
- `getMeanResponseTrace.m:1-41`: Full parameter documentation with type hints
- `epicTreeTools.m:1-80`: Class-level documentation with typical workflows

## Function Design

**Size:** Typical range 50-150 lines per function
- Small utility functions: 10-30 lines
- Core logic functions: 50-100 lines
- Complex analysis: up to 200+ lines (with nested helpers)
- Public interface methods in classes: 5-40 lines (delegate to private implementations)

**Parameters:**
- Positional parameters: 1-3 required parameters maximum
- Optional parameters: Use `varargin` + `inputParser` for flexibility
- Example from `getMeanResponseTrace.m:44-51`:
  ```matlab
  ip = inputParser;
  ip.addRequired('epochListOrNode');
  ip.addRequired('streamName', @ischar);
  ip.addParameter('RecordingType', 'raw', @ischar);
  ip.addParameter('BaselineSubtract', [], @islogical);
  ip.parse(epochListOrNode, streamName, varargin{:});
  ```

**Return Values:**
- Single output vs multiple outputs based on usage context
- Multiple outputs grouped in struct for related data (less common, mostly cell arrays)
- Empty arrays `[]` or empty structs `struct()` for "no data" cases
- Example: `getSelectedData()` returns `[dataMatrix, selectedEpochs, sampleRate]` (always 3 outputs)
- Example: `getResponseMatrix()` returns `[dataMatrix, sampleRate]` (always 2 outputs)

## Module Design

**Exports:**
- All public functions are exported (no public/private distinction at file level)
- Static methods in classes accessed via: `ClassName.staticMethod()`
- Instance methods accessed via object: `obj.instanceMethod()`
- No explicit export control (MATLAB has no module system)

**Barrel Files:**
- Not used (no aggregation pattern observed)
- Each .m file = one class or one function
- No index/init files that re-export multiple functions

**Class Properties:**
- Public properties listed first (under `properties`)
- Hidden/private properties under `properties (Hidden = true)` or `properties (SetAccess = private)`
- Custom data stored in struct: `custom` property holds analysis results and UI state
- Example from `epicTreeTools.m:82-103`:
  ```matlab
  properties
      splitKey = ''
      splitValue = []
      children = {}
      epochList = {}
  end

  properties (SetAccess = private)
      custom = struct('isSelected', true, 'isExample', false, ...)
  end
  ```

**Method Organization:**
- Constructor first
- Destructor (if needed)
- Main public methods
- Private methods in separate `methods (Access = private)` section
- Static methods in separate `methods (Static)` section
- Example structure in `epicTreeGUI.m:50-181` (public), then lines 184-820 (private)

## Key Patterns by Module

**epicTreeTools.m (Tree class):**
- Navigation: `childAt(i)`, `childBySplitValue(val)`, `leafNodes()`, `parent`, `parentAt(n)`, `depth()`, `pathFromRoot()`
- Data access: `getAllEpochs(onlySelected)`, `epochCount()`, `selectedCount()`
- Controlled access: `putCustom(key, val)`, `getCustom(key)`, `hasCustom(key)`
- Building: `buildTree(keyPaths)`, `buildTreeWithSplitters(splitterFunctions)`

**getSelectedData.m (Data extraction):**
- Accepts: epicTreeTools node OR cell array of epochs
- Filters: Only returns epochs with `isSelected == true`
- Returns: `[dataMatrix, selectedEpochs, sampleRate]` always (3 outputs)
- CRITICAL: Used by all analysis functions

**Analysis pattern (getMeanResponseTrace, etc):**
1. Accept tree node or epoch list
2. Parse optional parameters with inputParser
3. Get data using `getSelectedData()` or `getResponseMatrix()`
4. Process and compute results
5. Return struct with named fields (never print, caller decides output)

**GUI pattern (epicTreeGUI.m):**
1. Constructor validates input, builds UI
2. Public methods for getting data (getSelectedEpochs, getSelectedEpochTreeNodes)
3. Private methods for UI building (buildUIComponents, buildTreeBrowserPanel)
4. Private callbacks for interaction (onTreeSelectionChanged, onTreeCheckChanged)
5. Separation: UI logic ≠ Data logic (use getSelectedData for data)

---

*Convention analysis: 2026-02-06*
