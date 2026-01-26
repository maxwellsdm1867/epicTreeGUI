# EpicTreeGUI Usage Patterns

There are **two ways** to use epicTreeGUI, depending on your workflow:

## Pattern 1: Simple File Loading (Dynamic Splits)

Use this for **quick exploration** where you want to try different split configurations interactively.

```matlab
% Just pass a file path - GUI will have a dropdown to change splits
gui = epicTreeGUI('data.mat');
```

**Features:**
- Split dropdown menu in GUI
- Can dynamically reorganize tree using different splitters
- Good for initial data exploration
- Limited to built-in splitter combinations

---

## Pattern 2: Pre-Built Tree (Legacy Pattern)

Use this for **production analysis** where you know exactly how to organize your data. This matches the legacy `epochTreeGUI` behavior.

```matlab
% 1. Load data
[data, ~] = loadEpicTreeData('data.mat');

% 2. Build tree structure in code
tree = epicTreeTools(data);
tree.buildTreeWithSplitters({
    @epicTreeTools.splitOnCellType,        % Level 1
    @epicTreeTools.splitOnExperimentDate,  % Level 2
    'cellInfo.id',                        % Level 3
    @myCustomSplitter                      % Level 4
});

% 3. Launch GUI with pre-built tree
gui = epicTreeGUI(tree);
```

**Features:**
- **NO split dropdown** - tree structure is fixed
- Full control over split hierarchy in code
- Supports custom splitter functions
- Reproducible analysis workflows
- Matches legacy epochTreeGUI pattern exactly

---

## Comparison with Legacy Code

### Legacy Java Pattern:
```matlab
% Legacy epochTreeGUI (Java-based)
loader = edu.washington.rieke.Analysis.getEntityLoader();
list = loader.loadEpochList('data.mat', dataFolder);

dateSplit = @(list)splitOnExperimentDate(list);
dateSplit_java = riekesuite.util.SplitValueFunctionAdapter.buildMap(list, dateSplit);

tree = riekesuite.analysis.buildTree(list, {
    'protocolSettings(source:type)',
    dateSplit_java,
    'cell.label',
    'protocolSettings(epochGroup:label)'
});

gui = epochTreeGUI(tree);  % GUI shows fixed structure
```

### New MATLAB Pattern:
```matlab
% New epicTreeGUI (pure MATLAB)
[data, ~] = loadEpicTreeData('data.mat');

tree = epicTreeTools(data);
tree.buildTreeWithSplitters({
    'cellInfo.type',                      % Was: protocolSettings(source:type)
    @epicTreeTools.splitOnExperimentDate, % Was: dateSplit_java
    'cellInfo.id',                        % Was: cell.label
    'parameters.epochGroup'               % Was: protocolSettings(epochGroup:label)
});

gui = epicTreeGUI(tree);  % GUI shows fixed structure
```

**Key differences:**
- No Java imports needed
- `loadEpicTreeData()` replaces `loader.loadEpochList()`
- `epicTreeTools` replaces `riekesuite.analysis.buildTree()`
- Static splitters like `@epicTreeTools.splitOnExperimentDate` replace Java adapters
- Field name mapping: `cellInfo.type` ≈ `protocolSettings(source:type)`

---

## Creating Custom Splitters

Both patterns support custom splitter functions:

```matlab
function value = myCustomSplitter(epoch)
    % Extract any value from the epoch struct
    % Use epicTreeTools.getNestedValue() for deep field access

    value = epicTreeTools.getNestedValue(epoch, 'parameters.myParam');

    % OR custom logic:
    if epoch.parameters.stimulus == 'flash'
        value = 'flash';
    else
        value = 'other';
    end

    % Return value can be: numeric, char, string, logical
end
```

Then use it in your tree:
```matlab
tree.buildTreeWithSplitters({
    @epicTreeTools.splitOnCellType,
    @myCustomSplitter,              % Your custom splitter
    'cellInfo.id'
});
```

---

## When to Use Each Pattern

| Scenario | Pattern |
|----------|---------|
| Quick data exploration | Pattern 1 (file path) |
| Trying different groupings | Pattern 1 (file path) |
| Production analysis pipeline | Pattern 2 (pre-built tree) |
| Custom splitter functions | Pattern 2 (pre-built tree) |
| Reproducible workflows | Pattern 2 (pre-built tree) |
| Matching legacy scripts | Pattern 2 (pre-built tree) |

---

## Examples

See these test scripts for working examples:
- `test_launch.m` - Pattern 1 (simple file loading)
- `test_legacy_pattern.m` - Pattern 2 (pre-built tree)
- `test_exact_legacy_pattern.m` - Pattern 2 (matches legacy code exactly)
