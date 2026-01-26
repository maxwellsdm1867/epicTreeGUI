%% START HERE - Launch EpicTreeGUI
% This is the simplest way to launch the GUI with all paths configured

close all; clear; clc;

fprintf('=== EpicTreeGUI Startup ===\n\n');

%% 1. Add paths
addpath('src/gui');
addpath('src/tree');
addpath('src/splitters');
addpath('src/utilities');
addpath('src/config');
addpath('src');
fprintf('✓ Paths added\n');

%% 2. Configure H5 directory (CRITICAL!)
h5Dir = '/Users/maxwellsdm/Documents/epicTreeTest/h5';
epicTreeConfig('h5_dir', h5Dir);
fprintf('✓ H5 directory set: %s\n', h5Dir);

%% 3. Load data and build tree
dataFile = '/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat';
fprintf('✓ Loading data...\n');
[data, ~] = loadEpicTreeData(dataFile);
fprintf('  Loaded %d epochs\n', length(data));

%% 4. Build tree structure
fprintf('✓ Building tree...\n');
tree = epicTreeTools(data);
tree.buildTreeWithSplitters({
    @epicTreeTools.splitOnCellType,
    @epicTreeTools.splitOnProtocol
});
fprintf('  Tree has %d cell types\n', tree.childrenLength());

%% 5. Launch GUI
fprintf('✓ Launching GUI...\n\n');
gui = epicTreeGUI(tree);

fprintf('=== READY! ===\n');
fprintf('Click on nodes to load data from H5 files\n');
fprintf('- Click protocol (e.g., "SingleSpot") → See all epochs\n');
fprintf('- Click individual epoch (e.g., "#1") → See single trace\n');
