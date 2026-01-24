function childNode = getChildBySplitValue(treeNode, value)
% GETCHILDBYSPLITVALUE Find child node by its split value
%
% Usage:
%   childNode = getChildBySplitValue(treeNode, value)
%
% Inputs:
%   treeNode - Tree node struct (from buildTreeByKeyPaths)
%   value - Split value to search for
%
% Outputs:
%   childNode - Child node with matching split value, or [] if not found
%
% Description:
%   Navigates the tree by finding a child node that has the specified
%   split value. This is the MATLAB equivalent of Java's childBySplitValue().
%
% Examples:
%   % Find the 'OnP' cell type branch
%   onpNode = getChildBySplitValue(tree, 'OnP');
%
%   % Find contrast = 0.5 branch
%   contrastNode = getChildBySplitValue(cellTypeNode, 0.5);
%
%   % Chain navigation
%   leaf = getChildBySplitValue(getChildBySplitValue(tree, 'OnP'), 0.5);
%
% See also: buildTreeByKeyPaths, getLeafNodes, getSplitValues

    childNode = [];

    if isempty(treeNode) || ~isfield(treeNode, 'children')
        return;
    end

    if isempty(treeNode.children)
        return;
    end

    for i = 1:length(treeNode.children)
        child = treeNode.children{i};

        if ~isfield(child, 'splitValue')
            continue;
        end

        childValue = child.splitValue;

        % Check for match
        if valuesEqual(childValue, value)
            childNode = child;
            return;
        end
    end
end


function eq = valuesEqual(a, b)
% Compare two values for equality (handles different types)

    % Handle empty
    if isempty(a) && isempty(b)
        eq = true;
        return;
    end
    if isempty(a) || isempty(b)
        eq = false;
        return;
    end

    % Handle same reference
    if isequal(a, b)
        eq = true;
        return;
    end

    % Handle numeric comparison (with tolerance)
    if isnumeric(a) && isnumeric(b)
        if isscalar(a) && isscalar(b)
            eq = abs(a - b) < 1e-10;
        else
            eq = isequal(a, b);
        end
        return;
    end

    % Handle string comparison
    if (ischar(a) || isstring(a)) && (ischar(b) || isstring(b))
        eq = strcmp(char(a), char(b));
        return;
    end

    % Default: use isequal
    eq = isequal(a, b);
end
