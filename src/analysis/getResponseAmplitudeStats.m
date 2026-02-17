function stats = getResponseAmplitudeStats(epochListOrNode, streamName, varargin)
% GETRESPONSEAMPLITUDESTATS Compute response amplitude statistics
%
% Computes peak amplitude, integrated response, and other statistics
% for a collection of epochs.
%
% Usage:
%   stats = getResponseAmplitudeStats(epochs, 'Amp1')
%   stats = getResponseAmplitudeStats(treeNode, 'Amp1', 'ResponseWindow', [0.5 1.5])
%
% Inputs:
%   epochListOrNode - Cell array of epochs OR epicTreeTools node
%   streamName      - Response stream name (e.g., 'Amp1')
%
% Optional Parameters:
%   'RecordingType'   - 'exc', 'inh', 'extracellular'. Default: 'exc'
%   'ResponseWindow'  - [startTime endTime] in seconds for analysis window
%                       Default: uses preTime to preTime+stimTime
%   'BaselineWindow'  - [startTime endTime] in seconds for baseline
%                       Default: [0 preTime]
%   'OnlySelected'    - Only use selected epochs. Default: true
%
% Output:
%   stats - Struct with fields:
%       .peakAmplitude     - Peak response amplitude [nEpochs x 1]
%       .peakTime          - Time of peak [nEpochs x 1]
%       .integratedResponse - Time-integrated response [nEpochs x 1]
%       .meanAmplitude     - Mean amplitude in response window [nEpochs x 1]
%       .baseline          - Baseline value [nEpochs x 1]
%
%       .mean_peak         - Mean of peak amplitudes
%       .std_peak          - Std of peak amplitudes
%       .sem_peak          - SEM of peak amplitudes
%       .mean_integrated   - Mean of integrated responses
%       .std_integrated    - Std of integrated responses
%       .sem_integrated    - SEM of integrated responses
%
%       .n                 - Number of epochs
%       .units             - Units string
%
% Example:
%   stats = getResponseAmplitudeStats(treeNode, 'Amp1', 'RecordingType', 'exc');
%   bar([stats.mean_peak, stats.mean_integrated]);
%   errorbar([1 2], [stats.mean_peak, stats.mean_integrated], ...
%            [stats.sem_peak, stats.sem_integrated]);
%
% See also: getMeanResponseTrace, getSelectedData

% Parse inputs
ip = inputParser;
ip.addRequired('epochListOrNode');
ip.addRequired('streamName', @ischar);
ip.addParameter('RecordingType', 'exc', @ischar);
ip.addParameter('ResponseWindow', [], @isnumeric);
ip.addParameter('BaselineWindow', [], @isnumeric);
ip.addParameter('OnlySelected', true, @islogical);
ip.parse(epochListOrNode, streamName, varargin{:});

recordingType = lower(ip.Results.RecordingType);
responseWindow = ip.Results.ResponseWindow;
baselineWindow = ip.Results.BaselineWindow;
onlySelected = ip.Results.OnlySelected;

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
stats = struct();
stats.n = length(epochs);

if stats.n == 0
    stats.peakAmplitude = [];
    stats.peakTime = [];
    stats.integratedResponse = [];
    stats.meanAmplitude = [];
    stats.baseline = [];
    stats.mean_peak = NaN;
    stats.std_peak = NaN;
    stats.sem_peak = NaN;
    stats.mean_integrated = NaN;
    stats.std_integrated = NaN;
    stats.sem_integrated = NaN;
    stats.units = '';
    return;
end

% Get response data matrix
[dataMatrix, sampleRate] = getResponseMatrix(epochs, streamName);

if isempty(dataMatrix)
    stats.peakAmplitude = [];
    stats.peakTime = [];
    stats.integratedResponse = [];
    stats.meanAmplitude = [];
    stats.baseline = [];
    stats.mean_peak = NaN;
    stats.std_peak = NaN;
    stats.sem_peak = NaN;
    stats.mean_integrated = NaN;
    stats.std_integrated = NaN;
    stats.sem_integrated = NaN;
    stats.units = '';
    return;
end

nSamples = size(dataMatrix, 2);
timeVector = (0:nSamples-1) / sampleRate;

% Get timing parameters
preTime = 0;
stimTime = 1;
if ~isempty(epochs)
    epoch1 = epochs{1};
    if isfield(epoch1, 'parameters')
        params = epoch1.parameters;
        if isfield(params, 'preTime')
            preTime = params.preTime / 1000;  % ms to s
        end
        if isfield(params, 'stimTime')
            stimTime = params.stimTime / 1000;  % ms to s
        end
    end
end

% Set default windows
if isempty(baselineWindow)
    baselineWindow = [0, preTime];
end
if isempty(responseWindow)
    responseWindow = [preTime, preTime + stimTime];
end

% Convert windows to indices
baselineIdx = timeVector >= baselineWindow(1) & timeVector < baselineWindow(2);
responseIdx = timeVector >= responseWindow(1) & timeVector < responseWindow(2);

if sum(baselineIdx) == 0
    baselineIdx(1:min(10, nSamples)) = true;
end
if sum(responseIdx) == 0
    responseIdx = true(1, nSamples);
end

% Set units
switch recordingType
    case 'exc'
        stats.units = 'pA';
    case 'inh'
        stats.units = 'pA';
    case 'extracellular'
        stats.units = 'spikes';
    otherwise
        stats.units = 'AU';
end

% Compute baseline for each epoch
stats.baseline = mean(dataMatrix(:, baselineIdx), 2, 'omitnan');

% Baseline subtract
dataSubtracted = dataMatrix - stats.baseline;

% Extract response window data
responseData = dataSubtracted(:, responseIdx);
responseTime = timeVector(responseIdx);

% Determine sign for peak finding based on recording type
if strcmp(recordingType, 'inh')
    % Inhibitory currents are positive (outward)
    signMultiplier = 1;
else
    % Excitatory currents are negative (inward), take absolute
    signMultiplier = -1;
end

% Compute statistics for each epoch
nEpochs = stats.n;
stats.peakAmplitude = zeros(nEpochs, 1);
stats.peakTime = zeros(nEpochs, 1);
stats.integratedResponse = zeros(nEpochs, 1);
stats.meanAmplitude = zeros(nEpochs, 1);

dt = 1 / sampleRate;

for i = 1:nEpochs
    trace = responseData(i, :);

    % Peak amplitude (signed based on recording type)
    if strcmp(recordingType, 'inh')
        [pk, pkIdx] = max(trace);
    else
        [pk, pkIdx] = min(trace);  % Most negative for exc
    end

    stats.peakAmplitude(i) = pk;
    stats.peakTime(i) = responseTime(pkIdx);

    % Integrated response (charge transfer)
    stats.integratedResponse(i) = trapz(trace) * dt;

    % Mean amplitude
    stats.meanAmplitude(i) = mean(trace);
end

% Compute summary statistics
stats.mean_peak = mean(stats.peakAmplitude);
stats.std_peak = std(stats.peakAmplitude);
stats.sem_peak = stats.std_peak / sqrt(nEpochs);

stats.mean_integrated = mean(stats.integratedResponse);
stats.std_integrated = std(stats.integratedResponse);
stats.sem_integrated = stats.std_integrated / sqrt(nEpochs);

stats.mean_meanAmplitude = mean(stats.meanAmplitude);
stats.std_meanAmplitude = std(stats.meanAmplitude);
stats.sem_meanAmplitude = stats.std_meanAmplitude / sqrt(nEpochs);

end
