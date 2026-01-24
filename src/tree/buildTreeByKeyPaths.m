function treeNode = buildTreeByKeyPaths(epochs, keyPaths, parentNode)
% BUILDTREEBYKEYPATH Build hierarchical tree by grouping epochs on key paths
%
% Usage:
%   treeNode = buildTreeByKeyPaths(epochs, keyPaths)
%   treeNode = buildTreeByKeyPaths(epochs, keyPaths, parentNode)
%
% Inputs:
%   epochs - Cell array of epoch structs (from getAllEpochs)
%   keyPaths - Cell array of key path strings for splitting
%              e.g., {'cellInfo.type', 'parameters.contrast'}
%   parentNode - (optional) Parent node for building subtree
%
% Outputs:
%   treeNode - Struct with fields:
%              .splitKey - Key path used for this split (empty for root/leaf)
%              .splitValue - Value at this split (empty for root)
%              .children - Cell array of child treeNodes (empty for leaf)
%              .epochList - Cell array of epochs (only for leaf nodes)
%              .isLeaf - Logical flag
%              .parent - Reference to parent node (empty for root)
%
% Description:
%   Core algorithm that builds a hierarchical tree structure from a flat
%   list of epochs. Groups epochs recursively by each key path in order.
%   This is the MATLAB equivalent of Java GenericEpochTreeFactory.create().
%
% Algorithm:
%   1. If no key paths remaining: create leaf node with epochs, return
%   2. Pop first key path
%   3. Group epochs by value at that key path
%   4. For each unique value, create child node and recurse
%   5. Sort children by split value
%   6. Return tree node
%
% Examples:
%   % Build tree by cell type, then by contrast
%   data = loadEpicTreeData('experiment.mat');
%   epochs = getAllEpochs(data);
%   tree = buildTreeByKeyPaths(epochs, {'cellInfo.type', 'parameters.contrast'});
%
%   % Navigate tree
%   fprintf('Root has %d children\n', length(tree.children));
%   for i = 1:length(tree.children)
%       child = tree.children{i};
%       fprintf('  %s = %s\n', child.splitKey, string(child.splitValue));
%   end
%
% See also: getAllEpochs, getNestedValue, getLeafNodes, getChildBySplitValue

    % Handle optional parent argument
    if nargin < 3
        parentNode = [];
    end

    % Initialize tree node
    treeNode = struct();
    treeNode.parent = parentNode;

    % Base case: no more key paths - this is a leaf node
    if isempty(keyPaths)
        treeNode.splitKey = '';
        treeNode.splitValue = [];
        treeNode.children = {};
        treeNode.epochList = epochs;
        treeNode.isLeaf = true;
        return;
    end

    % Pop first key path
    keyPath = keyPaths{1};
    remainingPaths = keyPaths(2:end);

    % Group epochs by value at this key path
    groups = groupEpochsByKeyPath(epochs, keyPath);

    % Create child nodes for each unique value
    treeNode.splitKey = keyPath;
    treeNode.splitValue = [];  % Root/intermediate nodes don't have a value
    treeNode.children = {};
    treeNode.epochList = {};   % Non-leaf nodes don't store epochs directly
    treeNode.isLeaf = false;

    % Sort groups by value
    groups = sortGroupsByValue(groups);

    % Recursively build children
    for i = 1:length(groups)
        group = groups{i};

        % Build child subtree
        childNode = buildTreeByKeyPaths(group.epochs, remainingPaths, treeNode);

        % Set split info for this child
        childNode.splitKey = keyPath;
        childNode.splitValue = group.value;

        treeNode.children{end+1} = childNode;
    end
end


function groups = groupEpochsByKeyPath(epochs, keyPath)
% Group epochs by value at keyPath
% Returns cell array of structs with .value and .epochs fields

    groups = {};
    valueToIdx = containers.Map();

    for i = 1:length(epochs)
        epoch = epochs{i};
        value = getNestedValue(epoch, keyPath);

        % Convert value to string key for lookup
        valueKey = valueToString(value);

        if valueToIdx.isKey(valueKey)
            idx = valueToIdx(valueKey);
            groups{idx}.epochs{end+1} = epoch;
        else
            idx = length(groups) + 1;
            groups{idx} = struct('value', value, 'epochs', {{epoch}});
            valueToIdx(valueKey) = idx;
        end
    end
end


function groups = sortGroupsByValue(groups)
% Sort groups by their value field

    if isempty(groups)
        return;
    end

    % Extract values and types
    n = length(groups);
    values = cell(n, 1);
    for i = 1:n
        values{i} = groups{i}.value;
    end

    % Determine if all values are numeric
    allNumeric = true;
    numericValues = zeros(n, 1);
    for i = 1:n
        if isnumeric(values{i}) && isscalar(values{i})
            numericValues(i) = values{i};
        else
            allNumeric = false;
            break;
        end
    end

    if allNumeric
        % Sort numerically
        [~, sortIdx] = sort(numericValues);
    else
        % Sort as strings
        strValues = cell(n, 1);
        for i = 1:n
            strValues{i} = valueToString(values{i});
        end
        [~, sortIdx] = sort(strValues);
    end

    groups = groups(sortIdx);
end


function str = valueToString(value)
% Convert any value to a string for grouping/sorting

    if isempty(value)
        str = '__empty__';
    elseif ischar(value)
        str = value;
    elseif isstring(value)
        str = char(value);
    elseif isnumeric(value)
        if isscalar(value)
            str = sprintf('%.10g', value);
        else
            str = mat2str(value);
        end
    elseif islogical(value)
        if value
            str = 'true';
        else
            str = 'false';
        end
    elseif iscell(value)
        str = '__cell__';
    elseif isstruct(value)
        str = '__struct__';
    else
        str = '__unknown__';
    end
end
