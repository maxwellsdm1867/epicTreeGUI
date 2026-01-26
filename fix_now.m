%% EMERGENCY PATH FIX
% Run this if you're getting the "brace indexing" error
%
% This script forcefully clears the old graphicalTree from memory
% and ensures the new one is loaded.

fprintf('\n');
fprintf('============================================\n');
fprintf('  EMERGENCY PATH FIX FOR GRAPHICALTREE\n');
fprintf('============================================\n\n');

%% Step 1: Close all figures
fprintf('Step 1: Closing all GUI windows...\n');
close all;
fprintf('   ✓ Done\n\n');

%% Step 2: Clear workspace
fprintf('Step 2: Clearing workspace...\n');
clear classes;
clear all;
fprintf('   ✓ Done\n\n');

%% Step 3: Remove old code from path
fprintf('Step 3: Removing old_epochtree from path...\n');
warning('off', 'MATLAB:rmpath:DirNotFound');
rmpath(genpath('old_epochtree'));
warning('on', 'MATLAB:rmpath:DirNotFound');
fprintf('   ✓ Done\n\n');

%% Step 4: Add new code to path
fprintf('Step 4: Adding new code to path...\n');
addpath('src/gui');
addpath('src/tree');
addpath('src/splitters');
addpath('src/utilities');
addpath('src');
fprintf('   ✓ Done\n\n');

%% Step 5: Verify
fprintf('Step 5: Verifying graphicalTree...\n');
which_result = which('graphicalTree');
fprintf('   Location: %s\n', which_result);

if contains(which_result, 'src/gui')
    fprintf('   ✅ SUCCESS! Correct version loaded.\n\n');
    fprintf('You can now run:\n');
    fprintf('   >> run test_epoch_display.m\n');
    fprintf('   >> run test_legacy_pattern.m\n\n');
else
    fprintf('   ❌ STILL USING WRONG VERSION!\n\n');
    fprintf('   The old graphicalTree is stuck in memory.\n');
    fprintf('   You MUST:\n');
    fprintf('   1. Close MATLAB completely (File > Exit)\n');
    fprintf('   2. Restart MATLAB\n');
    fprintf('   3. cd(''/Users/maxwellsdm/Documents/GitHub/epicTreeGUI'')\n');
    fprintf('   4. Run: restoredefaultpath\n');
    fprintf('   5. Run: fix_now\n\n');
end

fprintf('============================================\n\n');
