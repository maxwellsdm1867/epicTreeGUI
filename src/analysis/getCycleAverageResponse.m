function result = getCycleAverageResponse(epochListOrNode, streamName, varargin)
% GETCYCLEAVERAGERESPONSE Compute cycle-averaged response for periodic stimuli
%
% For periodic stimuli (e.g., drifting gratings, flickering spots),
% computes the average response over one stimulus cycle.
%
% Usage:
%   result = getCycleAverageResponse(epochs, 'Amp1', 'Frequency', 2)
%   result = getCycleAverageResponse(treeNode, 'Amp1')
%
% Inputs:
%   epochListOrNode - Cell array of epochs OR epicTreeTools node
%   streamName      - Response stream name (e.g., 'Amp1')
%
% Optional Parameters:
%   'Frequency'       - Stimulus frequency in Hz. If not provided, attempts
%                       to read from epoch.parameters.temporal_frequency
%   'NumCycles'       - Number of cycles to average. Default: all
%   'SkipCycles'      - Number of initial cycles to skip. Default: 1
%   'OnlySelected'    - Only use selected epochs. Default: true
%   'BaselineSubtract'- Subtract baseline. Default: true
%
% Output:
%   result - Struct with fields:
%       .cycleAverage    - Mean cycle-averaged trace [1 x nPointsPerCycle]
%       .cycleStd        - Std across cycles
%       .cycleSEM        - SEM across cycles
%       .cycleTime       - Time vector for one cycle (seconds)
%       .F1amplitude     - First harmonic (fundamental) amplitude
%       .F1phase         - First harmonic phase (degrees)
%       .F2amplitude     - Second harmonic amplitude
%       .F2phase         - Second harmonic phase (degrees)
%       .F1F2ratio       - F1/F2 ratio
%       .DC              - Mean (DC component)
%       .frequency       - Stimulus frequency used
%       .nCycles         - Number of cycles averaged
%       .n               - Number of epochs
%
% Example:
%   result = getCycleAverageResponse(treeNode, 'Amp1', 'Frequency', 2);
%   plot(result.cycleTime * 1000, result.cycleAverage);
%   xlabel('Time in cycle (ms)');
%   title(sprintf('F1 = %.2f, F2 = %.2f', result.F1amplitude, result.F2amplitude));
%
% See also: getMeanResponseTrace, getF1F2statistics

% Parse inputs
ip = inputParser;
ip.addRequired('epochListOrNode');
ip.addRequired('streamName', @ischar);
ip.addParameter('Frequency', [], @isnumeric);
ip.addParameter('NumCycles', [], @isnumeric);
ip.addParameter('SkipCycles', 1, @isnumeric);
ip.addParameter('OnlySelected', true, @islogical);
ip.addParameter('BaselineSubtract', true, @islogical);
ip.parse(epochListOrNode, streamName, varargin{:});

stimFreq = ip.Results.Frequency;
numCycles = ip.Results.NumCycles;
skipCycles = ip.Results.SkipCycles;
onlySelected = ip.Results.OnlySelected;
baselineSubtract = ip.Results.BaselineSubtract;

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
result = struct();
result.n = length(epochs);

if result.n == 0
    result.cycleAverage = [];
    result.cycleStd = [];
    result.cycleSEM = [];
    result.cycleTime = [];
    result.F1amplitude = NaN;
    result.F1phase = NaN;
    result.F2amplitude = NaN;
    result.F2phase = NaN;
    result.F1F2ratio = NaN;
    result.DC = NaN;
    result.frequency = NaN;
    result.nCycles = 0;
    return;
end

% Get stimulus frequency from first epoch if not provided
if isempty(stimFreq)
    epoch1 = epochs{1};
    if isfield(epoch1, 'parameters')
        params = epoch1.parameters;
        if isfield(params, 'temporal_frequency')
            stimFreq = params.temporal_frequency;
        elseif isfield(params, 'temporalFrequency')
            stimFreq = params.temporalFrequency;
        end
    end
end

if isempty(stimFreq) || stimFreq <= 0
    error('Stimulus frequency must be provided or available in epoch.parameters.temporal_frequency');
end

result.frequency = stimFreq;

% Get response data
[dataMatrix, sampleRate] = getResponseMatrix(epochs, streamName);

if isempty(dataMatrix)
    result.cycleAverage = [];
    result.cycleStd = [];
    result.cycleSEM = [];
    result.cycleTime = [];
    result.F1amplitude = NaN;
    result.F1phase = NaN;
    result.F2amplitude = NaN;
    result.F2phase = NaN;
    result.F1F2ratio = NaN;
    result.DC = NaN;
    result.nCycles = 0;
    return;
end

% Get timing parameters
preTime = 0;
stimTime = 1;
if ~isempty(epochs)
    epoch1 = epochs{1};
    if isfield(epoch1, 'parameters')
        params = epoch1.parameters;
        if isfield(params, 'preTime')
            preTime = params.preTime / 1000;
        end
        if isfield(params, 'stimTime')
            stimTime = params.stimTime / 1000;
        end
    end
end

% Baseline subtract if requested
if baselineSubtract
    baselinePoints = max(1, round(preTime * sampleRate));
    baselines = mean(dataMatrix(:, 1:baselinePoints), 2, 'omitnan');
    dataMatrix = dataMatrix - baselines;
end

% Extract stimulus period
nSamples = size(dataMatrix, 2);
timeVector = (0:nSamples-1) / sampleRate;
stimIdx = timeVector >= preTime & timeVector < (preTime + stimTime);
stimData = dataMatrix(:, stimIdx);
stimTime_actual = timeVector(stimIdx) - preTime;

% Calculate cycle parameters
cyclePeriod = 1 / stimFreq;
pointsPerCycle = round(cyclePeriod * sampleRate);
totalCycles = floor(length(stimTime_actual) / pointsPerCycle);

if isempty(numCycles) || numCycles > (totalCycles - skipCycles)
    numCycles = totalCycles - skipCycles;
end

if numCycles < 1
    warning('Not enough cycles for averaging');
    result.cycleAverage = [];
    result.cycleStd = [];
    result.cycleSEM = [];
    result.cycleTime = [];
    result.F1amplitude = NaN;
    result.F1phase = NaN;
    result.F2amplitude = NaN;
    result.F2phase = NaN;
    result.F1F2ratio = NaN;
    result.DC = NaN;
    result.nCycles = 0;
    return;
end

result.nCycles = numCycles;
result.cycleTime = (0:pointsPerCycle-1) / sampleRate;

% Collect all cycles from all epochs
allCycles = [];

for i = 1:result.n
    trace = stimData(i, :);

    for c = (skipCycles + 1):(skipCycles + numCycles)
        startIdx = (c - 1) * pointsPerCycle + 1;
        endIdx = c * pointsPerCycle;

        if endIdx <= length(trace)
            cycle = trace(startIdx:endIdx);
            allCycles = [allCycles; cycle];
        end
    end
end

if isempty(allCycles)
    result.cycleAverage = [];
    result.cycleStd = [];
    result.cycleSEM = [];
    result.F1amplitude = NaN;
    result.F1phase = NaN;
    result.F2amplitude = NaN;
    result.F2phase = NaN;
    result.F1F2ratio = NaN;
    result.DC = NaN;
    return;
end

% Compute cycle average statistics
result.cycleAverage = mean(allCycles, 1, 'omitnan');
result.cycleStd = std(allCycles, 0, 1, 'omitnan');
nValidCycles = sum(~all(isnan(allCycles), 2));
result.cycleSEM = result.cycleStd / sqrt(max(nValidCycles, 1));

% Compute Fourier components
result.DC = mean(result.cycleAverage);

% F1 (fundamental)
n = length(result.cycleAverage);
t = (0:n-1) / sampleRate;
sinComponent = sum(result.cycleAverage .* sin(2*pi*stimFreq*t)) * 2 / n;
cosComponent = sum(result.cycleAverage .* cos(2*pi*stimFreq*t)) * 2 / n;
result.F1amplitude = sqrt(sinComponent^2 + cosComponent^2);
result.F1phase = atan2d(sinComponent, cosComponent);

% F2 (second harmonic)
sinComponent2 = sum(result.cycleAverage .* sin(2*pi*2*stimFreq*t)) * 2 / n;
cosComponent2 = sum(result.cycleAverage .* cos(2*pi*2*stimFreq*t)) * 2 / n;
result.F2amplitude = sqrt(sinComponent2^2 + cosComponent2^2);
result.F2phase = atan2d(sinComponent2, cosComponent2);

% F1/F2 ratio
if result.F2amplitude > 0
    result.F1F2ratio = result.F1amplitude / result.F2amplitude;
else
    result.F1F2ratio = Inf;
end

end
