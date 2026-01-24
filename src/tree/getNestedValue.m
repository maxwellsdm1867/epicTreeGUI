function value = getNestedValue(obj, keyPath)
% GETNESTEDVALUE Access nested struct fields using dot notation key path
%
% Usage:
%   value = getNestedValue(obj, keyPath)
%
% Inputs:
%   obj - Struct or object to access
%   keyPath - Dot-separated path string (e.g., 'parameters.contrast')
%
% Outputs:
%   value - Value at the specified path, or [] if path doesn't exist
%
% Description:
%   Enables accessing deeply nested struct fields using a single string.
%   This is the MATLAB equivalent of Java's KeyPathGetter and enables
%   dynamic tree splitting by any parameter.
%
% Examples:
%   epoch.parameters.contrast = 0.5;
%   val = getNestedValue(epoch, 'parameters.contrast');  % Returns 0.5
%
%   epoch.cellInfo.type = 'OnP';
%   val = getNestedValue(epoch, 'cellInfo.type');  % Returns 'OnP'
%
%   % Missing path returns []
%   val = getNestedValue(epoch, 'parameters.missing');  % Returns []
%
% See also: getAllEpochs, buildTreeByKeyPaths, sortEpochsByKey

    value = [];

    if isempty(obj) || isempty(keyPath)
        return;
    end

    % Split key path by dots
    parts = strsplit(keyPath, '.');

    % Traverse the path
    current = obj;
    for i = 1:length(parts)
        part = parts{i};

        if isempty(part)
            continue;
        end

        % Handle struct
        if isstruct(current)
            if isfield(current, part)
                current = current.(part);
            else
                % Field doesn't exist
                return;
            end
        % Handle cell array (take first element if single)
        elseif iscell(current) && numel(current) == 1
            current = current{1};
            if isstruct(current) && isfield(current, part)
                current = current.(part);
            else
                return;
            end
        % Handle object with properties
        elseif isobject(current)
            try
                current = current.(part);
            catch
                return;
            end
        else
            % Can't traverse further
            return;
        end
    end

    value = current;
end
