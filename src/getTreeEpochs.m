function epochList = getTreeEpochs(treeNode, onlySelected)
% GETTREEEPOCHS Get all epochs under a tree node
%
% Convenience wrapper for epicTreeTools.getAllEpochs().
% Used by singleEpoch viewer, analysis functions, and other utilities.
%
% Usage:
%   epochs = getTreeEpochs(tree)           % All epochs
%   epochs = getTreeEpochs(tree, true)     % Only selected epochs
%
% Inputs:
%   treeNode     - epicTreeTools node
%   onlySelected - (optional) If true, only return epochs with isSelected=true
%                  Default: false
%
% Output:
%   epochList - Cell array of epoch structs
%
% Description:
%   If treeNode is a leaf, returns its epochList directly.
%   If treeNode is an internal node, recursively collects epochs from all
%   leaf nodes beneath it.
%
% Legacy Equivalent:
%   epochList = getTreeEpochs(epochTree)
%   epochList = getTreeEpochs(epochTree, true)  % only selected
%
% Example:
%   % Get all epochs under a cell type node
%   onpNode = tree.childBySplitValue('OnP');
%   epochs = getTreeEpochs(onpNode);
%   fprintf('Found %d epochs\n', length(epochs));
%
%   % Get only selected epochs
%   selectedEpochs = getTreeEpochs(onpNode, true);
%
% See also: epicTreeTools.getAllEpochs, getSelectedData

% Default: return all epochs
if nargin < 2
    onlySelected = false;
end

% Validate input
if ~isa(treeNode, 'epicTreeTools')
    error('getTreeEpochs:InvalidInput', 'Input must be an epicTreeTools node');
end

% Delegate to tree method
epochList = treeNode.getAllEpochs(onlySelected);

end
