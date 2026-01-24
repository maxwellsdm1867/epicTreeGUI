function epochs = getAllEpochs(treeData)
% GETALLEPOCHS Extract all epochs from hierarchical tree data structure
%
% Usage:
%   epochs = getAllEpochs(treeData)
%
% Inputs:
%   treeData - Hierarchical structure from loadEpicTreeData
%              Must have .experiments array
%
% Outputs:
%   epochs - Cell array of all epochs with metadata attached
%            Each epoch struct includes:
%              .id, .parameters, .responses, .stimuli (original fields)
%              .cellInfo - Parent cell reference
%              .groupInfo - Parent epoch group reference
%              .blockInfo - Parent epoch block reference
%              .expInfo - Parent experiment reference
%
% Description:
%   Flattens the hierarchical tree structure into a single cell array
%   of epochs. Each epoch is enriched with references to its parent
%   cell, group, block, and experiment for context during analysis.
%
% Example:
%   data = loadEpicTreeData('experiment.mat');
%   epochs = getAllEpochs(data);
%   fprintf('Total epochs: %d\n', length(epochs));
%
% See also: buildTreeByKeyPaths, getNestedValue

    epochs = {};

    if ~isfield(treeData, 'experiments')
        warning('getAllEpochs: No experiments field in treeData');
        return;
    end

    % Traverse hierarchy: experiments -> cells -> epoch_groups -> epoch_blocks -> epochs
    for expIdx = 1:length(treeData.experiments)
        exp = treeData.experiments(expIdx);

        % Create lightweight experiment info (avoid circular refs)
        expInfo = struct('id', exp.id, 'exp_name', exp.exp_name);
        if isfield(exp, 'is_mea')
            expInfo.is_mea = exp.is_mea;
        end

        if ~isfield(exp, 'cells')
            continue;
        end

        for cellIdx = 1:length(exp.cells)
            cell = exp.cells(cellIdx);

            % Create lightweight cell info
            cellInfo = struct('id', cell.id);
            if isfield(cell, 'type')
                cellInfo.type = cell.type;
            else
                cellInfo.type = '';
            end
            if isfield(cell, 'label')
                cellInfo.label = cell.label;
            else
                cellInfo.label = '';
            end

            if ~isfield(cell, 'epoch_groups')
                continue;
            end

            for groupIdx = 1:length(cell.epoch_groups)
                eg = cell.epoch_groups(groupIdx);

                % Create lightweight group info
                groupInfo = struct('id', eg.id);
                if isfield(eg, 'protocol_name')
                    groupInfo.protocol_name = eg.protocol_name;
                else
                    groupInfo.protocol_name = '';
                end
                if isfield(eg, 'label')
                    groupInfo.label = eg.label;
                else
                    groupInfo.label = '';
                end

                if ~isfield(eg, 'epoch_blocks')
                    continue;
                end

                for blockIdx = 1:length(eg.epoch_blocks)
                    eb = eg.epoch_blocks(blockIdx);

                    % Create lightweight block info
                    blockInfo = struct('id', eb.id);
                    if isfield(eb, 'protocol_name')
                        blockInfo.protocol_name = eb.protocol_name;
                    else
                        blockInfo.protocol_name = '';
                    end

                    if ~isfield(eb, 'epochs')
                        continue;
                    end

                    for epochIdx = 1:length(eb.epochs)
                        epoch = eb.epochs(epochIdx);

                        % Attach parent references
                        epoch.cellInfo = cellInfo;
                        epoch.groupInfo = groupInfo;
                        epoch.blockInfo = blockInfo;
                        epoch.expInfo = expInfo;

                        epochs{end+1} = epoch;
                    end
                end
            end
        end
    end

    % Convert to column cell array for consistency
    epochs = epochs(:);
end
