function response = getMeanResponseTrace(epochListOrNode, streamName, varargin)
% GETMEANRESPONSETRACE Compute mean response trace with statistics
%
% Computes mean, standard deviation, and SEM across epochs for a given
% response stream. Supports different recording types with appropriate
% processing (baseline subtraction, PSTH computation, etc.)
%
% Usage:
%   response = getMeanResponseTrace(epochs, 'Amp1')
%   response = getMeanResponseTrace(treeNode, 'Amp1')
%   response = getMeanResponseTrace(epochs, 'Amp1', 'RecordingType', 'exc')
%
% Inputs:
%   epochListOrNode - Cell array of epochs OR epicTreeTools node
%   streamName      - Response stream name (e.g., 'Amp1')
%
% Optional Parameters:
%   'RecordingType'    - 'exc', 'inh', 'extracellular', 'iClamp', 'raw'
%                        Default: 'raw' (no baseline subtraction)
%   'BaselineSubtract' - true/false. Default: true for exc/inh
%   'PSTHsigma'        - Gaussian smoothing sigma for PSTH (ms). Default: 10
%   'OnlySelected'     - Only use selected epochs. Default: true
%
% Output:
%   response - Struct with fields:
%       .mean       - Mean trace [1 x nSamples]
%       .stdev      - Standard deviation [1 x nSamples]
%       .SEM        - Standard error of mean [1 x nSamples]
%       .n          - Number of epochs
%       .timeVector - Time in seconds [1 x nSamples]
%       .sampleRate - Sample rate in Hz
%       .units      - Units string ('pA', 'mV', 'spikes/s')
%       .baseline   - Mean baseline value (if subtracted)
%
% Example:
%   % Get mean excitatory current
%   resp = getMeanResponseTrace(treeNode, 'Amp1', 'RecordingType', 'exc');
%   plot(resp.timeVector * 1000, resp.mean);
%   xlabel('Time (ms)'); ylabel(resp.units);
%
% See also: getSelectedData, getResponseMatrix, getResponseAmplitudeStats

% Parse inputs
ip = inputParser;
ip.addRequired('epochListOrNode');
ip.addRequired('streamName', @ischar);
ip.addParameter('RecordingType', 'raw', @ischar);
ip.addParameter('BaselineSubtract', [], @islogical);
ip.addParameter('PSTHsigma', 10, @isnumeric);
ip.addParameter('OnlySelected', true, @islogical);
ip.parse(epochListOrNode, streamName, varargin{:});

recordingType = lower(ip.Results.RecordingType);
PSTHsigma = ip.Results.PSTHsigma;
onlySelected = ip.Results.OnlySelected;

% Determine baseline subtraction default based on recording type
if isempty(ip.Results.BaselineSubtract)
    baselineSubtract = ismember(recordingType, {'exc', 'inh'});
else
    baselineSubtract = ip.Results.BaselineSubtract;
end

% Get epochs
if isa(epochListOrNode, 'epicTreeTools')
    epochs = epochListOrNode.getAllEpochs(onlySelected);
elseif iscell(epochListOrNode)
    if onlySelected
        epochs = {};
        for i = 1:length(epochListOrNode)
            ep = epochListOrNode{i};
            if ~isfield(ep, 'isSelected') || ep.isSelected
                epochs{end+1} = ep;
            end
        end
        epochs = epochs(:);
    else
        epochs = epochListOrNode;
    end
else
    error('Input must be epicTreeTools node or cell array of epochs');
end

% Initialize output
response = struct();
response.n = length(epochs);

if response.n == 0
    response.mean = [];
    response.stdev = [];
    response.SEM = [];
    response.timeVector = [];
    response.sampleRate = [];
    response.units = '';
    response.baseline = [];
    return;
end

% Get h5_file from first epoch if available (for lazy loading)
h5_file = '';
if ~isempty(epochs)
    epoch1 = epochs{1};
    if isfield(epoch1, 'h5_file') && ~isempty(epoch1.h5_file)
        h5_file = epoch1.h5_file;
    end
end

% Get response data matrix (pass h5_file for lazy loading)
[dataMatrix, sampleRate] = getResponseMatrix(epochs, streamName, h5_file);

if isempty(dataMatrix)
    response.mean = [];
    response.stdev = [];
    response.SEM = [];
    response.timeVector = [];
    response.sampleRate = [];
    response.units = '';
    response.baseline = [];
    return;
end

% Ensure sampleRate is a scalar double
if iscell(sampleRate)
    sampleRate = sampleRate{1};
end
sampleRate = double(sampleRate);
response.sampleRate = sampleRate;

nSamples = size(dataMatrix, 2);
response.timeVector = (0:nSamples-1) / sampleRate;

% Get timing parameters for baseline
preTime = 0;
if ~isempty(epochs)
    epoch1 = epochs{1};
    if isfield(epoch1, 'parameters') && isfield(epoch1.parameters, 'preTime')
        preTime = epoch1.parameters.preTime / 1000;  % Convert ms to s
    end
end
baselinePoints = max(1, round(preTime * sampleRate));

% Process based on recording type
switch recordingType
    case 'extracellular'
        % Convert spike times to PSTH
        response.units = 'spikes/s';

        % Get spike times for each epoch
        spikeTimes = cell(response.n, 1);
        for i = 1:response.n
            resp = epicTreeTools.getResponseByName(epochs{i}, streamName);
            if ~isempty(resp) && isfield(resp, 'spike_times')
                spikeTimes{i} = resp.spike_times / 1000;  % Convert to seconds
            else
                spikeTimes{i} = [];
            end
        end

        % Compute PSTH
        dataMatrix = computePSTH(spikeTimes, response.timeVector, PSTHsigma/1000);
        response.baseline = [];

    case {'exc', 'inh'}
        % Voltage clamp currents
        response.units = 'pA';

        if baselineSubtract && baselinePoints > 1
            % Baseline subtract each trace
            baselines = mean(dataMatrix(:, 1:baselinePoints), 2);
            dataMatrix = dataMatrix - baselines;
            response.baseline = mean(baselines);
        else
            response.baseline = [];
        end

    case 'iclamp'
        % Current clamp voltage
        response.units = 'mV';

        if baselineSubtract && baselinePoints > 1
            baselines = mean(dataMatrix(:, 1:baselinePoints), 2);
            dataMatrix = dataMatrix - baselines;
            response.baseline = mean(baselines);
        else
            response.baseline = [];
        end

    otherwise  % 'raw'
        response.units = 'AU';
        response.baseline = [];
end

% Compute statistics
response.mean = mean(dataMatrix, 1);
response.stdev = std(dataMatrix, [], 1);
response.SEM = response.stdev / sqrt(response.n);

end


function psth = computePSTH(spikeTimes, timeVector, sigma)
% COMPUTEPSTH Compute PSTH from spike times using Gaussian kernel
%
% Inputs:
%   spikeTimes  - Cell array of spike time vectors (seconds)
%   timeVector  - Time vector (seconds)
%   sigma       - Gaussian kernel sigma (seconds)
%
% Output:
%   psth - [nTrials x nTimePoints] firing rate matrix (spikes/s)

nTrials = length(spikeTimes);
nTimePoints = length(timeVector);
dt = timeVector(2) - timeVector(1);

% Create Gaussian kernel
kernelWidth = ceil(4 * sigma / dt);
kernelX = (-kernelWidth:kernelWidth) * dt;
kernel = exp(-kernelX.^2 / (2 * sigma^2));
kernel = kernel / (sigma * sqrt(2 * pi));  % Normalize to give rate

psth = zeros(nTrials, nTimePoints);

for i = 1:nTrials
    spikes = spikeTimes{i};
    if isempty(spikes)
        continue;
    end

    % Create spike train
    spikeTrain = zeros(1, nTimePoints);
    for j = 1:length(spikes)
        idx = find(timeVector >= spikes(j), 1, 'first');
        if ~isempty(idx) && idx <= nTimePoints
            spikeTrain(idx) = spikeTrain(idx) + 1;
        end
    end

    % Convolve with kernel
    smoothed = conv(spikeTrain, kernel, 'same');
    psth(i, :) = smoothed;
end

end
