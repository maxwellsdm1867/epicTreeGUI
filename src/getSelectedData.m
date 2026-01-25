function [dataMatrix, selectedEpochs, sampleRate] = getSelectedData(treeNodeOrEpochs, streamName)
% GETSELECTEDDATA Get response data for ONLY selected epochs
%
% THIS IS THE CRITICAL FUNCTION FOR ALL ANALYSIS WORKFLOWS.
% Used by RFAnalysis, LSTA, SpatioTemporalModel, CenterSurround, etc.
%
% Usage:
%   [data, epochs] = getSelectedData(treeNode, 'Amp1')
%   [data, epochs, fs] = getSelectedData(epochList, 'Amp1')
%
% Inputs:
%   treeNodeOrEpochs - Either:
%                      - epicTreeTools node (extracts epochs from tree)
%                      - Cell array of epoch structs (uses directly)
%   streamName       - Response stream name (e.g., 'Amp1', 'Amp2')
%
% Outputs:
%   dataMatrix      - [nSelected x nSamples] response data matrix
%   selectedEpochs  - Cell array of selected epoch structs
%   sampleRate      - Sample rate in Hz (from first epoch)
%
% Description:
%   1. Collects all epochs from input (tree node or list)
%   2. Filters to only epochs with isSelected == true
%   3. Extracts response data matrix for the specified stream
%
% Legacy Equivalent:
%   tempData = riekesuite.getResponseMatrix(epochList, streamName);
%   isSelected = arrayfun(@(e) e.isSelected, epochList);
%   epochData = tempData(isSelected, :);
%
% Example:
%   % Get data from tree node
%   gui = epicTreeGUI('data.mat');
%   selectedNode = gui.tree.childBySplitValue('OnP');
%   [data, epochs, fs] = getSelectedData(selectedNode, 'Amp1');
%
%   % Compute mean trace
%   meanTrace = mean(data, 1);
%   t = (1:size(data,2)) / fs * 1000;  % ms
%   plot(t, meanTrace);
%
% See also: getResponseMatrix, getTreeEpochs, epicTreeTools.getAllEpochs

% Handle input type
if isa(treeNodeOrEpochs, 'epicTreeTools')
    % Get all epochs from tree node
    allEpochs = treeNodeOrEpochs.getAllEpochs(false);
elseif iscell(treeNodeOrEpochs)
    % Already a cell array of epochs
    allEpochs = treeNodeOrEpochs;
else
    error('getSelectedData:InvalidInput', ...
        'Input must be epicTreeTools node or cell array of epochs');
end

% Filter by isSelected flag
selectedEpochs = {};
for i = 1:length(allEpochs)
    ep = allEpochs{i};

    % Check isSelected flag (default to true if not present)
    if isfield(ep, 'isSelected')
        if ep.isSelected
            selectedEpochs{end+1} = ep;
        end
    else
        % Include if isSelected field doesn't exist (backwards compatibility)
        selectedEpochs{end+1} = ep;
    end
end
selectedEpochs = selectedEpochs(:);

% Handle empty selection
if isempty(selectedEpochs)
    dataMatrix = [];
    sampleRate = [];
    return;
end

% Extract response data matrix
[dataMatrix, sampleRate] = getResponseMatrix(selectedEpochs, streamName);

end
