function [dataMatrix, sampleRate] = getResponseMatrix(epochList, streamName, h5_file)
% GETRESPONSEMATRIX Extract response data matrix from epoch list
%
% THIS IS THE CORE DATA EXTRACTION FUNCTION.
% Returns a matrix where each row is one epoch's response data.
%
% Usage:
%   [data, fs] = getResponseMatrix(epochs, 'Amp1')
%   [data, fs] = getResponseMatrix(epochs, 'Amp1', '/path/to/file.h5')
%
% Inputs:
%   epochList  - Cell array of epoch structs
%   streamName - Device name (e.g., 'Amp1', 'Amp2', 'Stage')
%   h5_file    - (Optional) Path to H5 file for lazy loading
%
% Outputs:
%   dataMatrix - [nEpochs x nSamples] response data matrix
%   sampleRate - Sample rate in Hz (from first epoch)
%
% Description:
%   For each epoch, finds the response with matching device_name and
%   extracts the data field. All epochs are assumed to have the same
%   number of samples (pads/truncates if needed).
%
%   If response.data is empty, attempts to load from H5 file using
%   the h5_path field. The h5_file can be passed explicitly or may
%   be stored in epoch.h5_file.
%
% Data Format (per DATA_FORMAT_SPECIFICATION.md):
%   epoch.responses(i).device_name = 'Amp1'
%   epoch.responses(i).data = [1 x nSamples]
%   epoch.responses(i).sample_rate = 10000
%   epoch.responses(i).h5_path = '/experiment-.../responses/Amp1-...'
%
% Legacy Equivalent:
%   dataMatrix = riekesuite.getResponseMatrix(epochList, streamName)
%
% Example:
%   epochs = tree.getAllEpochs();
%   h5_file = '/Users/data/2025-12-02_F.h5';
%   [data, fs] = getResponseMatrix(epochs, 'Amp1', h5_file);
%   meanTrace = mean(data, 1);
%   t = (1:size(data,2)) / fs * 1000;  % time in ms
%   plot(t, meanTrace);
%
% See also: getSelectedData, epicTreeTools.responsesByStreamName, loadH5ResponseData

% Validate input
if isempty(epochList)
    dataMatrix = [];
    sampleRate = [];
    return;
end

% Ensure epochList is a cell array
if ~iscell(epochList)
    epochList = {epochList};
end

% Handle optional h5_file parameter
if nargin < 3
    h5_file = '';
end

nEpochs = length(epochList);

% Get first response to determine size and sample rate
[firstData, sampleRate] = getResponseFromEpoch(epochList{1}, streamName, h5_file);

if isempty(firstData)
    warning('getResponseMatrix:StreamNotFound', ...
        'Response stream "%s" not found in first epoch', streamName);
    dataMatrix = [];
    return;
end

nSamples = length(firstData);

% Pre-allocate output matrix
dataMatrix = zeros(nEpochs, nSamples);
dataMatrix(1, :) = firstData;

% Extract data from remaining epochs
for i = 2:nEpochs
    [data, ~] = getResponseFromEpoch(epochList{i}, streamName, h5_file);

    if isempty(data)
        % Stream not found - leave as zeros
        warning('getResponseMatrix:StreamNotFound', ...
            'Response stream "%s" not found in epoch %d', streamName, i);
        continue;
    end

    % Handle variable length data
    if length(data) == nSamples
        dataMatrix(i, :) = data;
    elseif length(data) < nSamples
        % Pad with zeros
        dataMatrix(i, 1:length(data)) = data;
    else
        % Truncate
        dataMatrix(i, :) = data(1:nSamples);
    end
end

end


function [data, sampleRate] = getResponseFromEpoch(epoch, streamName, h5_file)
% GETRESPONSEFROMEPOCH Extract response data from a single epoch
%
% Searches epoch.responses array for matching device_name.
% Supports lazy loading from H5 files when data field is empty.
%
% Inputs:
%   epoch      - Epoch struct with responses field
%   streamName - Device name to find (e.g., 'Amp1')
%   h5_file    - (Optional) Path to H5 file for lazy loading

data = [];
sampleRate = [];

if nargin < 3
    h5_file = '';
end

% Check if responses field exists
if ~isfield(epoch, 'responses')
    return;
end

responses = epoch.responses;

% Find the matching response
resp = [];
if isstruct(responses)
    for i = 1:length(responses)
        if isfield(responses(i), 'device_name') && strcmp(responses(i).device_name, streamName)
            resp = responses(i);
            break;
        end
    end
elseif iscell(responses)
    for i = 1:length(responses)
        r = responses{i};
        if isfield(r, 'device_name') && strcmp(r.device_name, streamName)
            resp = r;
            break;
        end
    end
end

if isempty(resp)
    return;
end

% Get sample rate
if isfield(resp, 'sample_rate')
    sampleRate = resp.sample_rate;
end

% Get data - try direct field first, then lazy load from H5
if isfield(resp, 'data') && ~isempty(resp.data)
    data = resp.data(:)';  % Ensure row vector
else
    % Lazy load from H5 file
    % Need h5_path in response, and h5_file from parameter or response
    hasH5Path = isfield(resp, 'h5_path') && ~isempty(resp.h5_path);

    % Use h5_file from: 1) parameter, 2) response field, 3) epoch field
    actualH5File = h5_file;
    if isempty(actualH5File) && isfield(resp, 'h5_file') && ~isempty(resp.h5_file)
        actualH5File = resp.h5_file;
    end
    if isempty(actualH5File) && isfield(epoch, 'h5_file') && ~isempty(epoch.h5_file)
        actualH5File = epoch.h5_file;
    end

    if hasH5Path && ~isempty(actualH5File)
        try
            data = loadH5ResponseData(resp, actualH5File);
            if ~isempty(data)
                data = data(:)';  % Ensure row vector
            end
        catch ME
            warning('getResponseFromEpoch:H5LoadFailed', ...
                'Failed to load H5 data: %s', ME.message);
        end
    elseif hasH5Path
        warning('getResponseFromEpoch:noH5File', ...
            'Response has h5_path but no h5_file. Set h5_dir using epicTreeConfig.');
    end
end

end
