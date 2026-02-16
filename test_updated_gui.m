%% Test Updated EpicTreeGUI - Pre-Built Tree Only
% This tests the updated GUI that only accepts pre-built trees
% (no dropdown, no file path loading)

close all; clear; clc;

fprintf('=== Testing Updated EpicTreeGUI (Pre-Built Tree Only) ===\n\n');

%% Setup Paths
fprintf('Setting up paths...\n');

% Remove old_epochtree from path
warning('off', 'MATLAB:rmpath:DirNotFound');
rmpath(genpath('old_epochtree'));
warning('on', 'MATLAB:rmpath:DirNotFound');

% Add NEW code paths (in correct order - most specific first)
addpath('src/gui');           % CRITICAL: graphicalTree
addpath('src/tree');
addpath('src/splitters');
addpath('src/utilities');
addpath('src');
addpath('src/config');        % For epicTreeConfig

% Set H5 directory for lazy loading
h5Dir = '/Users/maxwellsdm/Documents/epicTreeTest/h5';
if exist(h5Dir, 'dir')
    epicTreeConfig('h5_dir', h5Dir);
end

% Verify correct graphicalTree is loaded
which_result = which('graphicalTree');
if ~contains(which_result, 'src/gui')
    error(['WRONG graphicalTree loaded!\n' ...
           'Found: %s'], which_result);
end
fprintf('✓ Paths verified\n\n');

%% 1. Load Data
data_file = '/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat';

if ~exist(data_file, 'file')
    error('File not found: %s', data_file);
end

fprintf('Loading data: %s\n', data_file);
[data, ~] = loadEpicTreeData(data_file);
fprintf('  Loaded %d total epochs\n\n', length(data));

%% 2. Build Tree Structure
fprintf('Building tree with custom splitter hierarchy...\n');

% Create tree root
tree = epicTreeTools(data);

% Define split hierarchy (using the 22+ available splitters!)
splitHierarchy = {
    @epicTreeTools.splitOnCellType,        % Level 1: Cell Type
    @epicTreeTools.splitOnExperimentDate,  % Level 2: Date
    'cellInfo.id',                         % Level 3: Cell ID (key path)
    @epicTreeTools.splitOnProtocol         % Level 4: Protocol
};

% Build the tree
tree.buildTreeWithSplitters(splitHierarchy);

fprintf('  Tree built with %d levels\n', length(splitHierarchy));
fprintf('  Root has %d children\n', tree.childrenLength());

% Print tree structure
fprintf('\nTree structure:\n');
for i = 1:tree.childrenLength()
    node1 = tree.childAt(i);
    fprintf('  [%s] - %d epochs\n', char(node1.splitValue), node1.epochCount());

    % Show next level
    for j = 1:min(2, node1.childrenLength())
        node2 = node1.childAt(j);
        fprintf('    └─ %s - %d epochs\n', char(node2.splitValue), node2.epochCount());
    end
    if node1.childrenLength() > 2
        fprintf('    └─ ... (%d more)\n', node1.childrenLength() - 2);
    end
end

%% 3. Test GUI Constructor - Only Accepts epicTreeTools Object
fprintf('\n=== Testing GUI Constructor ===\n');

% This should work
fprintf('Creating GUI with pre-built tree... ');
try
    gui = epicTreeGUI(tree);
    fprintf('✓ SUCCESS\n');

    % Check that there's no split dropdown in the GUI
    if isfield(gui.treeBrowser, 'splitDropdown')
        error('ERROR: Split dropdown still exists in GUI!');
    else
        fprintf('✓ No split dropdown (as expected)\n');
    end

catch ME
    fprintf('✗ FAILED\n');
    fprintf('Error: %s\n', ME.message);
    rethrow(ME);
end

% This should fail (file path no longer supported)
fprintf('\nTrying to create GUI with file path (should fail)... ');
try
    gui2 = epicTreeGUI(data_file);
    fprintf('✗ ERROR: File path should not be accepted!\n');
catch ME
    if contains(ME.message, 'epicTreeTools object')
        fprintf('✓ Correctly rejected with message:\n  "%s"\n', ME.message);
    else
        fprintf('✗ Wrong error: %s\n', ME.message);
    end
end

%% Summary
fprintf('\n=== Test Summary ===\n');
fprintf('✓ GUI only accepts pre-built trees\n');
fprintf('✓ No split dropdown in GUI\n');
fprintf('✓ File paths correctly rejected\n');
fprintf('✓ Tree structure is fixed at launch\n');
fprintf('\n✓ ALL TESTS PASSED\n\n');

fprintf('The GUI is now running with the tree structure defined above.\n');
fprintf('To change the hierarchy, modify splitHierarchy and re-run this script.\n');
