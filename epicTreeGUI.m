classdef epicTreeGUI < handle
    % EPICTREEGUI Interactive GUI for visualizing and analyzing epoch data
    %
    % Main GUI controller that integrates:
    %   - epicTreeTools (data organization)
    %   - graphicalTree (tree visualization)
    %   - singleEpoch (epoch viewer)
    %
    % Usage:
    %   gui = epicTreeGUI('data.mat')
    %   gui = epicTreeGUI('data.mat', 'noEpochs')  % Hide individual epochs
    %
    % Layout:
    %   [40% Tree Browser] | [60% Viewer/Plotting]
    %
    % See also: epicTreeTools, graphicalTree, getSelectedData

    properties
        % Data
        tree                    % epicTreeTools root node
        allEpochs               % Flat epoch list (cell array)
        treeData                % Original hierarchical data struct

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
        function self = epicTreeGUI(dataPath, varargin)
            % Constructor
            %
            % Usage:
            %   gui = epicTreeGUI('data.mat')
            %   gui = epicTreeGUI('data.mat', 'noEpochs')

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
            if nargin >= 1 && ~isempty(dataPath)
                self.loadData(dataPath);
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
                [data, ~] = loadEpicTreeData(dataPath);
                self.treeData = data;

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

            % Get selected graphicalTreeNodes
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
                'String', {'Cell Type', 'Contrast', 'Protocol', 'Date', 'Cell Type + Contrast'}, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.15 0.96 0.7], ...
                'Callback', @(src,evt) self.onSplitChanged(src));

            % Tree axes (middle)
            self.treeBrowser.treeAxes = axes('Parent', self.treeBrowser.panel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.12 0.96 0.78]);

            % Initialize graphicalTree
            self.treeBrowser.graphTree = graphicalTree(self.treeBrowser.treeAxes, 'Epochs');
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

            % Clear existing graphicalTree
            gTree = self.treeBrowser.graphTree;
            gTree.nodeList = {};
            gTree.widgetList = {};

            % Recreate graphicalTree
            self.treeBrowser.graphTree = graphicalTree(self.treeBrowser.treeAxes, 'Epochs');
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
            % Recursively create graphicalTreeNodes for epicTreeTools nodes

            gTree = self.treeBrowser.graphTree;

            % Set browser node properties
            browserNode.userData = epochNode;

            % Get display name
            if ~isempty(epochNode.splitValue)
                if isnumeric(epochNode.splitValue)
                    browserNode.name = sprintf('%s = %g', epochNode.splitKey, epochNode.splitValue);
                else
                    browserNode.name = sprintf('%s', string(epochNode.splitValue));
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

            % Recurse on children
            if ~epochNode.isLeaf
                for ii = 1:length(epochNode.children)
                    childEpoch = epochNode.children{ii};
                    childBrowser = gTree.newNode(browserNode, '');
                    self.marryEpochNodesToWidgets(childEpoch, childBrowser);
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
                {'cellInfo.type'}
                {'parameters.contrast'}
                {@epicTreeTools.splitOnProtocol}
                {@epicTreeTools.splitOnExperimentDate}
                {'cellInfo.type', 'parameters.contrast'}
            };

            if splitIdx <= length(splitOptions)
                self.rebuildTree(splitOptions{splitIdx});
            end
        end

        function onTreeSelectionChanged(self, ~)
            % Handle tree node selection change

            nodes = self.getSelectedEpochTreeNodes();
            if isempty(nodes) || isempty(nodes{1})
                return;
            end

            node = nodes{1};
            self.updateInfoTable(node);
            self.plotNodeData(node);
        end

        function onTreeCheckChanged(self, ~)
            % Handle check/selection change

            % Sync check state to epicTreeTools nodes
            gTree = self.treeBrowser.graphTree;
            for ii = 1:length(gTree.nodeList)
                gNode = gTree.nodeList{ii};
                if ~isempty(gNode.userData)
                    gNode.userData.custom.isSelected = gNode.isChecked;
                    % Also update epochs if leaf
                    if gNode.userData.isLeaf
                        gNode.userData.setSelected(gNode.isChecked, false);
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
            [data, ~, fs] = getSelectedData(node, 'Amp1');

            if isempty(data)
                msgbox('No response data available', 'Analysis');
                return;
            end

            % Compute mean and SEM
            meanTrace = mean(data, 1);
            semTrace = std(data, [], 1) / sqrt(size(data, 1));
            t = (1:length(meanTrace)) / fs * 1000;

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
            % Update info table for selected node

            nEpochs = node.epochCount();
            nSelected = node.selectedCount();

            data = {
                'Node', node.splitKey;
                'Value', string(node.splitValue);
                'Epochs', sprintf('%d', nEpochs);
                'Selected', sprintf('%d', nSelected)
            };

            set(self.plottingCanvas.infoTable, 'Data', data);
        end

        function plotNodeData(self, node)
            % Plot data for selected node

            ax = self.plottingCanvas.axes;

            % Get selected data
            [data, ~, fs] = getSelectedData(node, 'Amp1');

            if isempty(data)
                cla(ax);
                text(ax, 0.5, 0.5, 'No response data', ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
                return;
            end

            % Plot all traces
            cla(ax);
            hold(ax, 'on');
            t = (1:size(data,2)) / fs * 1000;
            for ii = 1:min(size(data,1), 20)  % Limit to 20 traces
                plot(ax, t, data(ii,:), 'Color', [0.7 0.7 0.7]);
            end
            plot(ax, t, mean(data,1), 'k', 'LineWidth', 2);
            hold(ax, 'off');

            xlabel(ax, 'Time (ms)');
            ylabel(ax, 'Response');
            title(ax, sprintf('%d epochs', size(data,1)));
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
    end
end
