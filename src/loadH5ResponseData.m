function data = loadH5ResponseData(response)
% LOADH5RESPONSEDATA Load response data from H5 file on demand
%
% This function implements lazy loading of response data. The exported
% .mat file contains only paths to H5 files, and actual data is loaded
% when needed using this function.
%
% Usage:
%   data = loadH5ResponseData(response)
%
% Input:
%   response - Response struct with fields:
%       .h5_file    - Path to H5 file
%       .h5_path    - Path within H5 file
%       .data       - May be empty (will be loaded)
%
% Output:
%   data - Response data as column vector
%
% Example:
%   epoch = allEpochs{1};
%   resp = epoch.responses(1);  % or epoch.responses{1}
%   data = loadH5ResponseData(resp);
%
% See also: getResponseMatrix, getSelectedData

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

% Get H5 file path
if ~isfield(response, 'h5_file') || isempty(response.h5_file)
    warning('loadH5ResponseData:noPath', 'No h5_file path in response');
    return;
end

h5_file = response.h5_file;

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
try
    % Construct full path to data
    dataPath = [h5_path '/data/quantity'];

    % Try reading with h5read
    data = h5read(h5_file, ['/' dataPath]);
    data = data(:);  % Ensure column vector

catch ME
    % Try alternative path structure
    try
        info = h5info(h5_file, ['/' h5_path]);

        % Look for data group
        for i = 1:length(info.Groups)
            if strcmp(info.Groups(i).Name, [h5_path '/data']) || ...
               endsWith(info.Groups(i).Name, '/data')
                dataGroup = info.Groups(i);

                % Look for quantity dataset
                for j = 1:length(dataGroup.Datasets)
                    if strcmp(dataGroup.Datasets(j).Name, 'quantity')
                        fullPath = [dataGroup.Name '/quantity'];
                        data = h5read(h5_file, fullPath);
                        data = data(:);
                        return;
                    end
                end
            end
        end

        warning('loadH5ResponseData:noData', 'Could not find data in %s', h5_path);

    catch ME2
        warning('loadH5ResponseData:readError', 'Error reading H5 file: %s\n%s', ...
            ME.message, ME2.message);
    end
end

end
