function results = MeanSelectedNodes(nodes, streamName, varargin)
% MEANSELECTEDNODES Compare mean responses across multiple tree nodes
%
% Computes and plots mean response traces for multiple tree nodes,
% useful for comparing different conditions (e.g., different contrasts,
% cell types, or protocols).
%
% Usage:
%   results = MeanSelectedNodes(nodes, 'Amp1')
%   results = MeanSelectedNodes(nodes, 'Amp1', 'PreTime', 500)
%   results = MeanSelectedNodes(nodes, 'Amp1', 'h5_file', h5Path)
%
% Inputs:
%   nodes      - Cell array of epicTreeTools nodes to compare
%   streamName - Response stream name (e.g., 'Amp1')
%
% Optional Parameters:
%   'h5_file'        - Path to H5 file for lazy loading (default: '')
%   'PreTime'        - Pre-stimulus time in ms (default: auto from epoch)
%   'StimTime'       - Stimulus time in ms (default: auto from epoch)
%   'BaselineCorrect'- Subtract baseline mean (default: true)
%   'Normalize'      - Normalize response amplitudes (default: false)
%   'SmoothPts'      - Gaussian smoothing points (default: 10)
%   'PlotOffset'     - Vertical offset between traces (default: 0)
%   'LineWidth'      - Plot line width (default: 1.5)
%   'Colors'         - Color matrix or 'auto' (default: 'auto')
%   'Figure'         - Figure handle or number (default: new figure)
%   'HoldOn'         - Add to existing plot (default: false)
%   'ShowLegend'     - Display legend (default: true)
%   'ShowAnalysis'   - Show response amplitude subplot (default: true)
%
% Outputs:
%   results - Struct with fields:
%       .meanResponse  - [nNodes x nSamples] mean response traces
%       .semResponse   - [nNodes x nSamples] SEM traces
%       .respAmp       - [1 x nNodes] integrated response amplitudes
%       .splitValue    - [1 x nNodes] split values for each node
%       .nEpochs       - [1 x nNodes] number of epochs per node
%       .timeVector    - [1 x nSamples] time in seconds
%       .sampleRate    - Sample rate in Hz
%
% Example:
%   % Compare different contrasts
%   tree = epicTreeTools(data);
%   tree.buildTree({'cellInfo.type', 'parameters.contrast'});
%
%   % Get nodes for different contrasts
%   onpNode = tree.childBySplitValue('OnP');
%   nodes = {};
%   for i = 1:onpNode.childrenLength()
%       nodes{end+1} = onpNode.childAt(i);
%   end
%
%   % Plot comparison
%   results = MeanSelectedNodes(nodes, 'Amp1', 'h5_file', h5_file);
%
% See also: getSelectedData, getMeanResponseTrace, epicTreeTools

%% Parse inputs
p = inputParser;
p.addRequired('nodes', @iscell);
p.addRequired('streamName', @ischar);
p.addParameter('h5_file', '', @ischar);
p.addParameter('PreTime', [], @(x) isempty(x) || isnumeric(x));
p.addParameter('StimTime', [], @(x) isempty(x) || isnumeric(x));
p.addParameter('BaselineCorrect', true, @islogical);
p.addParameter('Normalize', false, @islogical);
p.addParameter('SmoothPts', 10, @isnumeric);
p.addParameter('PlotOffset', 0, @isnumeric);
p.addParameter('LineWidth', 1.5, @isnumeric);
p.addParameter('Colors', 'auto', @(x) ischar(x) || isnumeric(x));
p.addParameter('Figure', [], @(x) isempty(x) || isnumeric(x) || ishandle(x));
p.addParameter('HoldOn', false, @islogical);
p.addParameter('ShowLegend', true, @islogical);
p.addParameter('ShowAnalysis', true, @islogical);
p.parse(nodes, streamName, varargin{:});
opts = p.Results;

%% Validate inputs
nNodes = length(nodes);
if nNodes == 0
    error('MeanSelectedNodes:NoNodes', 'No nodes provided');
end

%% Setup colors
if ischar(opts.Colors) && strcmp(opts.Colors, 'auto')
    colors = lines(nNodes);
else
    colors = opts.Colors;
    if size(colors, 1) < nNodes
        colors = repmat(colors, ceil(nNodes/size(colors,1)), 1);
    end
end

%% Initialize results
results = struct();
results.splitValue = zeros(1, nNodes);
results.respAmp = zeros(1, nNodes);
results.nEpochs = zeros(1, nNodes);
results.meanResponse = [];
results.semResponse = [];

%% Process each node
legendLabels = cell(1, nNodes);

for i = 1:nNodes
    node = nodes{i};

    % Get selected data from node
    [dataMatrix, epochs, sampleRate] = getSelectedData(node, streamName, opts.h5_file);

    if isempty(dataMatrix)
        warning('MeanSelectedNodes:NoData', 'No data for node %d', i);
        continue;
    end

    % Store sample rate and initialize on first valid node
    if isempty(results.meanResponse)
        results.sampleRate = sampleRate;
        nSamples = size(dataMatrix, 2);
        results.meanResponse = zeros(nNodes, nSamples);
        results.semResponse = zeros(nNodes, nSamples);
        results.timeVector = (1:nSamples) / sampleRate;
    end

    % Get timing parameters
    if ~isempty(epochs) && isfield(epochs{1}, 'parameters')
        params = epochs{1}.parameters;
        if isempty(opts.PreTime) && isfield(params, 'preTime')
            preTime = params.preTime;
        else
            preTime = opts.PreTime;
        end
        if isempty(opts.StimTime) && isfield(params, 'stimTime')
            stimTime = params.stimTime;
        else
            stimTime = opts.StimTime;
        end
    else
        preTime = opts.PreTime;
        stimTime = opts.StimTime;
    end

    % Convert to points
    if ~isempty(preTime)
        prePts = round(preTime / 1000 * sampleRate);
    else
        prePts = round(size(dataMatrix, 2) * 0.1);  % Default 10%
    end
    if ~isempty(stimTime)
        stimPts = round(stimTime / 1000 * sampleRate);
    else
        stimPts = round(size(dataMatrix, 2) * 0.5);  % Default 50%
    end

    % Baseline correction
    if opts.BaselineCorrect && prePts > 1
        baselines = mean(dataMatrix(:, 1:prePts), 2);
        dataMatrix = dataMatrix - baselines;
    end

    % Compute mean and SEM
    meanTrace = mean(dataMatrix, 1);
    semTrace = std(dataMatrix, [], 1) / sqrt(size(dataMatrix, 1));

    % Smooth if requested
    if opts.SmoothPts > 1
        kernel = gausswin(opts.SmoothPts);
        kernel = kernel / sum(kernel);
        meanTrace = conv(meanTrace, kernel, 'same');
        semTrace = conv(semTrace, kernel, 'same');
    end

    % Store results
    results.meanResponse(i, :) = meanTrace;
    results.semResponse(i, :) = semTrace;
    results.nEpochs(i) = size(dataMatrix, 1);

    % Compute integrated response amplitude (during stim period)
    if prePts + stimPts <= length(meanTrace)
        stimRegion = meanTrace(prePts+1 : prePts+stimPts);
        results.respAmp(i) = sum(stimRegion) / sampleRate;  % Integrated (pA*s or mV*s)
    else
        results.respAmp(i) = sum(meanTrace(prePts+1:end)) / sampleRate;
    end

    % Get split value for legend
    if isnumeric(node.splitValue)
        results.splitValue(i) = node.splitValue;
        legendLabels{i} = sprintf('%g (n=%d)', node.splitValue, results.nEpochs(i));
    else
        results.splitValue(i) = i;
        legendLabels{i} = sprintf('%s (n=%d)', string(node.splitValue), results.nEpochs(i));
    end
end

%% Normalize if requested
if opts.Normalize && max(abs(results.respAmp)) > 0
    results.respAmp = results.respAmp / max(abs(results.respAmp));
end

%% Plot results
if opts.ShowAnalysis
    numSubplots = 2;
else
    numSubplots = 1;
end

% Create or use figure
if isempty(opts.Figure)
    fig = figure('Name', 'Mean Selected Nodes', 'NumberTitle', 'off');
else
    fig = figure(opts.Figure);
end

if ~opts.HoldOn
    clf(fig);
end

% Plot mean traces
subplot(1, numSubplots, 1);
hold on;

for i = 1:nNodes
    if results.nEpochs(i) > 0
        t = results.timeVector;
        y = results.meanResponse(i, :) + opts.PlotOffset * (i-1);

        % Plot SEM shading
        yUpper = y + results.semResponse(i, :);
        yLower = y - results.semResponse(i, :);
        fill([t fliplr(t)], [yUpper fliplr(yLower)], colors(i,:), ...
            'EdgeColor', 'none', 'FaceAlpha', 0.2);

        % Plot mean trace
        plot(t, y, 'Color', colors(i,:), 'LineWidth', opts.LineWidth);
    end
end

xlabel('Time (s)');
ylabel('Response');
title('Mean Responses');

if opts.ShowLegend
    legend(legendLabels{results.nEpochs > 0}, 'Location', 'best');
end

% Plot response amplitude vs split value
if opts.ShowAnalysis
    subplot(1, numSubplots, 2);
    hold on;

    validIdx = results.nEpochs > 0;
    plot(results.splitValue(validIdx), results.respAmp(validIdx), 'ko-', ...
        'MarkerFaceColor', 'k', 'LineWidth', 1.5, 'MarkerSize', 8);

    xlabel('Split Value');
    ylabel('Integrated Response');
    title('Response vs Condition');
    grid on;
end

end
