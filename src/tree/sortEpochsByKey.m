function sortedEpochs = sortEpochsByKey(epochs, keyPath)
% SORTEPOCHSBYKEY Sort epochs by value at specified key path
%
% Usage:
%   sortedEpochs = sortEpochsByKey(epochs, keyPath)
%
% Inputs:
%   epochs - Cell array of epoch structs
%   keyPath - Dot-separated path string (e.g., 'parameters.contrast')
%
% Outputs:
%   sortedEpochs - Cell array of epochs sorted by the key path value
%
% Description:
%   Sorts epochs by the value at the specified key path. Numeric values
%   are sorted numerically, strings alphabetically. Missing values are
%   placed at the end.
%
% Examples:
%   % Sort by contrast
%   sorted = sortEpochsByKey(epochs, 'parameters.contrast');
%
%   % Sort by cell type
%   sorted = sortEpochsByKey(epochs, 'cellInfo.type');
%
%   % Sort by epoch ID
%   sorted = sortEpochsByKey(epochs, 'id');
%
% See also: getNestedValue, getAllEpochs, buildTreeByKeyPaths

    if isempty(epochs)
        sortedEpochs = epochs;
        return;
    end

    n = length(epochs);

    % Extract values for all epochs
    values = cell(n, 1);
    for i = 1:n
        values{i} = getNestedValue(epochs{i}, keyPath);
    end

    % Determine value types
    hasNumeric = false;
    hasString = false;
    hasMissing = false;

    numericValues = nan(n, 1);
    stringValues = cell(n, 1);

    for i = 1:n
        val = values{i};
        if isempty(val)
            hasMissing = true;
            stringValues{i} = char(intmax);  % Sort to end
        elseif isnumeric(val) && isscalar(val)
            hasNumeric = true;
            numericValues(i) = val;
            stringValues{i} = sprintf('%020.10f', val);
        elseif ischar(val) || isstring(val)
            hasString = true;
            stringValues{i} = char(val);
        elseif islogical(val)
            hasNumeric = true;
            numericValues(i) = double(val);
            stringValues{i} = sprintf('%d', val);
        else
            hasMissing = true;
            stringValues{i} = char(intmax);
        end
    end

    % Choose sorting strategy
    if hasNumeric && ~hasString
        % Pure numeric sort
        [~, sortIdx] = sort(numericValues, 'MissingPlacement', 'last');
    else
        % String sort (handles mixed types)
        [~, sortIdx] = sort(stringValues);
    end

    % Apply sort
    sortedEpochs = epochs(sortIdx);
end
