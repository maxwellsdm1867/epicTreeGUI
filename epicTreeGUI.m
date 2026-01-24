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
    grid = uigridlayout(fig, [1 2]);
    grid.ColumnWidth = {'1x', '2x'};

    % Left panel - Tree navigation
    leftPanel = uipanel(grid, 'Title', 'Epoch Tree');
    leftPanel.Layout.Row = 1;
    leftPanel.Layout.Column = 1;

    % Right panel - Data display
    rightPanel = uipanel(grid, 'Title', 'Data View');
    rightPanel.Layout.Row = 1;
    rightPanel.Layout.Column = 2;

    % Create tree component
    tree = uitree(leftPanel, ...
                  'Position', [10 50 280 500], ...
                  'SelectionChangedFcn', @(src, event) onTreeSelection(src, event));

    % Create text area for data display
    dataDisplay = uitextarea(rightPanel, ...
                            'Position', [10 10 580 540], ...
                            'Editable', 'off');

    % Add menu bar
    menuFile = uimenu(fig, 'Text', 'File');
    uimenu(menuFile, 'Text', 'Load Data...', 'MenuSelectedFcn', @(src, event) loadData());
    uimenu(menuFile, 'Text', 'Exit', 'MenuSelectedFcn', @(src, event) close(fig));

    menuHelp = uimenu(fig, 'Text', 'Help');
    uimenu(menuHelp, 'Text', 'About', 'MenuSelectedFcn', @(src, event) showAbout());

    % Store handles in figure UserData
    handles.tree = tree;
    handles.dataDisplay = dataDisplay;
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
                % Use the standard format display function
                handles.dataDisplay.Value = formatEpicNodeData(nodeData);
            else
                handles.dataDisplay.Value = sprintf('Selected: %s', selectedNode.Text);
            end
        end
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
                msg = sprintf(['Data loaded successfully!\n\n', ...
                              'Experiments: %d\n', ...
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

