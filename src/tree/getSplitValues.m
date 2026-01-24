function splitValues = getSplitValues(treeNode)
% GETSPLITVALUES Get all split key-value pairs from root to this node
%
% Usage:
%   splitValues = getSplitValues(treeNode)
%
% Inputs:
%   treeNode - Tree node struct (from buildTreeByKeyPaths)
%
% Outputs:
%   splitValues - Struct with fields for each split key containing its value
%                 Returns empty struct for root node
%
% Description:
%   Traverses up the tree from the given node to root, collecting all
%   split key-value pairs. This tells you the complete path/context
%   for any node in the tree.
%
% Examples:
%   % Build tree
%   tree = buildTreeByKeyPaths(epochs, {'cellInfo.type', 'parameters.contrast'});
%
%   % Navigate to a leaf
%   onpNode = getChildBySplitValue(tree, 'OnP');
%   contrastNode = getChildBySplitValue(onpNode, 0.5);
%
%   % Get full context
%   sv = getSplitValues(contrastNode);
%   % sv.cellInfo_type = 'OnP'
%   % sv.parameters_contrast = 0.5
%
% See also: buildTreeByKeyPaths, getChildBySplitValue, getLeafNodes

    splitValues = struct();

    if isempty(treeNode)
        return;
    end

    % Collect split values from this node up to root
    node = treeNode;
    while ~isempty(node)
        if isfield(node, 'splitKey') && ~isempty(node.splitKey) && ...
           isfield(node, 'splitValue')
            % Convert key path to valid field name
            fieldName = strrep(node.splitKey, '.', '_');
            fieldName = matlab.lang.makeValidName(fieldName);

            splitValues.(fieldName) = node.splitValue;
        end

        % Move to parent
        if isfield(node, 'parent')
            node = node.parent;
        else
            break;
        end
    end
end
