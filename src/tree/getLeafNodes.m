function leafNodes = getLeafNodes(treeNode)
% GETLEAFNODES Get all leaf nodes from a tree node
%
% Usage:
%   leafNodes = getLeafNodes(treeNode)
%
% Inputs:
%   treeNode - Tree node struct (from buildTreeByKeyPaths)
%
% Outputs:
%   leafNodes - Cell array of all leaf nodes under this node
%               Returns {treeNode} if treeNode is itself a leaf
%
% Description:
%   Recursively traverses the tree to find all leaf nodes (nodes that
%   contain epochs rather than children). This is useful for batch
%   processing all conditions in a tree.
%
% Examples:
%   % Get all leaf nodes from root
%   tree = buildTreeByKeyPaths(epochs, {'cellInfo.type', 'parameters.contrast'});
%   leaves = getLeafNodes(tree);
%   fprintf('Tree has %d leaves\n', length(leaves));
%
%   % Process all leaves
%   for i = 1:length(leaves)
%       leaf = leaves{i};
%       epochs = leaf.epochList;
%       sv = getSplitValues(leaf);
%       fprintf('Processing %s = %s with %d epochs\n', ...
%           leaf.splitKey, string(leaf.splitValue), length(epochs));
%   end
%
% See also: buildTreeByKeyPaths, getSplitValues, getChildBySplitValue

    leafNodes = {};

    if isempty(treeNode)
        return;
    end

    % Check if this is a leaf node
    if isfield(treeNode, 'isLeaf') && treeNode.isLeaf
        leafNodes = {treeNode};
        return;
    end

    % Not a leaf - recurse to children
    if isfield(treeNode, 'children') && ~isempty(treeNode.children)
        for i = 1:length(treeNode.children)
            childLeaves = getLeafNodes(treeNode.children{i});
            leafNodes = [leafNodes; childLeaves(:)];
        end
    else
        % No children but also not marked as leaf - treat as leaf
        if isfield(treeNode, 'epochList') && ~isempty(treeNode.epochList)
            leafNodes = {treeNode};
        end
    end
end
