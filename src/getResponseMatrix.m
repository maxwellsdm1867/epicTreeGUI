function [dataMatrix, sampleRate] = getResponseMatrix(epochList, streamName)
% GETRESPONSEMATRIX Extract response data matrix from epoch list
%
% THIS IS THE CORE DATA EXTRACTION FUNCTION.
% Returns a matrix where each row is one epoch's response data.
%
% Usage:
%   [data, fs] = getResponseMatrix(epochs, 'Amp1')
%
% Inputs:
%   epochList  - Cell array of epoch structs
%   streamName - Device name (e.g., 'Amp1', 'Amp2', 'Stage')
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
% Data Format (per DATA_FORMAT_SPECIFICATION.md):
%   epoch.responses(i).device_name = 'Amp1'
%   epoch.responses(i).data = [1 x nSamples]
%   epoch.responses(i).sample_rate = 10000
%
% Legacy Equivalent:
%   dataMatrix = riekesuite.getResponseMatrix(epochList, streamName)
%
% Example:
%   epochs = tree.getAllEpochs();
%   [data, fs] = getResponseMatrix(epochs, 'Amp1');
%   meanTrace = mean(data, 1);
%   t = (1:size(data,2)) / fs * 1000;  % time in ms
%   plot(t, meanTrace);
%
% See also: getSelectedData, epicTreeTools.responsesByStreamName

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

nEpochs = length(epochList);

% Get first response to determine size and sample rate
[firstData, sampleRate] = getResponseFromEpoch(epochList{1}, streamName);

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
    [data, ~] = getResponseFromEpoch(epochList{i}, streamName);

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


function [data, sampleRate] = getResponseFromEpoch(epoch, streamName)
% GETRESPONSEFROMEPOCH Extract response data from a single epoch
%
% Searches epoch.responses array for matching device_name

data = [];
sampleRate = [];

% Check if responses field exists
if ~isfield(epoch, 'responses')
    return;
end

responses = epoch.responses;

% Handle struct array vs cell array
if isstruct(responses)
    for i = 1:length(responses)
        resp = responses(i);
        if isfield(resp, 'device_name') && strcmp(resp.device_name, streamName)
            if isfield(resp, 'data')
                data = resp.data(:)';  % Ensure row vector
            end
            if isfield(resp, 'sample_rate')
                sampleRate = resp.sample_rate;
            end
            return;
        end
    end
elseif iscell(responses)
    for i = 1:length(responses)
        resp = responses{i};
        if isfield(resp, 'device_name') && strcmp(resp.device_name, streamName)
            if isfield(resp, 'data')
                data = resp.data(:)';  % Ensure row vector
            end
            if isfield(resp, 'sample_rate')
                sampleRate = resp.sample_rate;
            end
            return;
        end
    end
end

end
