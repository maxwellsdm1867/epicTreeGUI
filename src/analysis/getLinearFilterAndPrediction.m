function result = getLinearFilterAndPrediction(epochListOrNode, stimStreamName, respStreamName, varargin)
% GETLINEARFILTERANDPREDICTION Compute linear filter (STA) and prediction
%
% Computes the spike-triggered average (STA) or stimulus-response
% correlation to estimate the linear filter, and uses it to generate
% a linear prediction of the response.
%
% Usage:
%   result = getLinearFilterAndPrediction(epochs, 'Stage', 'Amp1')
%   result = getLinearFilterAndPrediction(treeNode, 'LED', 'Amp1', 'FilterLength', 500)
%
% Inputs:
%   epochListOrNode - Cell array of epochs OR epicTreeTools node
%   stimStreamName  - Stimulus stream name (e.g., 'Stage', 'LED')
%   respStreamName  - Response stream name (e.g., 'Amp1')
%
% Optional Parameters:
%   'FilterLength'    - Length of filter in ms. Default: 500
%   'OnlySelected'    - Only use selected epochs. Default: true
%   'Method'          - 'correlation' or 'sta'. Default: 'correlation'
%
% Output:
%   result - Struct with fields:
%       .filter         - Linear filter [1 x filterPoints]
%       .filterTime     - Time vector for filter (ms)
%       .prediction     - Linear prediction (concatenated)
%       .response       - Actual response (concatenated)
%       .stimulus       - Stimulus (concatenated)
%       .correlation    - Correlation coefficient
%       .sampleRate     - Sample rate in Hz
%       .n              - Number of epochs
%
% Example:
%   result = getLinearFilterAndPrediction(treeNode, 'Stage', 'Amp1');
%   subplot(2,1,1);
%   plot(result.filterTime, result.filter);
%   xlabel('Time (ms)'); title('Linear Filter');
%   subplot(2,1,2);
%   plot(result.response(1:1000)); hold on;
%   plot(result.prediction(1:1000));
%   legend('Actual', 'Predicted');
%
% See also: getMeanResponseTrace, getCycleAverageResponse

% Parse inputs
ip = inputParser;
ip.addRequired('epochListOrNode');
ip.addRequired('stimStreamName', @ischar);
ip.addRequired('respStreamName', @ischar);
ip.addParameter('FilterLength', 500, @isnumeric);  % ms
ip.addParameter('OnlySelected', true, @islogical);
ip.addParameter('Method', 'correlation', @ischar);
ip.parse(epochListOrNode, stimStreamName, respStreamName, varargin{:});

filterLengthMs = ip.Results.FilterLength;
onlySelected = ip.Results.OnlySelected;
method = lower(ip.Results.Method);

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
    result.filter = [];
    result.filterTime = [];
    result.prediction = [];
    result.response = [];
    result.stimulus = [];
    result.correlation = NaN;
    result.sampleRate = [];
    return;
end

% Get response data
[respMatrix, sampleRate] = getResponseMatrix(epochs, respStreamName);

if isempty(respMatrix)
    result.filter = [];
    result.filterTime = [];
    result.prediction = [];
    result.response = [];
    result.stimulus = [];
    result.correlation = NaN;
    result.sampleRate = [];
    return;
end

result.sampleRate = sampleRate;

% Get stimulus data
stimMatrix = zeros(size(respMatrix));
for i = 1:result.n
    stim = epicTreeTools.getStimulusByName(epochs{i}, stimStreamName);
    if ~isempty(stim) && isfield(stim, 'data')
        data = stim.data(:)';
        if length(data) >= size(stimMatrix, 2)
            stimMatrix(i, :) = data(1:size(stimMatrix, 2));
        else
            stimMatrix(i, 1:length(data)) = data;
        end
    end
end

% Filter length in samples
filterLength = round(filterLengthMs / 1000 * sampleRate);
result.filterTime = (0:filterLength-1) / sampleRate * 1000;  % ms

% Concatenate all epochs
allStim = [];
allResp = [];
for i = 1:result.n
    allStim = [allStim, stimMatrix(i, :)];
    allResp = [allResp, respMatrix(i, :)];
end

% Remove mean
allStim = allStim - mean(allStim);
allResp = allResp - mean(allResp);

result.stimulus = allStim;
result.response = allResp;

% Compute linear filter
switch method
    case 'correlation'
        % Cross-correlation method
        result.filter = computeFilterByCorrelation(allStim, allResp, filterLength);

    case 'sta'
        % Spike-triggered average (requires spike times)
        % For continuous responses, fall back to correlation
        result.filter = computeFilterByCorrelation(allStim, allResp, filterLength);

    otherwise
        result.filter = computeFilterByCorrelation(allStim, allResp, filterLength);
end

% Normalize filter
if max(abs(result.filter)) > 0
    result.filter = result.filter / max(abs(result.filter));
end

% Compute linear prediction
result.prediction = conv(allStim, result.filter, 'same');

% Scale prediction to match response
scaleFactor = std(allResp) / std(result.prediction);
result.prediction = result.prediction * scaleFactor;

% Compute correlation
validIdx = ~isnan(result.response) & ~isnan(result.prediction);
if sum(validIdx) > 0
    R = corrcoef(result.response(validIdx), result.prediction(validIdx));
    result.correlation = R(1, 2);
else
    result.correlation = NaN;
end

end


function filter = computeFilterByCorrelation(stimulus, response, filterLength)
% COMPUTEFILTERBYCORRELATION Compute filter using cross-correlation
%
% Uses Wiener-Hopf equation: filter = R_ss^(-1) * R_sr
% where R_ss is stimulus autocorrelation and R_sr is stimulus-response
% cross-correlation.

n = length(stimulus);

% Compute cross-correlation (stimulus leading response)
xcorr_sr = zeros(1, filterLength);
for lag = 0:filterLength-1
    if lag + 1 <= n
        xcorr_sr(lag + 1) = sum(stimulus(1:n-lag) .* response(lag+1:n)) / (n - lag);
    end
end

% Compute stimulus autocorrelation
xcorr_ss = zeros(filterLength, filterLength);
for i = 0:filterLength-1
    for j = 0:filterLength-1
        lag = abs(i - j);
        if lag + 1 <= n
            xcorr_ss(i+1, j+1) = sum(stimulus(1:n-lag) .* stimulus(lag+1:n)) / (n - lag);
        end
    end
end

% Solve for filter (regularized)
lambda = 0.01 * trace(xcorr_ss) / filterLength;  % Regularization
filter = (xcorr_ss + lambda * eye(filterLength)) \ xcorr_sr';
filter = filter';

end
