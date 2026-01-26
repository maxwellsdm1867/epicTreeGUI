classdef epicTreeGUI < handle
    % EPICTREEGUI Interactive GUI for visualizing and analyzing epoch data
    %
    % Main GUI controller that integrates:
    %   - epicTreeTools (data organization)
    %   - epicGraphicalTree (tree visualization)
    %   - singleEpoch (epoch viewer)
    %
    % Usage:
    %   gui = epicTreeGUI('data.mat')
    %   gui = epicTreeGUI('data.mat', 'noEpochs')  % Hide individual epochs
    %
    % Layout:
    %   [40% Tree Browser] | [60% Viewer/Plotting]
    %
    % See also: epicTreeTools, epicGraphicalTree, getSelectedData

    properties
        % Data
        tree                    % epicTreeTools root node
        allEpochs               % Flat epoch list (cell array)
        treeData                % Original hierarchical data struct
        h5File                  % H5 file path for lazy loading

        % UI Components
        figure                  % Main figure handle
        treeBrowser             % struct: panel, graphTree, splitDropdown
        plottingCanvas          % struct: panel, axes, infoTable

        % State
        showEpochs = true       % Show individual epochs in tree
        isBusy = false          % Busy flag
    end

    properties (Hidden = true)
        title = 'Epic Tree GUI'
        fontSize = 12
        xDivLeft = 0.4          % Tree panel width (40%)
        currentSplitKeys = {'cellInfo.type'}  % Current split configuration
    end

    methods
        function self = epicTreeGUI(dataPathOrTree, varargin)
            % Constructor
            %
            % Usage:
            %   gui = epicTreeGUI('data.mat')                    % Load from file
            %   gui = epicTreeGUI('data.mat', 'noEpochs')       % Hide epochs
            %   gui = epicTreeGUI(prebuiltTree)                 % Use pre-built tree
            %
            % The pre-built tree pattern matches legacy epochTreeGUI:
            %   tree = epicTreeTools(data);
            %   tree.buildTreeWithSplitters({@splitOnCellType, @splitOnDate});
            %   gui = epicTreeGUI(tree);

            % Parse options
            if any(strcmpi(varargin, 'noEpochs'))
                self.showEpochs = false;
            end

            % Create figure
            self.figure = figure(...
                'Name', self.title, ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Position', [100 100 1200 700], ...
                'CloseRequestFcn', @(src,evt) self.onClose(), ...
                'Visible', 'off');

            % Build UI components
            self.buildUIComponents();

            % Load data if provided
            if nargin >= 1 && ~isempty(dataPathOrTree)
                if isa(dataPathOrTree, 'epicTreeTools')
                    % Pre-built tree passed in
                    self.tree = dataPathOrTree;
                    self.allEpochs = self.tree.allEpochs;
                    self.treeData = [];  % Don't store original data

                    % Get H5 file from config
                    try
                        config = epicTreeConfig();
                        if isfield(config, 'h5_dir') && ~isempty(config.h5_dir)
                            % Get experiment name from first epoch
                            if ~isempty(self.allEpochs)
                                ep = self.allEpochs{1};
                                if isfield(ep, 'expInfo') && isfield(ep.expInfo, 'exp_name')
                                    expName = ep.expInfo.exp_name;
                                    self.h5File = fullfile(config.h5_dir, [expName '.h5']);

                                    % Verify H5 file exists
                                    if ~exist(self.h5File, 'file')
                                        warning('epicTreeGUI:H5NotFound', ...
                                            'H5 file not found: %s\nData will not load!', self.h5File);
                                        self.h5File = '';
                                    else
                                        fprintf('✓ H5 file found: %s\n', self.h5File);
                                    end
                                end
                            end
                        else
                            warning('epicTreeGUI:NoH5Config', ...
                                'H5 directory not configured! Run: epicTreeConfig(''h5_dir'', ''/path/to/h5'')');
                        end
                    catch ME
                        warning('epicTreeGUI:ConfigError', ...
                            'Error getting H5 config: %s', ME.message);
                    end

                    % Hide split dropdown since tree is pre-built
                    if isfield(self.treeBrowser, 'controlPanel')
                        set(self.treeBrowser.controlPanel, 'Visible', 'off');
                    end

                    % Update tree browser
                    self.initTreeBrowser();

                    % Update title
                    nEpochs = length(self.allEpochs);
                    set(self.figure, 'Name', sprintf('%s - %d epochs', self.title, nEpochs));
                elseif ischar(dataPathOrTree) || isstring(dataPathOrTree)
                    % File path - load using default splitter
                    self.loadData(dataPathOrTree);
                else
                    error('Input must be either a file path (char/string) or epicTreeTools object');
                end
            end

            % Show figure
            set(self.figure, 'Visible', 'on');
        end

        function delete(self)
            % Destructor
            if ~isempty(self.figure) && ishandle(self.figure)
                delete(self.figure);
            end
        end

        function loadData(self, dataPath)
            % LOADDATA Load data from .mat file
            %
            % Usage:
            %   gui.loadData('data.mat')

            self.isBusy = true;

            try
                % Load using standard format loader
                [data, metadata] = loadEpicTreeData(dataPath);
                self.treeData = data;

                % Get H5 file path for lazy loading
                self.h5File = self.getH5FilePath(metadata, dataPath);

                % Create epicTreeTools and build tree
                self.tree = epicTreeTools(data);
                self.tree.buildTree(self.currentSplitKeys);
                self.allEpochs = self.tree.allEpochs;

                % Update tree browser
                self.initTreeBrowser();

                % Update title
                nEpochs = length(self.allEpochs);
                set(self.figure, 'Name', sprintf('%s - %d epochs', self.title, nEpochs));

            catch ME
                errordlg(sprintf('Error loading data:\n%s', ME.message), 'Load Error');
            end

            self.isBusy = false;
        end

        function rebuildTree(self, splitKeys)
            % REBUILDTREE Rebuild tree with new split keys
            %
            % Usage:
            %   gui.rebuildTree({'cellInfo.type', 'parameters.contrast'})

            if isempty(self.treeData)
                return;
            end

            self.isBusy = true;
            self.currentSplitKeys = splitKeys;

            % Rebuild tree
            self.tree = epicTreeTools(self.treeData);

            % Check if any keys are function handles
            hasFunctionHandles = any(cellfun(@(x) isa(x, 'function_handle'), splitKeys));

            if hasFunctionHandles
                self.tree.buildTreeWithSplitters(splitKeys);
            else
                self.tree.buildTree(splitKeys);
            end

            % Update tree browser
            self.initTreeBrowser();

            self.isBusy = false;
        end

        function nodes = getSelectedEpochTreeNodes(self)
            % GETSELECTEDEPOCHTREENODES Get selected tree nodes
            %
            % Returns cell array of epicTreeTools nodes

            if isempty(self.treeBrowser) || isempty(self.treeBrowser.graphTree)
                nodes = {};
                return;
            end

            % Get selected epicGraphicalTreeNodes
            [graphNodes, ~] = self.treeBrowser.graphTree.getSelectedNodes();

            % Extract epicTreeTools nodes from userData
            nodes = cell(size(graphNodes));
            for ii = 1:length(graphNodes)
                if ~isempty(graphNodes{ii}) && ~isempty(graphNodes{ii}.userData)
                    nodes{ii} = graphNodes{ii}.userData;
                end
            end
        end

        function epochs = getSelectedEpochs(self)
            % GETSELECTEDEPOCHS Get epochs from selected tree nodes
            %
            % Returns cell array of epoch structs

            nodes = self.getSelectedEpochTreeNodes();

            epochs = {};
            for ii = 1:length(nodes)
                if ~isempty(nodes{ii})
                    nodeEpochs = nodes{ii}.getAllEpochs(true);  % Only selected
                    epochs = [epochs; nodeEpochs(:)];
                end
            end
        end
    end

    %% Private Methods - UI Building
    methods (Access = private)
        function buildUIComponents(self)
            % Build all UI components

            % Initialize structs
            self.treeBrowser = struct();
            self.plottingCanvas = struct();

            % Create tree browser panel (left)
            self.buildTreeBrowserPanel();

            % Create plotting canvas (right)
            self.buildPlottingCanvas();

            % Create menu bar
            self.buildMenuBar();
        end

        function buildTreeBrowserPanel(self)
            % Build the tree browser panel (left side)

            % Main panel
            self.treeBrowser.panel = uipanel(self.figure, ...
                'Title', 'Epoch Tree', ...
                'FontSize', self.fontSize, ...
                'Units', 'normalized', ...
                'Position', [0 0 self.xDivLeft 1]);

            % Control panel (top)
            self.treeBrowser.controlPanel = uipanel(self.treeBrowser.panel, ...
                'Title', 'Split By', ...
                'FontSize', self.fontSize - 2, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.92 0.96 0.07]);

            % Split dropdown
            self.treeBrowser.splitDropdown = uicontrol(self.treeBrowser.controlPanel, ...
                'Style', 'popupmenu', ...
                'String', {'Cell Type', 'Date', 'Cell Type + Cell ID', 'Date + Cell ID', ...
                          'Cell Type + Date + Cell ID', 'Date + Cell Type', 'Protocol'}, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.15 0.96 0.7], ...
                'Callback', @(src,evt) self.onSplitChanged(src));

            % Tree axes (middle)
            self.treeBrowser.treeAxes = axes('Parent', self.treeBrowser.panel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.12 0.96 0.78]);

            % Initialize epicGraphicalTree
            self.treeBrowser.graphTree = epicGraphicalTree(self.treeBrowser.treeAxes, 'Epochs');
            self.treeBrowser.graphTree.nodesSelectedFcn = @(tree) self.onTreeSelectionChanged(tree);
            self.treeBrowser.graphTree.nodesCheckedFcn = @(tree) self.onTreeCheckChanged(tree);

            % Button panel (bottom)
            self.treeBrowser.buttonPanel = uipanel(self.treeBrowser.panel, ...
                'Title', '', ...
                'BorderType', 'none', ...
                'Units', 'normalized', ...
                'Position', [0.02 0.01 0.96 0.10]);

            % Set Example button
            self.treeBrowser.setExampleBtn = uicontrol(self.treeBrowser.buttonPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Set Example', ...
                'Units', 'normalized', ...
                'Position', [0.02 0.3 0.3 0.6], ...
                'Callback', @(src,evt) self.onSetExample());

            % Select All button
            self.treeBrowser.selectAllBtn = uicontrol(self.treeBrowser.buttonPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Select All', ...
                'Units', 'normalized', ...
                'Position', [0.35 0.3 0.3 0.6], ...
                'Callback', @(src,evt) self.onSelectAll());

            % Clear Selection button
            self.treeBrowser.clearSelBtn = uicontrol(self.treeBrowser.buttonPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Clear Sel', ...
                'Units', 'normalized', ...
                'Position', [0.68 0.3 0.3 0.6], ...
                'Callback', @(src,evt) self.onClearSelection());
        end

        function buildPlottingCanvas(self)
            % Build the plotting canvas (right side)

            % Main panel
            self.plottingCanvas.panel = uipanel(self.figure, ...
                'Title', 'Data Viewer', ...
                'FontSize', self.fontSize, ...
                'Units', 'normalized', ...
                'Position', [self.xDivLeft 0 (1 - self.xDivLeft) 1]);

            % Info table (top)
            self.plottingCanvas.infoTable = uitable(self.plottingCanvas.panel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.85 0.96 0.13], ...
                'ColumnName', {'Property', 'Value'}, ...
                'ColumnWidth', {120, 200}, ...
                'Data', {'Node', ''; 'Epochs', ''; 'Selected', ''});

            % Plot axes (bottom)
            self.plottingCanvas.axes = axes('Parent', self.plottingCanvas.panel, ...
                'Units', 'normalized', ...
                'Position', [0.1 0.1 0.85 0.70]);

            xlabel(self.plottingCanvas.axes, 'Time (ms)');
            ylabel(self.plottingCanvas.axes, 'Response');
        end

        function buildMenuBar(self)
            % Build menu bar

            % File menu
            fileMenu = uimenu(self.figure, 'Label', 'File');
            uimenu(fileMenu, 'Label', 'Load Data...', 'Callback', @(src,evt) self.onLoadData());
            uimenu(fileMenu, 'Label', 'Export Selection...', 'Callback', @(src,evt) self.onExportSelection(), 'Separator', 'on');
            uimenu(fileMenu, 'Label', 'Close', 'Callback', @(src,evt) self.onClose(), 'Separator', 'on');

            % Analysis menu
            analysisMenu = uimenu(self.figure, 'Label', 'Analysis');
            uimenu(analysisMenu, 'Label', 'Mean Response Trace', 'Callback', @(src,evt) self.onAnalysisMeanTrace());
            uimenu(analysisMenu, 'Label', 'Response Amplitude', 'Callback', @(src,evt) self.onAnalysisAmplitude());

            % Help menu
            helpMenu = uimenu(self.figure, 'Label', 'Help');
            uimenu(helpMenu, 'Label', 'Keyboard Shortcuts', 'Callback', @(src,evt) self.showKeyboardHelp());
            uimenu(helpMenu, 'Label', 'About', 'Callback', @(src,evt) self.showAbout());
        end

        function initTreeBrowser(self)
            % Initialize tree browser from epicTreeTools

            if isempty(self.tree)
                return;
            end

            % Delete existing epicGraphicalTree (cleans up all widgets)
            if ~isempty(self.treeBrowser.graphTree)
                delete(self.treeBrowser.graphTree);
            end

            % Recreate epicGraphicalTree
            self.treeBrowser.graphTree = epicGraphicalTree(self.treeBrowser.treeAxes, 'Epochs');
            gTree = self.treeBrowser.graphTree;
            gTree.nodesSelectedFcn = @(tree) self.onTreeSelectionChanged(tree);
            gTree.nodesCheckedFcn = @(tree) self.onTreeCheckChanged(tree);

            % Build graphical tree from epicTreeTools
            self.marryEpochNodesToWidgets(self.tree, gTree.trunk);

            % Draw
            gTree.trunk.isExpanded = true;
            gTree.draw();
        end

        function marryEpochNodesToWidgets(self, epochNode, browserNode)
            % Recursively create epicGraphicalTreeNodes for epicTreeTools nodes

            gTree = self.treeBrowser.graphTree;

            % Set browser node properties
            browserNode.userData = epochNode;

            % Get display name
            if ~isempty(epochNode.splitValue)
                if isnumeric(epochNode.splitValue)
                    browserNode.name = sprintf('%s = %g', epochNode.splitKey, epochNode.splitValue);
                elseif ischar(epochNode.splitValue)
                    displayValue = self.abbreviateProtocolName(epochNode.splitValue);
                    browserNode.name = sprintf('%s', displayValue);
                else
                    displayValue = self.abbreviateProtocolName(char(string(epochNode.splitValue)));
                    browserNode.name = displayValue;
                end
            else
                browserNode.name = 'Root';
            end

            % Add epoch count
            nEpochs = epochNode.epochCount();
            browserNode.name = sprintf('%s (%d)', browserNode.name, nEpochs);

            % Set check state from custom property
            browserNode.isChecked = epochNode.custom.isSelected;

            % Handle example nodes (red background)
            if epochNode.custom.isExample
                browserNode.textBackgroundColor = [1 0.8 0.8];
            end

            % Recurse on children OR create individual epoch nodes
            if ~epochNode.isLeaf
                % Internal node - recurse on children
                for ii = 1:length(epochNode.children)
                    childEpoch = epochNode.children{ii};
                    childBrowser = gTree.newNode(browserNode, '');
                    self.marryEpochNodesToWidgets(childEpoch, childBrowser);
                end
            elseif self.showEpochs && ~isempty(epochNode.epochList)
                % Leaf node - create individual epoch widgets (legacy behavior)
                epochs = epochNode.epochList;
                for ii = 1:length(epochs)
                    ep = epochs{ii};

                    % Create epoch widget
                    epochWidget = gTree.newNode(browserNode, '');
                    epochWidget.userData = ep;  % Store epoch struct directly, not tree node

                    % Set selection state
                    if isfield(ep, 'isSelected') && ~isempty(ep.isSelected)
                        epochWidget.isChecked = ep.isSelected;
                    else
                        epochWidget.isChecked = true;
                    end

                    % Format name: "#N: date/time"
                    epochWidget.name = self.formatEpochName(ii, ep);

                    % Pink background for individual epochs
                    epochWidget.textColor = [0 0 0];
                    epochWidget.textBackgroundColor = [1 .85 .85];
                end
            end
        end
    end

    %% Private Methods - Callbacks
    methods (Access = private)
        function onClose(self)
            delete(self);
        end

        function onLoadData(self)
            [file, path] = uigetfile({'*.mat', 'MATLAB Data (*.mat)'}, 'Select Data File');
            if file ~= 0
                self.loadData(fullfile(path, file));
            end
        end

        function onSplitChanged(self, src)
            % Handle split dropdown change

            splitIdx = get(src, 'Value');
            splitOptions = {
                {'cellInfo.type'}                                           % 1: Cell Type
                {@epicTreeTools.splitOnExperimentDate}                     % 2: Date
                {'cellInfo.type', 'cellInfo.id'}                           % 3: Cell Type + Cell ID
                {@epicTreeTools.splitOnExperimentDate, 'cellInfo.id'}     % 4: Date + Cell ID
                {@epicTreeTools.splitOnCellType, ...                       % 5: Cell Type + Date + Cell ID
                 @epicTreeTools.splitOnExperimentDate, 'cellInfo.id'}
                {@epicTreeTools.splitOnExperimentDate, ...                 % 6: Date + Cell Type
                 @epicTreeTools.splitOnCellType}
                {@epicTreeTools.splitOnProtocol}                           % 7: Protocol
            };

            if splitIdx <= length(splitOptions)
                self.rebuildTree(splitOptions{splitIdx});
            end
        end

        function onTreeSelectionChanged(self, ~)
            % Handle tree node selection change

            % Get selected graphical nodes
            if isempty(self.treeBrowser) || isempty(self.treeBrowser.graphTree)
                return;
            end

            [graphNodes, ~] = self.treeBrowser.graphTree.getSelectedNodes();
            if isempty(graphNodes) || isempty(graphNodes{1})
                return;
            end

            % Check userData type
            userData = graphNodes{1}.userData;

            if isa(userData, 'epicTreeTools')
                % Tree node clicked

                % Performance optimization: Navigate to first single epoch
                % Find first leaf node
                leaves = userData.leafNodes();
                if ~isempty(leaves)
                    firstLeaf = leaves{1};
                    % Get first epoch from that leaf
                    if ~isempty(firstLeaf.epochList)
                        firstEpoch = firstLeaf.epochList{1};
                        fprintf('Note: Showing first epoch from node "%s"\n', ...
                            string(userData.splitValue));
                        % Plot single epoch
                        self.updateInfoTableForEpoch(firstEpoch);
                        self.plotSingleEpoch(firstEpoch);
                        return;
                    end
                end

                % Fallback: if no epochs found, show node info
                self.updateInfoTable(userData);
                self.plotNodeData(userData);

            elseif isstruct(userData)
                % Individual epoch - display single epoch
                self.updateInfoTableForEpoch(userData);
                self.plotSingleEpoch(userData);
            end
        end

        function onTreeCheckChanged(self, ~)
            % Handle check/selection change

            % Sync check state to epicTreeTools nodes or individual epochs
            gTree = self.treeBrowser.graphTree;
            for ii = 1:length(gTree.nodeList)
                gNode = gTree.nodeList{ii};
                if ~isempty(gNode.userData)
                    if isa(gNode.userData, 'epicTreeTools')
                        % Tree node - update custom flag
                        gNode.userData.custom.isSelected = gNode.isChecked;
                        % Also update epochs if leaf
                        if gNode.userData.isLeaf
                            gNode.userData.setSelected(gNode.isChecked, false);
                        end
                    elseif isstruct(gNode.userData)
                        % Individual epoch - update isSelected field
                        gNode.userData.isSelected = gNode.isChecked;
                    end
                end
            end
        end

        function onSetExample(self)
            % Toggle example flag on selected nodes

            nodes = self.getSelectedEpochTreeNodes();
            for ii = 1:length(nodes)
                if ~isempty(nodes{ii})
                    nodes{ii}.custom.isExample = ~nodes{ii}.custom.isExample;
                end
            end
            self.initTreeBrowser();
        end

        function onSelectAll(self)
            % Select all epochs

            if ~isempty(self.tree)
                self.tree.setSelected(true, true);
                self.initTreeBrowser();
            end
        end

        function onClearSelection(self)
            % Clear all selections

            if ~isempty(self.tree)
                self.tree.setSelected(false, true);
                self.initTreeBrowser();
            end
        end

        function onExportSelection(self)
            % Export selected epochs

            epochs = self.getSelectedEpochs();
            if isempty(epochs)
                msgbox('No epochs selected', 'Export');
                return;
            end

            [file, path] = uiputfile('*.mat', 'Export Selected Epochs');
            if file ~= 0
                selectedEpochs = epochs;
                save(fullfile(path, file), 'selectedEpochs');
                msgbox(sprintf('Exported %d epochs', length(epochs)), 'Export');
            end
        end

        function onAnalysisMeanTrace(self)
            % Compute and plot mean response trace

            nodes = self.getSelectedEpochTreeNodes();
            if isempty(nodes) || isempty(nodes{1})
                msgbox('Select a tree node first', 'Analysis');
                return;
            end

            node = nodes{1};
            [data, ~, fs] = getSelectedData(node, 'Amp1', self.h5File);

            if isempty(data)
                msgbox('No response data available', 'Analysis');
                return;
            end

            % Convert to double and ensure fs is valid
            data = double(data);
            fs = double(fs);
            if isempty(fs) || fs == 0
                fs = 10000;  % Default sample rate
            end

            % Compute mean and SEM
            meanTrace = mean(data, 1);
            semTrace = std(data, [], 1) / sqrt(size(data, 1));
            t = (0:length(meanTrace)-1) / fs * 1000;

            % Plot
            ax = self.plottingCanvas.axes;
            cla(ax);
            hold(ax, 'on');
            fill(ax, [t fliplr(t)], [meanTrace-semTrace fliplr(meanTrace+semTrace)], ...
                [0.8 0.8 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
            plot(ax, t, meanTrace, 'b', 'LineWidth', 2);
            hold(ax, 'off');
            xlabel(ax, 'Time (ms)');
            ylabel(ax, 'Response');
            title(ax, sprintf('Mean Response (n=%d)', size(data,1)));
        end

        function onAnalysisAmplitude(self)
            msgbox('Amplitude analysis not yet implemented', 'Analysis');
        end

        function updateInfoTable(self, node)
            % Update info table for selected tree node

            nEpochs = node.epochCount();
            nSelected = node.selectedCount();

            % Convert splitValue to char (table requires char, not string objects)
            if isempty(node.splitValue)
                valueStr = '';
            elseif isnumeric(node.splitValue)
                valueStr = sprintf('%g', node.splitValue);
            elseif ischar(node.splitValue)
                valueStr = node.splitValue;
            else
                valueStr = char(string(node.splitValue));
            end

            data = {
                'Node', node.splitKey;
                'Value', valueStr;
                'Epochs', sprintf('%d', nEpochs);
                'Selected', sprintf('%d', nSelected)
            };

            set(self.plottingCanvas.infoTable, 'Data', data);
        end

        function updateInfoTableForEpoch(self, epoch)
            % Update info table for selected individual epoch

            % Extract epoch metadata
            if isfield(epoch, 'expInfo') && isfield(epoch.expInfo, 'date')
                dateStr = epoch.expInfo.date;
            else
                dateStr = 'Unknown';
            end

            if isfield(epoch, 'isSelected')
                isSelected = logical(epoch.isSelected);
            else
                isSelected = true;
            end

            % Get protocol name
            if isfield(epoch, 'protocolSettings') && isfield(epoch.protocolSettings, 'protocolID')
                protocol = epoch.protocolSettings.protocolID;
            elseif isfield(epoch, 'parameters') && isfield(epoch.parameters, 'protocol')
                protocol = epoch.parameters.protocol;
            else
                protocol = 'Unknown';
            end

            data = {
                'Type', 'Single Epoch';
                'Date', dateStr;
                'Protocol', char(protocol);
                'Selected', char(string(isSelected))
            };

            set(self.plottingCanvas.infoTable, 'Data', data);
        end

        function plotNodeData(self, node)
            % Plot data for selected tree node (aggregated epochs)

            ax = self.plottingCanvas.axes;

            % Get selected data (pass H5 file for lazy loading)
            [data, ~, fs] = getSelectedData(node, 'Amp1', self.h5File);

            if isempty(data)
                cla(ax);
                text(ax, 0.5, 0.5, 'No response data', ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
                return;
            end

            % Convert to double and ensure fs is valid
            data = double(data);
            fs = double(fs);
            if isempty(fs) || fs == 0
                fs = 10000;  % Default sample rate
            end

            % Plot all traces
            cla(ax);
            hold(ax, 'on');
            t = (0:size(data,2)-1) / fs * 1000;
            for ii = 1:min(size(data,1), 20)  % Limit to 20 traces
                plot(ax, t, data(ii,:), 'Color', [0.7 0.7 0.7]);
            end
            plot(ax, t, mean(data,1), 'k', 'LineWidth', 2);
            hold(ax, 'off');

            xlabel(ax, 'Time (ms)');
            ylabel(ax, 'Response');
            title(ax, sprintf('%d epochs', size(data,1)));
        end

        function plotSingleEpoch(self, epoch)
            % Plot data for a single epoch (lazy loaded from H5)

            ax = self.plottingCanvas.axes;
            cla(ax);

            try
                % Use getSelectedData for single epoch (lazy loads from H5)
                epochList = {epoch};
                [data, ~, fs] = getSelectedData(epochList, 'Amp1', self.h5File);

                if isempty(data)
                    text(ax, 0.5, 0.5, 'No response data', ...
                        'HorizontalAlignment', 'center', 'Units', 'normalized');
                    return;
                end

                % Convert to double and ensure fs is valid
                data = double(data(:)');  % Ensure row vector of doubles
                fs = double(fs);
                if isempty(fs) || fs == 0
                    fs = 10000;  % Default sample rate
                end

                % Plot single trace
                t = (0:length(data)-1) / fs * 1000;  % Convert to ms
                plot(ax, t, data, 'b', 'LineWidth', 1.5);

                xlabel(ax, 'Time (ms)');
                ylabel(ax, 'Amp1');
                title(ax, 'Single Epoch');

            catch ME
                text(ax, 0.5, 0.5, sprintf('Error loading data:\n%s', ME.message), ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
            end
        end

        function showKeyboardHelp(self)
            msg = sprintf([...
                'Keyboard Shortcuts:\n\n' ...
                'Up/Down Arrow - Navigate tree\n' ...
                'Left Arrow - Collapse node\n' ...
                'Right Arrow - Expand node\n' ...
                'F or Space - Toggle selection\n']);
            msgbox(msg, 'Keyboard Shortcuts');
        end

        function showAbout(self)
            msg = sprintf([...
                'Epic Tree GUI v2.0\n\n' ...
                'Pure MATLAB epoch tree browser.\n\n' ...
                'Based on legacy Rieke Lab tools.']);
            msgbox(msg, 'About');
        end

        function shortName = abbreviateProtocolName(~, fullName)
            % ABBREVIATEPROTOCOLNAME Shorten long protocol names for display
            %
            % Converts:
            %   'edu.washington.riekelab.protocols.SingleSpot'  -> 'SingleSpot'
            %   'edu.washington.riekelab.turner.protocols.Foo'  -> 'Foo'
            %
            % Max length: 40 characters (truncate with '...')

            if ~ischar(fullName) && ~isstring(fullName)
                shortName = char(fullName);
                return;
            end

            fullName = char(fullName);

            % Extract last component after final '.' (protocol name only)
            parts = strsplit(fullName, '.');
            if length(parts) > 1
                shortName = parts{end};
            else
                shortName = fullName;
            end

            % Truncate if still too long
            maxLen = 40;
            if length(shortName) > maxLen
                shortName = [shortName(1:maxLen-3) '...'];
            end
        end

        function name = formatEpochName(~, index, epoch)
            % FORMATEPOCHNAME Format epoch display name
            %
            % Legacy format: "#N: YYYY-MM-DD HH:MM:SS"
            % Example: "  1: 2025-12-02 10:15:30"

            % Try to extract date/time from epoch
            if isfield(epoch, 'expInfo') && isfield(epoch.expInfo, 'date')
                dateStr = epoch.expInfo.date;
            elseif isfield(epoch, 'startTime')
                dateStr = epoch.startTime;
            else
                dateStr = '';
            end

            % Format name
            if ~isempty(dateStr)
                name = sprintf('%3d: %s', index, dateStr);
            else
                name = sprintf('%3d', index);
            end
        end

        function h5Path = getH5FilePath(~, metadata, matPath)
            % GETH5FILEPATH Get H5 file path for lazy loading
            %
            % Tries multiple strategies to find the H5 file

            % Strategy 1: Check epicTreeConfig
            try
                config = epicTreeConfig();
                if isfield(config, 'h5_dir') && ~isempty(config.h5_dir)
                    h5Dir = config.h5_dir;
                    % Look for H5 file in this directory
                    if isfield(metadata, 'exp_name')
                        h5Path = fullfile(h5Dir, [metadata.exp_name '.h5']);
                        if exist(h5Path, 'file')
                            return;
                        end
                    end
                end
            catch
                % Config not available
            end

            % Strategy 2: Look for h5 directory next to .mat file
            [matDir, matName, ~] = fileparts(matPath);
            h5Dir = fullfile(fileparts(matDir), 'h5');
            if exist(h5Dir, 'dir')
                % Extract experiment name from mat file
                if isfield(metadata, 'exp_name')
                    expName = metadata.exp_name;
                else
                    % Use mat filename as experiment name
                    expName = matName;
                end

                h5Path = fullfile(h5Dir, [expName '.h5']);
                if exist(h5Path, 'file')
                    return;
                end
            end

            % Strategy 3: Return empty (will use in-memory data if available)
            h5Path = '';
        end
    end
end
