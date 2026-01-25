function data = loadH5ResponseData(response, h5_file)
% LOADH5RESPONSEDATA Load response data from H5 file on demand
%
% This function implements lazy loading of response data. The exported
% .mat file contains h5_path (internal path within H5 file), and the
% h5_file can be passed as a parameter or derived from configuration.
%
% Usage:
%   data = loadH5ResponseData(response)           % Uses response.h5_file
%   data = loadH5ResponseData(response, h5_file)  % Uses provided h5_file
%
% Input:
%   response - Response struct with fields:
%       .h5_path    - Path within H5 file (e.g., '/experiment-.../responses/Amp1-...')
%       .h5_file    - (Optional) Path to H5 file
%       .data       - May be empty (will be loaded)
%   h5_file  - (Optional) Path to H5 file, overrides response.h5_file
%
% Output:
%   data - Response data as column vector
%
% Example:
%   epoch = allEpochs{1};
%   resp = epoch.responses(1);
%   data = loadH5ResponseData(resp, '/path/to/experiment.h5');
%
% See also: getResponseMatrix, getSelectedData, getH5FilePath

data = [];

% Handle cell array of responses
if iscell(response)
    response = response{1};
end

% Check if data is already loaded
if isfield(response, 'data') && ~isempty(response.data)
    data = response.data(:);
    return;
end

% Get H5 file path - prefer parameter, then response field
if nargin < 2 || isempty(h5_file)
    if isfield(response, 'h5_file') && ~isempty(response.h5_file)
        h5_file = response.h5_file;
    else
        warning('loadH5ResponseData:noH5File', ...
            'No h5_file provided and none in response struct');
        return;
    end
end

% Handle path mappings (NAS paths may differ between systems)
if ~exist(h5_file, 'file')
    % Try common path mappings
    altPaths = {
        strrep(h5_file, '/Volumes/rieke-nas/', '/Volumes/rieke/'),
        strrep(h5_file, '/Volumes/rieke/', '/Volumes/rieke-nas/'),
        strrep(h5_file, '/mnt/rieke-nas/', '/Volumes/rieke-nas/'),
    };

    for i = 1:length(altPaths)
        if exist(altPaths{i}, 'file')
            h5_file = altPaths{i};
            break;
        end
    end

    if ~exist(h5_file, 'file')
        warning('loadH5ResponseData:fileNotFound', 'H5 file not found: %s', h5_file);
        return;
    end
end

% Get H5 path within file
if ~isfield(response, 'h5_path') || isempty(response.h5_path)
    warning('loadH5ResponseData:noH5Path', 'No h5_path in response');
    return;
end

h5_path = response.h5_path;

% Clean path (remove leading slash if present)
if h5_path(1) == '/'
    h5_path = h5_path(2:end);
end

% Load data from H5 file
% The H5 structure is: h5_path/data (compound dataset with 'quantity' field)
try
    % Construct full path to data dataset
    dataPath = ['/' h5_path '/data'];

    % Read the compound dataset
    rawData = h5read(h5_file, dataPath);

    % Extract numeric values from compound dataset
    % The dataset has fields: quantity (float64), units (string)
    if isstruct(rawData)
        % Compound dataset read as struct in MATLAB
        if isfield(rawData, 'quantity')
            data = double(rawData.quantity(:));
        elseif isfield(rawData, 'Quantity')
            data = double(rawData.Quantity(:));
        else
            % Try first numeric field
            fn = fieldnames(rawData);
            for i = 1:length(fn)
                if isnumeric(rawData.(fn{i}))
                    data = double(rawData.(fn{i})(:));
                    break;
                end
            end
        end
    else
        % Simple numeric array
        data = double(rawData(:));
    end

catch ME
    % Try alternative: data might be in a subgroup
    try
        % Check if it's a group with 'quantity' dataset inside
        altPath = ['/' h5_path '/data/quantity'];
        data = h5read(h5_file, altPath);
        data = double(data(:));
    catch
        % Final fallback - try to explore the structure
        try
            info = h5info(h5_file, ['/' h5_path]);

            % Look for data in datasets or groups
            for i = 1:length(info.Datasets)
                if strcmpi(info.Datasets(i).Name, 'data')
                    data = h5read(h5_file, ['/' h5_path '/' info.Datasets(i).Name]);
                    if isstruct(data) && isfield(data, 'quantity')
                        data = double(data.quantity(:));
                    else
                        data = double(data(:));
                    end
                    return;
                end
            end

            warning('loadH5ResponseData:noData', ...
                'Could not find data in %s. Error: %s', h5_path, ME.message);

        catch ME2
            warning('loadH5ResponseData:readError', ...
                'Error reading H5 file %s path %s: %s', ...
                h5_file, h5_path, ME2.message);
        end
    end
end

end
