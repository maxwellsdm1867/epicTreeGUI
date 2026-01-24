function epochData = getSelectedData(treeData, epochIndices, streamName)
% GETSELECTEDDATA Extract response data from epochs
% 
% Adapter function to replicate legacy getSelectedData() functionality
% from old epochtree system. This is THE CRITICAL FUNCTION used by all
% analysis functions (RFAnalysis, LSTA, SpatioTemporalModel, etc.)
%
% Usage:
%   epochData = getSelectedData(treeData, epochIndices, streamName)
%
% Inputs:
%   treeData - EpicTreeGUI data structure with experiments/cells/epochs
%   epochIndices - Array of epoch indices to extract [1 x N]
%   streamName - Response stream to extract:
%                'Amp1', 'Amp2' - Amplifier recordings (voltage/current)
%                'Cell' - Spike times (for spike data)
%                'Frame Monitor' - Frame timing signals
%
% Output:
%   epochData - Response matrix [nEpochs x nSamples]
%               For spike data: [nEpochs x 1] cell array of spike times
%
% Legacy System:
%   tempData = riekesuite.getResponseMatrix(epochList, streamName);
%   epochData = tempData(selectedEpochs, :);
%
% New System:
%   - Flattens hierarchy to find epochs
%   - Extracts response data based on streamName
%   - Returns matrix format compatible with old analysis functions
%
% Example:
%   % Get voltage traces for epochs 1-10
%   data = getSelectedData(treeData, 1:10, 'Amp1');
%
%   % Get spike times for selected epochs
%   spikes = getSelectedData(treeData, selectedIdx, 'Cell');

% Validate inputs
if nargin < 3
    error('getSelectedData requires 3 arguments: treeData, epochIndices, streamName');
end

if isempty(epochIndices)
    error('epochIndices cannot be empty');
end

% Flatten tree to get all epochs
allEpochs = flattenTreeToEpochs(treeData);

% Check if indices are valid
if max(epochIndices) > length(allEpochs)
    error('Epoch index %d exceeds number of epochs (%d)', max(epochIndices), length(allEpochs));
end

% Extract selected epochs
selectedEpochs = allEpochs(epochIndices);

% Initialize output based on stream type
nEpochs = length(selectedEpochs);

% Determine if this is spike data or continuous data
if strcmpi(streamName, 'Cell')
    % Spike data - return cell array of spike times
    epochData = cell(nEpochs, 1);
    
    for i = 1:nEpochs
        epoch = selectedEpochs{i};
        
        % Check if spike times already extracted
        if isfield(epoch, 'spikeTimes')
            epochData{i} = epoch.spikeTimes;
        elseif isfield(epoch, 'response')
            % Need to detect spikes from raw trace
            % For now, return empty - spike detection should be done separately
            warning('Spike detection not yet implemented. Use detectSpikes() first.');
            epochData{i} = [];
        else
            epochData{i} = [];
        end
    end
    
else
    % Continuous data (voltage, current, frame monitor, etc.)
    % Determine matrix size from first epoch
    firstEpoch = selectedEpochs{1};
    
    if isfield(firstEpoch, 'response')
        nSamples = length(firstEpoch.response);
        epochData = zeros(nEpochs, nSamples);
        
        % Extract response data for each epoch
        for i = 1:nEpochs
            epoch = selectedEpochs{i};
            
            % Handle different amplifier channels
            if strcmpi(streamName, 'Amp1') || strcmpi(streamName, 'Amp2')
                % Check if responseAmplifier matches
                if isfield(epoch, 'responseAmplifier')
                    if strcmpi(epoch.responseAmplifier, streamName)
                        epochData(i, :) = epoch.response;
                    else
                        % Different amplifier - set to zeros
                        epochData(i, :) = zeros(1, nSamples);
                    end
                else
                    % No amplifier specified - assume correct
                    epochData(i, :) = epoch.response;
                end
            elseif strcmpi(streamName, 'Frame Monitor')
                % Frame timing signal
                if isfield(epoch, 'frameMonitor')
                    epochData(i, :) = epoch.frameMonitor;
                else
                    % Not available
                    epochData(i, :) = zeros(1, nSamples);
                end
            else
                % Generic stream name - try to access from response
                epochData(i, :) = epoch.response;
            end
        end
    else
        error('Epoch structure does not contain response data');
    end
end

end


function allEpochs = flattenTreeToEpochs(treeData)
% FLATTENTREETOEPOCHS Recursively extract all epochs from tree structure
%
% Traverses: experiments → cells → cellData → groups → blocks → epochs

allEpochs = {};

if ~isfield(treeData, 'experiments')
    error('treeData does not contain experiments field');
end

for exp_idx = 1:length(treeData.experiments)
    experiment = treeData.experiments{exp_idx};
    
    if isfield(experiment, 'cells')
        for cell_idx = 1:length(experiment.cells)
            cell = experiment.cells{cell_idx};
            
            if isfield(cell, 'cellData')
                for data_idx = 1:length(cell.cellData)
                    cellData = cell.cellData{data_idx};
                    
                    if isfield(cellData, 'groups')
                        for group_idx = 1:length(cellData.groups)
                            group = cellData.groups{group_idx};
                            
                            if isfield(group, 'blocks')
                                for block_idx = 1:length(group.blocks)
                                    block = group.blocks{block_idx};
                                    
                                    if isfield(block, 'epochs')
                                        for epoch_idx = 1:length(block.epochs)
                                            % Add epoch to flat list
                                            allEpochs{end+1} = block.epochs{epoch_idx};
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

end
