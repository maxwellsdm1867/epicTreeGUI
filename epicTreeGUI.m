function epicTreeGUI()
% EPICTREEGUI Interactive GUI for visualizing epoch tree data
%
% Usage:
%   epicTreeGUI()
%
% Description:
%   Launches an interactive GUI for browsing and visualizing hierarchical
%   epoch data structures commonly used in electrophysiology experiments.

    % Create main figure
    fig = uifigure('Name', 'Epoch Tree GUI', ...
                   'Position', [100 100 1000 600]);

    % Create grid layout
    grid = uigridlayout(fig, [2 2]);
    grid.RowHeight = {'fit', '1x'};
    grid.ColumnWidth = {'1x', '2x'};

    % Left panel - Tree navigation
    leftPanel = uipanel(grid, 'Title', 'Epoch Tree');
    leftPanel.Layout.Row = 2;
    leftPanel.Layout.Column = 1;

    % Splitter control panel (top left)
    controlPanel = uipanel(grid, 'Title', 'Tree Organization');
    controlPanel.Layout.Row = 1;
    controlPanel.Layout.Column = 1;

    % Create split selector dropdown
    uilabel(controlPanel, 'Text', 'Split by:', ...
        'Position', [10 40 60 20]);
    splitDropdown = uidropdown(controlPanel, ...
        'Position', [75 40 200 20], ...
        'Items', {'None', 'Cell Type', 'Contrast', 'Size', 'Temporal Frequency'}, ...
        'ItemsData', {'none', 'cellType', 'contrast', 'size', 'temporalFrequency'}, ...
        'ValueChangedFcn', @(src, event) onSplitChanged(src, event));

    % Right panel - Data display
    rightPanel = uipanel(grid, 'Title', 'Data View');
    rightPanel.Layout.Row = [1 2];
    rightPanel.Layout.Column = 2;

    % Create tree component
    tree = uitree(leftPanel, ...
                  'Position', [10 10 280 500], ...
                  'SelectionChangedFcn', @(src, event) onTreeSelection(src, event));

    % Create axes for plots instead of text area
    dataAxes = axes('Parent', rightPanel, ...
                   'Position', [0.05 0.05 0.9 0.9]);

    % Add menu bar
    menuFile = uimenu(fig, 'Text', 'File');
    uimenu(menuFile, 'Text', 'Load Data...', 'MenuSelectedFcn', @(src, event) loadData());
    uimenu(menuFile, 'Text', 'Exit', 'MenuSelectedFcn', @(src, event) close(fig));

    menuHelp = uimenu(fig, 'Text', 'Help');
    uimenu(menuHelp, 'Text', 'About', 'MenuSelectedFcn', @(src, event) showAbout());

    % Store handles in figure UserData
    handles.tree = tree;
    handles.dataAxes = dataAxes;
    handles.splitDropdown = splitDropdown;
    handles.treeData = [];
    handles.metadata = [];
    fig.UserData = handles;

    % Add sample data
    addSampleTree(tree);

    % Nested callback functions
    function onTreeSelection(~, event)
        % Handle tree node selection
        selectedNode = event.SelectedNodes;
        if ~isempty(selectedNode)
            handles = fig.UserData;
            nodeData = selectedNode.NodeData;
            if ~isempty(nodeData)
                % Use the visual display function
                displayNodeData(handles.dataAxes, nodeData, handles.treeData);
            else
                cla(handles.dataAxes);
                text(handles.dataAxes, 0.5, 0.5, sprintf('Selected: %s', selectedNode.Text), ...
                    'HorizontalAlignment', 'center');
            end
        end
    end

    function onSplitChanged(~, event)
        % Handle split method change
        handles = fig.UserData;
        
        if isempty(handles.treeData)
            return;
        end
        
        splitMethod = event.Value;
        
        % Rebuild tree with new split
        rebuildTreeWithSplit(handles.tree, handles.treeData, splitMethod);
    end

    function loadData()
        % Load epoch tree data from file
        [file, path] = uigetfile({'*.mat', 'MATLAB Data Files (*.mat)'}, ...
                                 'Select Epoch Tree Data');
        if file ~= 0
            try
                % Load data using standard format loader
                [treeData, metadata] = loadEpicTreeData(fullfile(path, file));

                % Store in figure UserData
                handles = fig.UserData;
                handles.treeData = treeData;
                handles.metadata = metadata;
                fig.UserData = handles;

                % Build tree
                buildTreeFromEpicData(handles.tree, treeData);

                % Show success message with summary
                msg = sprint with current split method
                splitMethod = handles.splitDropdown.Value;
                rebuildTreeWithSplit(handles.tree, treeData, splitMethod
                              'Source: %s\n', ...
                              'Created: %s'], ...
                              length(treeData.experiments), ...
                              metadata.data_source, ...
                              metadata.created_date);
                uialert(fig, msg, 'Success');
            catch ME
                uialert(fig, ME.message, 'Error Loading Data');
            end
        end
    end

    function showAbout()
        % Display about dialog
        msg = sprintf(['Epoch Tree GUI v1.0\n\n', ...
                      'A tool for visualizing hierarchical epoch data.\n\n', ...
                      'Created for neuroscience research.']);
        uialert(fig, msg, 'About Epoch Tree GUI');
    end

end

function addSampleTree(tree)
    % Add sample hierarchical data to tree
    root = uitreenode(tree, 'Text', 'Experiment', 'NodeData', struct('type', 'root'));

    session1 = uitreenode(root, 'Text', 'Session 1', ...
                         'NodeData', struct('type', 'session', 'id', 1));
    epoch1 = uitreenode(session1, 'Text', 'Epoch 1', ...
                       'NodeData', struct('type', 'epoch', 'id', 1, 'duration', 100));
    epoch2 = uitreenode(session1, 'Text', 'Epoch 2', ...
                       'NodeData', struct('type', 'epoch', 'id', 2, 'duration', 150));

    session2 = uitreenode(root, 'Text', 'Session 2', ...
                         'NodeData', struct('type', 'session', 'id', 2));
    epoch3 = uitreenode(session2, 'Text', 'Epoch 3', ...
                       'NodeData', struct('type', 'epoch', 'id', 3, 'duration', 120));

    expand(tree);
end

