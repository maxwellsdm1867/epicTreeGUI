classdef epicTreeTools < handle
    % EPICTREETOOLS Hierarchical tree structure for organizing epoch data
    %
    % This class provides tree-based organization and navigation for epoch
    % data, with controlled access to node custom properties.
    %
    % NAVIGATION PATTERNS:
    % ====================
    % Navigate DOWN (to children):
    %   n = node.childrenLength()          % Number of children
    %   child = node.childAt(idx)          % Get child by index (1-based)
    %   child = node.childBySplitValue(v)  % Find child by split value
    %   leaves = node.leafNodes()          % Get all leaf nodes below
    %
    % Navigate UP (to parents):
    %   parent = node.parent               % Direct parent
    %   ancestor = node.parentAt(3)        % Go up 3 levels
    %   root = node.getRoot()              % Get root node
    %   d = node.depth()                   % Levels from root (root=0)
    %
    % Loop over children:
    %   for i = 1:node.childrenLength()
    %       child = node.childAt(i);
    %       % process child
    %   end
    %
    % CONTROLLED ACCESS (put/get custom data):
    % ========================================
    % Store analysis results at a node:
    %   results.ImageSum = ImageResp;
    %   results.NLI = NLI;
    %   node.putCustom('results', results);
    %
    % Retrieve stored results:
    %   results = node.getCustom('results');
    %   if ~isempty(results)
    %       ImageSum = results.ImageSum;
    %   end
    %
    % Check if key exists:
    %   if node.hasCustom('results')
    %       % process
    %   end
    %
    % TYPICAL ANALYSIS WORKFLOW:
    % ==========================
    %   % Navigate tree and analyze
    %   for i = 1:rootNode.childrenLength()
    %       cellTypeNode = rootNode.childAt(i);
    %       cellType = cellTypeNode.splitValue;
    %
    %       for j = 1:cellTypeNode.childrenLength()
    %           dateNode = cellTypeNode.childAt(j);
    %
    %           for k = 1:dateNode.childrenLength()
    %               cellNode = dateNode.childAt(k);
    %
    %               % Run analysis
    %               epochs = cellNode.getAllEpochs(true);  % selected only
    %               [data, fs] = getSelectedData(epochs, 'Amp1');
    %               results = analyzeData(data);
    %
    %               % Store results at cell level
    %               cellNode.putCustom('results', results);
    %           end
    %       end
    %   end
    %
    %   % Later: query stored results
    %   results = cellNode.getCustom('results');
    %
    % Properties:
    %   splitKey    - Key path used for this split (empty for root)
    %   splitValue  - Value at this split (empty for root)
    %   children    - Cell array of child epicTreeTools nodes
    %   epochList   - Cell array of epochs (only for leaf nodes)
    %   isLeaf      - True if this is a leaf node
    %   parent      - Reference to parent node (empty for root)
    %
    % See also: loadEpicTreeData, getSelectedData, CompatibilityList

    properties
        splitKey = ''           % Key path used for splitting at this node
        splitValue = []         % Value at this split
        children = {}           % Cell array of child epicTreeTools nodes
        epochList = {}          % Cell array of epochs (leaf nodes only)
        isLeaf = false          % True if this is a leaf node
        parent = []             % Reference to parent node
        allEpochs = {}          % Flattened epoch list (root only)
        treeData = []           % Original hierarchical data (root only)
        sourceFile = ''         % Path to source .mat file (for .ugm file discovery)
    end

    properties (SetAccess = private)
        % Custom properties for GUI state (replaces Java HashMap)
        % PROTECTED - use putCustom()/getCustom() for access
        % - isSelected: Selection state for this tree node
        % - isExample: Flag to mark this node as an example (highlights in GUI)
        % - display: Struct with name, color, backgroundColor for rendering
        % - results: Struct to cache analysis results on this node
        custom = struct('isSelected', true, 'isExample', false, ...
                       'display', struct('name', '', 'color', [0 0 0], 'backgroundColor', 'none'), ...
                       'results', struct())
    end

    methods
        function obj = epicTreeTools(dataOrParent, varargin)
            % Constructor - create epicTreeTools from data or as child node
            %
            % Usage:
            %   tree = epicTreeTools(treeData)  % Create root from loaded data
            %   tree = epicTreeTools(parent)    % Create child node
            %   tree = epicTreeTools()          % Create empty node
            %   tree = epicTreeTools(treeData, 'LoadUserMetadata', 'auto')
            %   tree = epicTreeTools(treeData, 'LoadUserMetadata', 'latest')
            %   tree = epicTreeTools(treeData, 'LoadUserMetadata', 'none')
            %   tree = epicTreeTools(treeData, 'LoadUserMetadata', '/path/to/file.ugm')
            %
            % Name-Value Arguments:
            %   LoadUserMetadata - Controls .ugm file loading:
            %     'auto' (default) - Auto-load latest .ugm if exists (silent if not found)
            %     'latest'         - Load latest .ugm, error if none exists
            %     'none'           - Skip loading (all epochs selected)
            %     '/path/file.ugm' - Load specific .ugm file

            if nargin == 0
                return;
            end

            if isa(dataOrParent, 'epicTreeTools')
                % Creating child node - don't parse varargin for LoadUserMetadata
                obj.parent = dataOrParent;
            elseif isstruct(dataOrParent)
                % Creating root from data
                obj.treeData = dataOrParent;
                obj.allEpochs = obj.extractAllEpochs(dataOrParent);
                obj.epochList = obj.allEpochs;
                obj.isLeaf = true;  % Until buildTree is called

                % Capture source file path if available in data
                if isfield(dataOrParent, 'source_file')
                    obj.sourceFile = dataOrParent.source_file;
                end

                % Parse optional arguments
                p = inputParser;
                p.KeepUnmatched = true;  % Allow unknown params
                addParameter(p, 'LoadUserMetadata', 'auto', @(x) ischar(x) || isstring(x));
                parse(p, varargin{:});

                loadOption = char(p.Results.LoadUserMetadata);

                if strcmp(loadOption, 'auto')
                    % Auto-load latest .ugm if exists (silent if none found)
                    if ~isempty(obj.sourceFile)
                        ugmFile = epicTreeTools.findLatestUGM(obj.sourceFile);
                        if ~isempty(ugmFile)
                            fprintf('Auto-loading selection mask: %s\n', ugmFile);
                            obj.loadUserMetadata(ugmFile);  % This prints its own warning
                        end
                    end
                elseif strcmp(loadOption, 'latest')
                    % Load latest, error if none exists
                    if isempty(obj.sourceFile)
                        error('epicTreeTools:NoSourceFile', ...
                            'Cannot find .ugm files: sourceFile not set. Set sourceFile property or pass data with source_file field.');
                    end
                    ugmFile = epicTreeTools.findLatestUGM(obj.sourceFile);
                    if isempty(ugmFile)
                        error('epicTreeTools:NoUGMFiles', ...
                            'No .ugm files found for: %s', obj.sourceFile);
                    end
                    obj.loadUserMetadata(ugmFile);
                elseif strcmp(loadOption, 'none')
                    % Skip loading, all epochs selected by default (already the case)
                else
                    % Assume it's a filename path
                    if ~obj.loadUserMetadata(loadOption)
                        warning('epicTreeTools:UGMLoadFailed', ...
                            'Failed to load user metadata from: %s', loadOption);
                    end
                end
            end
        end

        function buildTree(obj, keyPaths)
            % BUILDTREE Build hierarchical tree by grouping on key paths
            %
            % Usage:
            %   tree.buildTree({'cellInfo.type', 'protocolSettings.contrast'})
            %
            % Inputs:
            %   keyPaths - Cell array of key path strings for splitting
            %
            % Description:
            %   Reorganizes the flat epoch list into a hierarchical tree
            %   structure. Each key path creates a level in the tree.

            if isempty(obj.allEpochs) && ~isempty(obj.epochList)
                obj.allEpochs = obj.epochList;
            end

            if isempty(obj.allEpochs)
                warning('epicTreeTools:NoData', 'No epochs to build tree from');
                return;
            end

            % Build tree recursively
            obj.buildTreeRecursive(obj.allEpochs, keyPaths);
        end

        function buildTreeWithSplitters(obj, splitters)
            % BUILDTREEWITHSPLITTERS Build tree using custom splitter functions
            %
            % Usage:
            %   tree.buildTreeWithSplitters({@epicTreeTools.splitOnCellType, ...
            %                                @epicTreeTools.splitOnContrast})
            %
            %   % Or mix key paths and function handles:
            %   tree.buildTreeWithSplitters({'cellInfo.type', ...
            %                                @epicTreeTools.splitOnF1F2Phase})
            %
            % Inputs:
            %   splitters - Cell array of splitters. Each can be:
            %               - String: key path (e.g., 'parameters.contrast')
            %               - Function handle: @(epoch) -> split value
            %
            % Description:
            %   Like buildTree but accepts function handles for custom splitting.
            %   Function handles should take an epoch struct and return a value.

            if isempty(obj.allEpochs) && ~isempty(obj.epochList)
                obj.allEpochs = obj.epochList;
            end

            if isempty(obj.allEpochs)
                warning('epicTreeTools:NoData', 'No epochs to build tree from');
                return;
            end

            % Build tree recursively with splitters
            obj.buildTreeWithSplittersRecursive(obj.allEpochs, splitters);
        end

        function node = childBySplitValue(obj, value)
            % CHILDBYSPLITVALUE Find child node by its split value
            %
            % Usage:
            %   child = tree.childBySplitValue('OnP')
            %   child = tree.childBySplitValue(0.5)
            %
            % Returns empty [] if not found

            node = [];

            for i = 1:length(obj.children)
                child = obj.children{i};
                if obj.valuesEqual(child.splitValue, value)
                    node = child;
                    return;
                end
            end
        end

        function leaves = leafNodes(obj)
            % LEAFNODES Get all leaf nodes under this node
            %
            % Usage:
            %   leaves = tree.leafNodes()
            %
            % Returns cell array of epicTreeTools leaf nodes

            leaves = {};

            if obj.isLeaf
                leaves = {obj};
                return;
            end

            for i = 1:length(obj.children)
                childLeaves = obj.children{i}.leafNodes();
                leaves = [leaves; childLeaves(:)];
            end
        end

        function sv = splitValues(obj)
            % SPLITVALUES Get all split key-values from root to this node
            %
            % Usage:
            %   sv = node.splitValues()
            %
            % Returns struct with fields for each split key

            sv = struct();
            node = obj;

            while ~isempty(node)
                if ~isempty(node.splitKey) && ~isempty(node.splitValue)
                    fieldName = strrep(node.splitKey, '.', '_');
                    fieldName = matlab.lang.makeValidName(fieldName);
                    sv.(fieldName) = node.splitValue;
                end

                node = node.parent;
            end
        end

        function epochs = sortedBy(obj, keyPath)
            % SORTEDBY Return epochs sorted by key path value
            %
            % Usage:
            %   sorted = tree.sortedBy('protocolSettings.contrast')

            epochs = obj.epochList;
            if isempty(epochs)
                return;
            end

            % Extract values
            n = length(epochs);
            values = cell(n, 1);
            for i = 1:n
                values{i} = obj.getNestedValue(epochs{i}, keyPath);
            end

            % Sort
            [~, sortIdx] = obj.sortValues(values);
            epochs = epochs(sortIdx);
        end

        function names = responseStreamNames(obj)
            % RESPONSESTREAMNAMES Get unique response stream names
            %
            % Usage:
            %   names = tree.responseStreamNames()

            names = obj.getStreamNames('responses');
        end

        function names = stimuliStreamNames(obj)
            % STIMULISTREAMNAMES Get unique stimulus stream names
            %
            % Usage:
            %   names = tree.stimuliStreamNames()

            names = obj.getStreamNames('stimuli');
        end

        function n = length(obj)
            % LENGTH Number of epochs in this node's epochList
            n = length(obj.epochList);
        end

        function epoch = elements(obj, idx)
            % ELEMENTS Get epoch by index (1-based)
            %
            % Usage:
            %   epoch = tree.elements(1)
            %   allEpochs = tree.elements()  % returns all

            if nargin < 2
                epoch = obj.epochList;
            else
                epoch = obj.epochList{idx};
            end
        end

        function disp(obj)
            % Display tree node info
            if obj.isLeaf
                fprintf('epicTreeTools (leaf): %d epochs\n', length(obj.epochList));
            else
                fprintf('epicTreeTools: %d children\n', length(obj.children));
            end
            if ~isempty(obj.splitKey)
                fprintf('  splitKey: %s\n', obj.splitKey);
                fprintf('  splitValue: %s\n', string(obj.splitValue));
            end
        end

        %% ================================================================
        % TREE NAVIGATION METHODS (from JAUIMODEL EpochTree interface)
        % ================================================================

        function child = child(obj, index)
            % CHILD Get child node by index (1-based)
            %
            % Usage:
            %   child = tree.child(1)  % Get first child
            %
            % Equivalent to Java: children(int index)

            if index < 1 || index > length(obj.children)
                error('epicTreeTools:InvalidIndex', 'Child index out of range');
            end
            child = obj.children{index};
        end

        function leaf = leafNode(obj, index)
            % LEAFNODE Get specific leaf node by index (1-based)
            %
            % Usage:
            %   leaf = tree.leafNode(1)  % Get first leaf
            %
            % Equivalent to Java: leafNodes(int index)

            leaves = obj.leafNodes();
            if index < 1 || index > length(leaves)
                error('epicTreeTools:InvalidIndex', 'Leaf index out of range');
            end
            leaf = leaves{index};
        end

        function value = splitValueByKey(obj, key)
            % SPLITVALUEBYKEY Get specific split value by key
            %
            % Usage:
            %   contrast = node.splitValueByKey('parameters.contrast')
            %
            % Equivalent to Java: splitValues(String key)

            sv = obj.splitValues();
            fieldName = strrep(key, '.', '_');
            fieldName = matlab.lang.makeValidName(fieldName);
            if isfield(sv, fieldName)
                value = sv.(fieldName);
            else
                value = [];
            end
        end

        function paths = splitKeyPaths(obj)
            % SPLITKEYPATHS Get array of all split key paths from root to this node
            %
            % Usage:
            %   paths = node.splitKeyPaths()
            %
            % Returns cell array of key path strings used for splitting.
            % Equivalent to Java: splitKeyPaths()

            paths = {};
            node = obj;

            while ~isempty(node)
                if ~isempty(node.splitKey)
                    paths = [{node.splitKey}; paths];
                end
                node = node.parent;
            end
        end

        function nodes = descendentsDepthFirst(obj)
            % DESCENDENTSDEPTHFIRST Get all descendant nodes in depth-first order
            %
            % Usage:
            %   allNodes = tree.descendentsDepthFirst()
            %
            % Equivalent to Java: descendentsDepthFirst()

            nodes = {};

            if obj.isLeaf
                nodes = {obj};
                return;
            end

            for i = 1:length(obj.children)
                childNodes = obj.children{i}.descendentsDepthFirst();
                nodes = [nodes; childNodes(:)];
            end
        end

        function epoch = firstValue(obj)
            % FIRSTVALUE Get first epoch in epoch list
            %
            % Usage:
            %   epoch = node.firstValue()
            %
            % Equivalent to Java: CompatabilityList.firstValue()

            if isempty(obj.epochList)
                epoch = [];
            else
                epoch = obj.epochList{1};
            end
        end

        function epoch = valueByIndex(obj, index)
            % VALUEBYINDEX Get epoch by index (alias for elements)
            %
            % Usage:
            %   epoch = node.valueByIndex(1)
            %
            % Equivalent to Java: CompatabilityList.valueByIndex(int)

            epoch = obj.elements(index);
        end

        function n = numChildren(obj)
            % NUMCHILDREN Get number of children
            %
            % Usage:
            %   n = node.numChildren()

            n = length(obj.children);
        end

        function n = numLeaves(obj)
            % NUMLEAVES Get number of leaf nodes
            %
            % Usage:
            %   n = tree.numLeaves()

            leaves = obj.leafNodes();
            n = length(leaves);
        end

        %% ================================================================
        % CONTROLLED ACCESS METHODS (replaces Java HashMap custom property)
        % These methods provide controlled access to node custom data.
        % Analysis code should use these instead of direct property access.
        % ================================================================

        function putCustom(obj, key, value)
            % PUTCUSTOM Store data in node's custom property
            %
            % Usage:
            %   node.putCustom('results', myResults)
            %   node.putCustom('NLIs', nliArray)
            %
            % This is the ONLY way to store custom data on nodes.
            % Equivalent to Java: node.custom.put(key, value)
            %
            % Common keys:
            %   'results'    - Analysis results struct
            %   'stimParamz' - Stimulus parameters
            %   'norNLI'     - Normalized NLI values
            %   'NLIs'       - NLI array for cell type
            %
            % Example:
            %   % Store analysis results
            %   results.ImageSum = ImageResp;
            %   results.DiscSum = DiscResp;
            %   results.NLI = NLI;
            %   node.putCustom('results', results);

            if ~ischar(key) && ~isstring(key)
                error('epicTreeTools:InvalidKey', 'Key must be a string');
            end

            % Use dynamic field name to set the value
            obj.custom.(key) = value;
        end

        function value = getCustom(obj, key)
            % GETCUSTOM Retrieve data from node's custom property
            %
            % Usage:
            %   results = node.getCustom('results')
            %   nlis = node.getCustom('NLIs')
            %
            % Returns empty [] if key not found.
            % Equivalent to Java: node.custom.get(key)
            %
            % Example:
            %   % Retrieve stored results
            %   results = node.getCustom('results');
            %   if ~isempty(results)
            %       ImageSum = results.ImageSum;
            %       DiscSum = results.DiscSum;
            %   end

            if ~ischar(key) && ~isstring(key)
                error('epicTreeTools:InvalidKey', 'Key must be a string');
            end

            if isfield(obj.custom, key)
                value = obj.custom.(key);
            else
                value = [];
            end
        end

        function tf = hasCustom(obj, key)
            % HASCUSTOM Check if key exists in custom property
            %
            % Usage:
            %   if node.hasCustom('results')
            %       % process results
            %   end

            tf = isfield(obj.custom, key);
        end

        function removeCustom(obj, key)
            % REMOVECUSTOM Remove key from custom property
            %
            % Usage:
            %   node.removeCustom('tempData')

            if isfield(obj.custom, key)
                obj.custom = rmfield(obj.custom, key);
            end
        end

        function keys = customKeys(obj)
            % CUSTOMKEYS Get all keys in custom property
            %
            % Usage:
            %   keys = node.customKeys()

            keys = fieldnames(obj.custom);
        end

        %% ================================================================
        % CHILDREN NAVIGATION METHODS
        % These provide Java-style access patterns for tree traversal.
        % ================================================================

        function child = childAt(obj, index)
            % CHILDAT Get child by 1-based index
            %
            % Usage:
            %   child = node.childAt(1)  % Get first child
            %
            % Same as child() but clearer name for indexed access.
            % Equivalent to Java: children.elements(index)

            if index < 1 || index > length(obj.children)
                error('epicTreeTools:InvalidIndex', ...
                    'Child index %d out of range [1, %d]', index, length(obj.children));
            end
            child = obj.children{index};
        end

        function n = childrenLength(obj)
            % CHILDRENLENGTH Get number of children
            %
            % Usage:
            %   for i = 1:node.childrenLength()
            %       child = node.childAt(i);
            %   end
            %
            % Equivalent to Java: children.length

            n = length(obj.children);
        end

        function iter = childIterator(obj)
            % CHILDITERATOR Get cell array of children for iteration
            %
            % Usage:
            %   for child = node.childIterator()
            %       % process child{1}
            %   end
            %
            % Or use directly:
            %   children = node.childIterator();
            %   for i = 1:length(children)
            %       child = children{i};
            %   end

            iter = obj.children;
        end

        function list = getChildren(obj)
            % GETCHILDREN Get children as CompatibilityList for Java-style access
            %
            % Usage:
            %   children = node.getChildren();
            %   for i = 1:children.length
            %       child = children.elements(i);
            %   end
            %
            % This provides Java-style navigation:
            %   node.getChildren().length       % number of children
            %   node.getChildren().elements(i)  % get child by index
            %
            % Equivalent to Java: node.children (as CompatibilityList)

            list = CompatibilityList(obj.children);
        end

        function list = getEpochList(obj)
            % GETEPOCHLIST Get epoch list as CompatibilityList for Java-style access
            %
            % Usage:
            %   epochs = node.getEpochList();
            %   for i = 1:epochs.length
            %       epoch = epochs.elements(i);
            %   end
            %
            % This provides Java-style navigation:
            %   node.getEpochList().length       % number of epochs
            %   node.getEpochList().elements(i)  % get epoch by index
            %
            % Equivalent to Java: node.epochList (as CompatibilityList)

            list = CompatibilityList(obj.epochList);
        end

        %% ================================================================
        % PARENT NAVIGATION METHODS
        % The .parent property provides upward tree traversal for accessing
        % higher levels in the tree hierarchy.
        % ================================================================

        function ancestor = parentAt(obj, levelsUp)
            % PARENTAT Get ancestor node N levels up
            %
            % Usage:
            %   grandparent = node.parentAt(2)  % Go up 2 levels
            %   root = node.parentAt(node.depth())  % Go to root
            %
            % Returns empty [] if levelsUp exceeds tree depth.
            %
            % Example:
            %   % If at Level 5 and need Level 2 (3 levels up):
            %   target = currentNode.parentAt(3);

            ancestor = obj;
            for i = 1:levelsUp
                if isempty(ancestor.parent)
                    ancestor = [];
                    return;
                end
                ancestor = ancestor.parent;
            end
        end

        function d = depth(obj)
            % DEPTH Get depth of this node from root (root = 0)
            %
            % Usage:
            %   d = node.depth()
            %
            % Example:
            %   % Leaf at depth 5 means 5 levels below root

            d = 0;
            node = obj;
            while ~isempty(node.parent)
                d = d + 1;
                node = node.parent;
            end
        end

        function path = pathFromRoot(obj)
            % PATHFROMROOT Get array of nodes from root to this node
            %
            % Usage:
            %   path = node.pathFromRoot()
            %   % path{1} = root, path{end} = node
            %
            % Useful for displaying full path or navigating.

            path = {obj};
            node = obj;
            while ~isempty(node.parent)
                node = node.parent;
                path = [{node}; path];
            end
        end

        function str = pathString(obj, separator)
            % PATHSTRING Get string representation of path from root
            %
            % Usage:
            %   str = node.pathString()      % Uses ' > ' separator
            %   str = node.pathString('/')   % Custom separator
            %
            % Example:
            %   % Returns: 'Root > OnP > 0.5 > epoch-123'

            if nargin < 2
                separator = ' > ';
            end

            path = obj.pathFromRoot();
            parts = {};
            for i = 1:length(path)
                node = path{i};
                if isempty(node.splitValue)
                    parts{end+1} = 'Root';
                elseif isnumeric(node.splitValue)
                    parts{end+1} = sprintf('%g', node.splitValue);
                else
                    parts{end+1} = char(string(node.splitValue));
                end
            end
            str = strjoin(parts, separator);
        end

        %% ================================================================
        % DATA MATRIX METHODS (from JAUIMODEL EpochList interface)
        % ================================================================

        function dataMatrix = stimuliByStreamName(obj, streamName)
            % STIMULIBYSTREAMNAME Get stimulus data matrix for all epochs
            %
            % Usage:
            %   stimMatrix = node.stimuliByStreamName('Stage')
            %
            % Returns matrix where each row is one epoch's stimulus data.
            % Equivalent to Java: EpochList.stimuliByStreamName(String)

            epochs = obj.epochList;
            if isempty(epochs)
                dataMatrix = [];
                return;
            end

            % Get first stimulus to determine size
            firstStim = epicTreeTools.getStimulusByName(epochs{1}, streamName);
            if isempty(firstStim) || ~isfield(firstStim, 'data')
                dataMatrix = [];
                return;
            end

            nSamples = length(firstStim.data);
            nEpochs = length(epochs);
            dataMatrix = zeros(nEpochs, nSamples);

            for i = 1:nEpochs
                stim = epicTreeTools.getStimulusByName(epochs{i}, streamName);
                if ~isempty(stim) && isfield(stim, 'data')
                    data = stim.data(:)';
                    if length(data) == nSamples
                        dataMatrix(i, :) = data;
                    elseif length(data) < nSamples
                        dataMatrix(i, 1:length(data)) = data;
                    else
                        dataMatrix(i, :) = data(1:nSamples);
                    end
                end
            end
        end

        function dataMatrix = responsesByStreamName(obj, streamName)
            % RESPONSESBYSTREAMNAME Get response data matrix for all epochs
            %
            % Usage:
            %   respMatrix = node.responsesByStreamName('Amp1')
            %
            % Returns matrix where each row is one epoch's response data.

            epochs = obj.epochList;
            if isempty(epochs)
                dataMatrix = [];
                return;
            end

            % Get first response to determine size
            [firstData, ~, ~] = epicTreeTools.getResponseData(epochs{1}, streamName);
            if isempty(firstData)
                dataMatrix = [];
                return;
            end

            nSamples = length(firstData);
            nEpochs = length(epochs);
            dataMatrix = zeros(nEpochs, nSamples);

            for i = 1:nEpochs
                [data, ~, ~] = epicTreeTools.getResponseData(epochs{i}, streamName);
                if ~isempty(data)
                    if length(data) == nSamples
                        dataMatrix(i, :) = data;
                    elseif length(data) < nSamples
                        dataMatrix(i, 1:length(data)) = data;
                    else
                        dataMatrix(i, :) = data(1:nSamples);
                    end
                end
            end
        end

        function [dataMatrix, sampleRate] = dataMatrix(obj, deviceName)
            % DATAMATRIX Get response data matrix and sample rate
            %
            % Usage:
            %   [data, fs] = node.dataMatrix('Amp1')
            %
            % Convenience method combining responsesByStreamName with sample rate.
            % Equivalent to Java: GenericEpochList.dataMatrix()

            dataMatrix = obj.responsesByStreamName(deviceName);
            sampleRate = [];

            if ~isempty(obj.epochList)
                resp = epicTreeTools.getResponseByName(obj.epochList{1}, deviceName);
                if ~isempty(resp) && isfield(resp, 'sample_rate')
                    sampleRate = resp.sample_rate;
                end
            end
        end

        function spikesMatrix = spikeTimesMatrix(obj, deviceName)
            % SPIKETIMESMATRIX Get spike times for all epochs
            %
            % Usage:
            %   spikes = node.spikeTimesMatrix('Amp1')
            %
            % Returns cell array where each cell contains spike times for one epoch.

            epochs = obj.epochList;
            nEpochs = length(epochs);
            spikesMatrix = cell(nEpochs, 1);

            for i = 1:nEpochs
                [~, ~, spikes] = epicTreeTools.getResponseData(epochs{i}, deviceName);
                spikesMatrix{i} = spikes;
            end
        end

        %% ================================================================
        % EPOCH LIST MODIFICATION METHODS
        % ================================================================

        function append(obj, epoch)
            % APPEND Add epoch to epoch list
            %
            % Usage:
            %   node.append(newEpoch)
            %
            % Equivalent to Java: EpochList.append()

            if iscell(epoch)
                obj.epochList = [obj.epochList; epoch(:)];
            else
                obj.epochList{end+1} = epoch;
            end

            % Update allEpochs if we're root
            if isempty(obj.parent)
                obj.allEpochs = obj.epochList;
            end
        end

        function insertEpoch(obj, epoch)
            % INSERTEPOCH Insert epoch into tree (rebuilds subtree)
            %
            % Usage:
            %   tree.insertEpoch(newEpoch)
            %
            % Equivalent to Java: EpochTree.insertEpoch()
            %
            % Note: This adds the epoch and rebuilds the tree using current splitKeyPaths.

            % Add to root's allEpochs
            root = obj.getRoot();
            root.allEpochs{end+1} = epoch;

            % Rebuild tree
            paths = obj.splitKeyPaths();
            if ~isempty(paths)
                root.buildTree(paths);
            end
        end

        function insertEpochs(obj, epochs)
            % INSERTEPOCHS Insert multiple epochs into tree
            %
            % Usage:
            %   tree.insertEpochs(newEpochs)
            %
            % Equivalent to Java: EpochTree.insertEpochs()

            root = obj.getRoot();

            if iscell(epochs)
                root.allEpochs = [root.allEpochs; epochs(:)];
            else
                % Struct array
                for i = 1:length(epochs)
                    root.allEpochs{end+1} = epochs(i);
                end
            end

            % Rebuild tree
            paths = obj.splitKeyPaths();
            if ~isempty(paths)
                root.buildTree(paths);
            end
        end

        function root = getRoot(obj)
            % GETROOT Get root node of tree
            %
            % Usage:
            %   root = node.getRoot()

            root = obj;
            while ~isempty(root.parent)
                root = root.parent;
            end
        end

        function epochs = getAllEpochs(obj, onlySelected)
            % GETALLEPOCHS Get all epochs under this node (recursive)
            %
            % Usage:
            %   epochs = tree.getAllEpochs()           % All epochs
            %   epochs = tree.getAllEpochs(true)       % Only selected epochs
            %
            % This is a CRITICAL function for analysis workflows.
            % When onlySelected=true, only returns epochs with isSelected=true.

            if nargin < 2
                onlySelected = false;
            end

            if obj.isLeaf
                if onlySelected
                    % Filter by isSelected flag
                    epochs = {};
                    for i = 1:length(obj.epochList)
                        ep = obj.epochList{i};
                        if isfield(ep, 'isSelected') && ep.isSelected
                            epochs{end+1} = ep;
                        elseif ~isfield(ep, 'isSelected')
                            % Include if isSelected field doesn't exist (backwards compat)
                            epochs{end+1} = ep;
                        end
                    end
                    epochs = epochs(:);
                else
                    epochs = obj.epochList;
                end
            else
                % Internal node - recurse to children
                epochs = {};
                for i = 1:length(obj.children)
                    childEpochs = obj.children{i}.getAllEpochs(onlySelected);
                    epochs = [epochs; childEpochs(:)];
                end
            end
        end

        function setSelected(obj, isSelected, recursive)
            % SETSELECTED Set selection state on this node and optionally children
            %
            % Usage:
            %   node.setSelected(true)           % Select this node only
            %   node.setSelected(true, true)     % Select this node and all descendants
            %
            % Also updates isSelected flag on epochs in leaf nodes.

            if nargin < 3
                recursive = false;
            end

            % Set node's custom.isSelected
            obj.custom.isSelected = isSelected;

            % If leaf, set isSelected on all epochs
            if obj.isLeaf
                for i = 1:length(obj.epochList)
                    obj.epochList{i}.isSelected = isSelected;
                end
            end

            % Recurse to children if requested
            if recursive && ~obj.isLeaf
                for i = 1:length(obj.children)
                    obj.children{i}.setSelected(isSelected, true);
                end
            end
        end

        function count = epochCount(obj)
            % EPOCHCOUNT Count total epochs under this node
            %
            % Usage:
            %   n = tree.epochCount()

            epochs = obj.getAllEpochs(false);
            count = length(epochs);
        end

        function count = selectedCount(obj)
            % SELECTEDCOUNT Count selected epochs under this node
            %
            % Usage:
            %   n = tree.selectedCount()

            epochs = obj.getAllEpochs(true);
            count = length(epochs);
        end

        function saveUserMetadata(obj, filepath)
            % SAVEUSERMETA Save selection state to .ugm file
            %
            % Usage:
            %   tree.saveUserMetadata('/path/to/file.ugm')
            %
            % Saves selection state to .ugm file with metadata.
            % Builds selection mask from epoch isSelected flags (one-time on save).

            % Get root node to access all epochs
            root = obj.getRoot();
            allEps = root.getAllEpochs(false);

            % Build mask from isSelected flags (ONE-TIME on save)
            mask = false(length(allEps), 1);
            for i = 1:length(allEps)
                if isfield(allEps{i}, 'isSelected') && allEps{i}.isSelected
                    mask(i) = true;
                end
            end

            % Extract basename for .ugm file metadata
            if ~isempty(root.sourceFile)
                [~, basename, ~] = fileparts(root.sourceFile);
            else
                [~, basename, ~] = fileparts(filepath);
            end

            % Build ugm struct
            ugm = struct();
            ugm.version = '1.0';
            ugm.created = datestr(now, 'yyyy-mm-dd HH:MM:SS');  % Use string instead of datetime object
            ugm.epoch_count = length(allEps);
            ugm.mat_file_basename = basename;
            ugm.selection_mask = mask;

            % Save to file
            save(filepath, 'ugm', '-v7.3');

            % Print command window message
            fprintf('Saved selection mask to: %s\n  %d of %d epochs selected (%.1f%%)\n', ...
                filepath, sum(mask), length(mask), 100*sum(mask)/length(mask));
        end

        function success = loadUserMetadata(obj, filepath)
            % LOADUSERMETADATA Load selection state from .ugm file
            %
            % Usage:
            %   success = tree.loadUserMetadata('/path/to/file.ugm')
            %
            % Returns:
            %   success - true if loaded successfully, false otherwise
            %
            % Loads selection state from .ugm file and applies to epochs.
            % Copies mask to isSelected flags (one-time on load).
            % Prints command window warning showing excluded epoch count.

            success = false;

            % Check file exists
            if ~exist(filepath, 'file')
                warning('epicTreeTools:FileNotFound', 'File not found: %s', filepath);
                return;
            end

            % Try loading (use -mat flag for .ugm extension compatibility)
            try
                loaded = load(filepath, '-mat');
            catch ME
                warning('epicTreeTools:LoadFailed', 'Failed to load %s: %s', filepath, ME.message);
                return;
            end

            % Validate struct
            if ~isfield(loaded, 'ugm')
                warning('epicTreeTools:InvalidFormat', 'File does not contain ugm struct: %s', filepath);
                return;
            end

            ugm = loaded.ugm;

            if ~isfield(ugm, 'selection_mask') || ~isfield(ugm, 'epoch_count')
                warning('epicTreeTools:InvalidFormat', 'ugm struct missing required fields');
                return;
            end

            % Get root node to access all epochs
            root = obj.getRoot();
            allEps = root.getAllEpochs(false);

            % Validate epoch count matches
            if ugm.epoch_count ~= length(allEps)
                warning('epicTreeTools:EpochCountMismatch', ...
                    'Epoch count mismatch: .ugm has %d, tree has %d', ...
                    ugm.epoch_count, length(allEps));
                return;
            end

            % Copy mask to isSelected flags (ONE-TIME on load)
            for i = 1:length(allEps)
                if i <= length(ugm.selection_mask)
                    allEps{i}.isSelected = ugm.selection_mask(i);
                else
                    allEps{i}.isSelected = true;  % Default for new epochs
                end
            end

            % Refresh node selection state cache
            root.refreshNodeSelectionState();

            % Print command window warning
            excluded = ugm.epoch_count - sum(ugm.selection_mask);
            fprintf('Selection mask loaded: %s\n  %d of %d epochs excluded (%.1f%%)\n', ...
                filepath, excluded, ugm.epoch_count, 100*excluded/ugm.epoch_count);

            success = true;
        end

        function refreshNodeSelectionState(obj)
            % REFRESHNODESELECTIONSTATE Sync node.custom.isSelected with epoch states
            %
            % Usage:
            %   tree.refreshNodeSelectionState()
            %
            % Walks tree and updates node.custom.isSelected based on actual
            % epoch isSelected flags. Call after loading .ugm files.

            if obj.isLeaf
                % Check if any epoch is selected
                anySelected = false;
                for i = 1:length(obj.epochList)
                    if isfield(obj.epochList{i}, 'isSelected') && obj.epochList{i}.isSelected
                        anySelected = true;
                        break;
                    end
                end
                obj.custom.isSelected = anySelected;
            else
                % Recurse to children
                anyChildSelected = false;
                for i = 1:length(obj.children)
                    obj.children{i}.refreshNodeSelectionState();
                    if obj.children{i}.custom.isSelected
                        anyChildSelected = true;
                    end
                end
                obj.custom.isSelected = anyChildSelected;
            end
        end
    end

    methods (Access = private)
        function buildTreeRecursive(obj, epochs, keyPaths)
            % Recursive tree building algorithm

            if isempty(keyPaths)
                % Base case: leaf node
                obj.epochList = epochs;
                obj.children = {};
                obj.isLeaf = true;
                return;
            end

            % Pop first key path
            keyPath = keyPaths{1};
            remainingPaths = keyPaths(2:end);

            % Group epochs by value at this key path
            groups = obj.groupByKeyPath(epochs, keyPath);

            % Sort groups by value
            groups = obj.sortGroups(groups);

            % Create child nodes
            obj.children = {};
            obj.epochList = {};
            obj.isLeaf = false;

            for i = 1:length(groups)
                group = groups{i};

                % Create child node
                child = epicTreeTools(obj);
                child.splitKey = keyPath;
                child.splitValue = group.value;

                % Recursively build subtree
                child.buildTreeRecursive(group.epochs, remainingPaths);

                obj.children{end+1} = child;
            end
        end

        function buildTreeWithSplittersRecursive(obj, epochs, splitters)
            % Recursive tree building with splitter functions

            if isempty(splitters)
                % Base case: leaf node
                obj.epochList = epochs;
                obj.children = {};
                obj.isLeaf = true;
                return;
            end

            % Pop first splitter
            splitter = splitters{1};
            remainingSplitters = splitters(2:end);

            % Determine splitter type and get split name
            if isa(splitter, 'function_handle')
                splitName = func2str(splitter);
                % Clean up function name for display
                splitName = regexprep(splitName, '^@?\(?([^)]+)\)?.*', '$1');
                splitName = regexprep(splitName, '.*\.', '');  % Remove class prefix
            else
                splitName = splitter;  % It's a key path string
            end

            % Group epochs by splitter value
            groups = obj.groupBySplitter(epochs, splitter);

            % Sort groups by value
            groups = obj.sortGroups(groups);

            % Create child nodes
            obj.children = {};
            obj.epochList = {};
            obj.isLeaf = false;

            for i = 1:length(groups)
                group = groups{i};

                % Create child node
                child = epicTreeTools(obj);
                child.splitKey = splitName;
                child.splitValue = group.value;

                % Recursively build subtree
                child.buildTreeWithSplittersRecursive(group.epochs, remainingSplitters);

                obj.children{end+1} = child;
            end
        end

        function groups = groupBySplitter(obj, epochs, splitter)
            % Group epochs by splitter value (function handle or key path)

            groups = {};
            valueToIdx = containers.Map();

            for i = 1:length(epochs)
                epoch = epochs{i};

                % Get value using splitter
                if isa(splitter, 'function_handle')
                    value = splitter(epoch);
                else
                    value = obj.getNestedValue(epoch, splitter);
                end

                valueKey = obj.valueToString(value);

                if valueToIdx.isKey(valueKey)
                    idx = valueToIdx(valueKey);
                    groups{idx}.epochs{end+1} = epoch;
                else
                    idx = length(groups) + 1;
                    groups{idx} = struct('value', value, 'epochs', {{epoch}});
                    valueToIdx(valueKey) = idx;
                end
            end
        end

        function groups = groupByKeyPath(obj, epochs, keyPath)
            % Group epochs by value at keyPath

            groups = {};
            valueToIdx = containers.Map();

            for i = 1:length(epochs)
                epoch = epochs{i};
                value = obj.getNestedValue(epoch, keyPath);
                valueKey = obj.valueToString(value);

                if valueToIdx.isKey(valueKey)
                    idx = valueToIdx(valueKey);
                    groups{idx}.epochs{end+1} = epoch;
                else
                    idx = length(groups) + 1;
                    groups{idx} = struct('value', value, 'epochs', {{epoch}});
                    valueToIdx(valueKey) = idx;
                end
            end
        end

        function groups = sortGroups(~, groups)
            % Sort groups by their value

            if isempty(groups)
                return;
            end

            n = length(groups);
            values = cell(n, 1);
            for i = 1:n
                values{i} = groups{i}.value;
            end

            % Check if all numeric
            allNumeric = true;
            numericVals = zeros(n, 1);
            for i = 1:n
                if isnumeric(values{i}) && isscalar(values{i})
                    numericVals(i) = values{i};
                else
                    allNumeric = false;
                    break;
                end
            end

            if allNumeric
                [~, sortIdx] = sort(numericVals);
            else
                strVals = cell(n, 1);
                for i = 1:n
                    if isempty(values{i})
                        strVals{i} = '';
                    elseif ischar(values{i})
                        strVals{i} = values{i};
                    elseif isnumeric(values{i})
                        strVals{i} = sprintf('%g', values{i});
                    else
                        strVals{i} = char(string(values{i}));
                    end
                end
                [~, sortIdx] = sort(strVals);
            end

            groups = groups(sortIdx);
        end

        function [sortIdx, sortedVals] = sortValues(~, values)
            % Sort values and return indices

            n = length(values);

            % Check if all numeric
            allNumeric = true;
            numericVals = zeros(n, 1);
            for i = 1:n
                if isnumeric(values{i}) && isscalar(values{i})
                    numericVals(i) = values{i};
                else
                    allNumeric = false;
                    break;
                end
            end

            if allNumeric
                [sortedVals, sortIdx] = sort(numericVals);
            else
                strVals = cell(n, 1);
                for i = 1:n
                    if isempty(values{i})
                        strVals{i} = char(intmax);
                    elseif ischar(values{i})
                        strVals{i} = values{i};
                    elseif isnumeric(values{i})
                        strVals{i} = sprintf('%020g', values{i});
                    else
                        strVals{i} = char(string(values{i}));
                    end
                end
                [sortedVals, sortIdx] = sort(strVals);
            end
        end

        function names = getStreamNames(obj, streamType)
            % Get unique stream names from epochs

            names = {};
            nameSet = containers.Map();

            epochs = obj.epochList;
            if isempty(epochs) && ~isempty(obj.allEpochs)
                epochs = obj.allEpochs;
            end

            for i = 1:length(epochs)
                epoch = epochs{i};
                if ~isfield(epoch, streamType)
                    continue;
                end

                streams = epoch.(streamType);
                if isstruct(streams)
                    for j = 1:length(streams)
                        if isfield(streams(j), 'device_name')
                            name = streams(j).device_name;
                            if ~isempty(name) && ~nameSet.isKey(name)
                                nameSet(name) = true;
                                names{end+1} = name;
                            end
                        end
                    end
                end
            end

            names = sort(names);
        end
    end

    methods (Static)
        function value = getNestedValue(obj, keyPath)
            % GETNESTEDVALUE Access nested struct fields via dot notation
            %
            % Usage:
            %   val = epicTreeTools.getNestedValue(epoch, 'protocolSettings.contrast')
            %
            % Supports both 'protocolSettings' and 'parameters' for compatibility

            value = [];

            if isempty(obj) || isempty(keyPath)
                return;
            end

            % Handle protocolSettings -> parameters alias
            keyPath = strrep(keyPath, 'protocolSettings', 'parameters');

            parts = strsplit(keyPath, '.');
            current = obj;

            for i = 1:length(parts)
                part = parts{i};
                if isempty(part)
                    continue;
                end

                if isstruct(current)
                    if isfield(current, part)
                        current = current.(part);
                    else
                        return;
                    end
                elseif iscell(current) && numel(current) == 1
                    current = current{1};
                    if isstruct(current) && isfield(current, part)
                        current = current.(part);
                    else
                        return;
                    end
                else
                    return;
                end
            end

            value = current;
        end

        function epochs = extractAllEpochs(treeData)
            % EXTRACTALLEPOCHS Flatten hierarchy to cell array of epochs
            %
            % Usage:
            %   epochs = epicTreeTools.extractAllEpochs(treeData)
            %
            % Handles both cell arrays and struct arrays in the hierarchy.

            epochs = {};

            if ~isfield(treeData, 'experiments')
                return;
            end

            experiments = treeData.experiments;
            for expIdx = 1:length(experiments)
                exp = epicTreeTools.getElement(experiments, expIdx);

                expInfo = struct();
                if isfield(exp, 'id'), expInfo.id = exp.id; end
                if isfield(exp, 'exp_name'), expInfo.exp_name = exp.exp_name; end
                if isfield(exp, 'is_mea'), expInfo.is_mea = exp.is_mea; end

                if ~isfield(exp, 'cells'), continue; end

                cells = exp.cells;
                for cellIdx = 1:length(cells)
                    cellData = epicTreeTools.getElement(cells, cellIdx);

                    cellInfo = struct();
                    if isfield(cellData, 'id'), cellInfo.id = cellData.id; end
                    if isfield(cellData, 'type'), cellInfo.type = cellData.type; else, cellInfo.type = ''; end
                    if isfield(cellData, 'label'), cellInfo.label = cellData.label; else, cellInfo.label = ''; end

                    if ~isfield(cellData, 'epoch_groups'), continue; end

                    epochGroups = cellData.epoch_groups;
                    for groupIdx = 1:length(epochGroups)
                        eg = epicTreeTools.getElement(epochGroups, groupIdx);

                        groupInfo = struct();
                        if isfield(eg, 'id'), groupInfo.id = eg.id; end
                        if isfield(eg, 'protocol_name'), groupInfo.protocol_name = eg.protocol_name; else, groupInfo.protocol_name = ''; end
                        if isfield(eg, 'label'), groupInfo.label = eg.label; else, groupInfo.label = ''; end

                        if ~isfield(eg, 'epoch_blocks'), continue; end

                        epochBlocks = eg.epoch_blocks;
                        for blockIdx = 1:length(epochBlocks)
                            eb = epicTreeTools.getElement(epochBlocks, blockIdx);

                            blockInfo = struct();
                            if isfield(eb, 'id'), blockInfo.id = eb.id; end
                            if isfield(eb, 'protocol_name'), blockInfo.protocol_name = eb.protocol_name; else, blockInfo.protocol_name = ''; end

                            if ~isfield(eb, 'epochs'), continue; end

                            epochList = eb.epochs;
                            for epochIdx = 1:length(epochList)
                                epoch = epicTreeTools.getElement(epochList, epochIdx);

                                % Attach parent references
                                epoch.cellInfo = cellInfo;
                                epoch.groupInfo = groupInfo;
                                epoch.blockInfo = blockInfo;
                                epoch.expInfo = expInfo;

                                % Alias parameters as protocolSettings for compatibility
                                if isfield(epoch, 'parameters') && ~isfield(epoch, 'protocolSettings')
                                    epoch.protocolSettings = epoch.parameters;
                                end

                                % Initialize selection state (CRITICAL for GUI)
                                epoch.isSelected = true;
                                epoch.includeInAnalysis = true;

                                epochs{end+1} = epoch;
                            end
                        end
                    end
                end
            end

            epochs = epochs(:);
        end

        function elem = getElement(arr, idx)
            % GETELEMENT Get element from cell array or struct array
            %
            % Handles both cell arrays and struct arrays uniformly.
            if iscell(arr)
                elem = arr{idx};
            else
                elem = arr(idx);
            end
        end

        function response = getResponseByName(epoch, deviceName)
            % GETRESPONSEBYNAME Get response struct by device name
            %
            % Usage:
            %   resp = epicTreeTools.getResponseByName(epoch, 'Amp1')

            response = [];
            if ~isfield(epoch, 'responses'), return; end

            for i = 1:length(epoch.responses)
                if strcmp(epoch.responses(i).device_name, deviceName)
                    response = epoch.responses(i);
                    return;
                end
            end
        end

        function stimulus = getStimulusByName(epoch, deviceName)
            % GETSTIMULUSBYNAME Get stimulus struct by device name
            %
            % Usage:
            %   stim = epicTreeTools.getStimulusByName(epoch, 'LED')

            stimulus = [];
            if ~isfield(epoch, 'stimuli'), return; end

            for i = 1:length(epoch.stimuli)
                if strcmp(epoch.stimuli(i).device_name, deviceName)
                    stimulus = epoch.stimuli(i);
                    return;
                end
            end
        end

        function [data, sampleRate, spikeTimes] = getResponseData(epoch, deviceName)
            % GETRESPONSEDATA Get response data, sample rate, spike times
            %
            % Usage:
            %   [data, fs, spikes] = epicTreeTools.getResponseData(epoch, 'Amp1')

            data = [];
            sampleRate = [];
            spikeTimes = [];

            resp = epicTreeTools.getResponseByName(epoch, deviceName);
            if isempty(resp), return; end

            if isfield(resp, 'data')
                data = resp.data(:)';  % Row vector
            end
            if isfield(resp, 'sample_rate')
                sampleRate = resp.sample_rate;
            end
            if isfield(resp, 'spike_times')
                spikeTimes = resp.spike_times(:)';  % Row vector
            end
        end

        function eq = valuesEqual(a, b)
            % Compare two values for equality

            if isempty(a) && isempty(b)
                eq = true;
            elseif isempty(a) || isempty(b)
                eq = false;
            elseif isequal(a, b)
                eq = true;
            elseif isnumeric(a) && isnumeric(b) && isscalar(a) && isscalar(b)
                eq = abs(a - b) < 1e-10;
            elseif (ischar(a) || isstring(a)) && (ischar(b) || isstring(b))
                eq = strcmp(char(a), char(b));
            else
                eq = isequal(a, b);
            end
        end

        function str = valueToString(value)
            % Convert value to string for grouping

            if isempty(value)
                str = '__empty__';
            elseif ischar(value)
                str = value;
            elseif isstring(value)
                str = char(value);
            elseif isnumeric(value) && isscalar(value)
                str = sprintf('%.10g', value);
            elseif islogical(value)
                if value, str = 'true'; else, str = 'false'; end
            else
                str = '__other__';
            end
        end

        %% ================================================================
        % PHASE 3: SPLITTER FUNCTIONS
        % These static methods return a split value from an epoch.
        % Use with buildTreeWithSplitters() or as custom key paths.
        % ================================================================

        function V = splitOnExperimentDate(epoch)
            % SPLITONEXPERIMENTDATE Split by experiment date
            %
            % Usage:
            %   value = epicTreeTools.splitOnExperimentDate(epoch)
            %
            % Returns the experiment name/date string.
            % Compatible with DATA_FORMAT_SPECIFICATION: uses expInfo.exp_name

            V = '';
            if isfield(epoch, 'expInfo') && isfield(epoch.expInfo, 'exp_name')
                V = epoch.expInfo.exp_name;
            elseif isfield(epoch, 'expInfo') && isfield(epoch.expInfo, 'start_time')
                V = datestr(epoch.expInfo.start_time);
            end
        end

        function V = splitOnCellType(epoch)
            % SPLITONCELLTYPE Split by cell type
            %
            % Usage:
            %   value = epicTreeTools.splitOnCellType(epoch)
            %
            % Returns the cell type (OnP, OffP, OnM, etc.)
            % Also checks keywords for legacy Symphony 1 compatibility.

            V = 'Unknown';

            % Try cellInfo.type first (DATA_FORMAT_SPECIFICATION)
            if isfield(epoch, 'cellInfo') && isfield(epoch.cellInfo, 'type')
                cellType = epoch.cellInfo.type;
                if ~isempty(cellType) && ~strcmp(cellType, 'unknown')
                    V = cellType;
                    return;
                end
            end

            % Try parameters source:type (Symphony 2)
            params = epicTreeTools.getParams(epoch);
            if isfield(params, 'source_type')
                V = params.source_type;
                if ~isempty(V) && ~strcmp(V, 'unknown')
                    return;
                end
            end

            % Fall back to keywords (Symphony 1)
            V = epicTreeTools.checkCellTypeKeywords(epoch);
        end

        function V = splitOnKeywords(epoch)
            % SPLITONKEYWORDS Split by epoch keywords
            %
            % Usage:
            %   value = epicTreeTools.splitOnKeywords(epoch)
            %
            % Returns concatenated keywords string.

            V = '';
            if isfield(epoch, 'keywords')
                kw = epoch.keywords;
                if iscell(kw)
                    V = strjoin(kw, ', ');
                elseif ischar(kw)
                    V = kw;
                end
            end
        end

        function V = splitOnKeywordsExcluding(epoch, excludeList)
            % SPLITONKEYWORDSEXCLUDING Split by keywords, excluding some
            %
            % Usage:
            %   value = epicTreeTools.splitOnKeywordsExcluding(epoch, {'example'})
            %
            % Returns concatenated keywords excluding specified ones.

            V = '';
            if ~isfield(epoch, 'keywords')
                return;
            end

            kw = epoch.keywords;
            if iscell(kw)
                % Filter out excluded keywords
                keep = true(size(kw));
                for i = 1:length(kw)
                    for j = 1:length(excludeList)
                        if strcmp(kw{i}, excludeList{j})
                            keep(i) = false;
                            break;
                        end
                    end
                end
                V = strjoin(kw(keep), ', ');
            elseif ischar(kw)
                V = kw;
            end
        end

        function V = splitOnF1F2Contrast(epoch)
            % SPLITONF1F2CONTRAST Split for F1/F2 contrast analysis
            %
            % Usage:
            %   value = epicTreeTools.splitOnF1F2Contrast(epoch)
            %
            % Handles ContrastF1F2 and SplitFieldCentering protocols.
            % Returns currentContrast or contrast value.

            V = [];
            params = epicTreeTools.getParams(epoch);

            if isfield(params, 'currentContrast')
                V = params.currentContrast;
            elseif isfield(params, 'contrast')
                V = params.contrast;
            end
        end

        function V = splitOnF1F2CenterSize(epoch)
            % SPLITONF1F2CENTERSIZE Split for F1/F2 center size analysis
            %
            % Usage:
            %   value = epicTreeTools.splitOnF1F2CenterSize(epoch)
            %
            % Returns spotDiameter or apertureDiameter.

            V = [];
            params = epicTreeTools.getParams(epoch);

            if isfield(params, 'spotDiameter')
                V = params.spotDiameter;
            elseif isfield(params, 'apertureDiameter')
                V = params.apertureDiameter;
            end
        end

        function V = splitOnF1F2Phase(epoch)
            % SPLITONF1F2PHASE Split for F1/F2 phase analysis
            %
            % Usage:
            %   value = epicTreeTools.splitOnF1F2Phase(epoch)
            %
            % Returns 'F1' or 'F2' based on splitField or currentPhase.

            V = '';
            params = epicTreeTools.getParams(epoch);

            if isfield(params, 'splitField')
                if params.splitField
                    V = 'F2';
                else
                    V = 'F1';
                end
            elseif isfield(params, 'currentPhase')
                if params.currentPhase == 0
                    V = 'F1';
                elseif params.currentPhase == 90
                    V = 'F2';
                end
            end
        end

        function V = splitOnRadiusOrDiameter(epoch, paramString)
            % SPLITONRADIUSORDIAMETER Split by radius or diameter
            %
            % Usage:
            %   value = epicTreeTools.splitOnRadiusOrDiameter(epoch, 'aperture')
            %   value = epicTreeTools.splitOnRadiusOrDiameter(epoch, 'mask')
            %
            % Handles Symphony 1->2 transition (radius to diameter).

            V = [];
            params = epicTreeTools.getParams(epoch);

            radiusField = [paramString, 'Radius'];
            diamField = [paramString, 'Diameter'];

            if isfield(params, radiusField)
                V = 2 * params.(radiusField);  % Convert radius to diameter
            elseif isfield(params, diamField)
                V = params.(diamField);
            end
        end

        function V = splitOnHoldingSignal(epoch)
            % SPLITONHOLDINGSIGNAL Split by holding/offset signal
            %
            % Usage:
            %   value = epicTreeTools.splitOnHoldingSignal(epoch)
            %
            % Returns Amp1 offset (Symphony 2) or Amplifier_Ch1 background.

            V = [];
            params = epicTreeTools.getParams(epoch);

            % Symphony 2 format (colon replaced with underscore in MATLAB)
            if isfield(params, 'stimuli_Amp1_offset')
                V = params.stimuli_Amp1_offset;
            elseif isfield(params, 'background_Amplifier_Ch1')
                V = params.background_Amplifier_Ch1;
            % Alternative field names
            elseif isfield(params, 'holdingSignal')
                V = params.holdingSignal;
            elseif isfield(params, 'amp1Offset')
                V = params.amp1Offset;
            end
        end

        function V = splitOnOLEDLevel(epoch)
            % SPLITONOLEDLEVEL Split by OLED brightness level
            %
            % Usage:
            %   value = epicTreeTools.splitOnOLEDLevel(epoch)
            %
            % Returns brightness level (maximum/high/medium/low/minimum).

            V = 'Not OLED';
            params = epicTreeTools.getParams(epoch);

            % Symphony 2 format
            if isfield(params, 'background_Microdisplay_Stage_localhost_microdisplayBrightness')
                V = params.background_Microdisplay_Stage_localhost_microdisplayBrightness;
            elseif isfield(params, 'microdisplayBrightness')
                V = params.microdisplayBrightness;
            elseif isfield(params, 'oledBrightness')
                % Symphony 1: convert numeric to label
                brightness = params.oledBrightness;
                switch brightness
                    case 23
                        V = 'maximum';
                    case 25
                        V = 'high';
                    case 73
                        V = 'medium';
                    case 120
                        V = 'low';
                    case 229
                        V = 'minimum';
                    otherwise
                        V = sprintf('%g', brightness);
                end
            end
        end

        function V = splitOnRecKeyword(epoch)
            % SPLITONRECKEYWORD Split by recording type keyword
            %
            % Usage:
            %   value = epicTreeTools.splitOnRecKeyword(epoch)
            %
            % Returns recording type (exc/inh/extracellular/gClamp/iClamp).

            V = 'noRecordingTag';
            keywords = epicTreeTools.getKeywordsString(epoch);

            if contains(keywords, 'exc')
                V = 'exc';
            elseif contains(keywords, 'inh')
                V = 'inh';
            elseif contains(keywords, 'extracellular')
                V = 'extracellular';
            elseif contains(keywords, 'gClamp')
                V = 'gClamp';
            elseif contains(keywords, 'iClamp')
                V = 'iClamp';
            end
        end

        function V = splitOnLogIRtag(epoch)
            % SPLITONLOGIRTAG Split by log IR tag in keywords
            %
            % Usage:
            %   value = epicTreeTools.splitOnLogIRtag(epoch)
            %
            % Returns IR level tag (12.0, 13.6, etc.).

            V = 'noIRTag';
            keywords = epicTreeTools.getKeywordsString(epoch);

            if contains(keywords, '12.0')
                V = '12.0';
            elseif contains(keywords, '13.6')
                V = '13.6';
            end
        end

        function V = splitOnPatchContrast_NatImage(epoch)
            % SPLITONPATCHCONTRAST_NATIMAGE Split for natural image patch contrast
            %
            % Usage:
            %   value = epicTreeTools.splitOnPatchContrast_NatImage(epoch)
            %
            % Returns patchContrast value or 'all' for random patches.

            V = 'all';
            params = epicTreeTools.getParams(epoch);

            if isfield(params, 'patchContrast')
                V = params.patchContrast;
            end
        end

        function V = splitOnPatchSampling_NatImage(epoch)
            % SPLITONPATCHSAMPLING_NATIMAGE Split for natural image patch sampling
            %
            % Usage:
            %   value = epicTreeTools.splitOnPatchSampling_NatImage(epoch)
            %
            % Returns patchSampling value or 'random' for first version.

            V = 'random';
            params = epicTreeTools.getParams(epoch);

            if isfield(params, 'patchSampling')
                V = params.patchSampling;
            end
        end

        function V = splitOnEpochBlockStart(epoch)
            % SPLITONEPOCHBLOCKSTART Split by epoch block start time
            %
            % Usage:
            %   value = epicTreeTools.splitOnEpochBlockStart(epoch)
            %
            % Returns block start time string.

            V = '';
            if isfield(epoch, 'blockInfo') && isfield(epoch.blockInfo, 'start_time')
                V = datestr(epoch.blockInfo.start_time);
            end
        end

        function V = splitOnBarWidth(epoch)
            % SPLITONBARWIDTH Split by bar width parameter
            %
            % Usage:
            %   value = epicTreeTools.splitOnBarWidth(epoch)

            V = [];
            params = epicTreeTools.getParams(epoch);

            if isfield(params, 'currentBarWidth')
                V = abs(params.currentBarWidth);
            elseif isfield(params, 'barWidth')
                V = abs(params.barWidth);
            end
        end

        function V = splitOnFlashDelay(epoch)
            % SPLITONFLASHDELAY Split by flash delay time
            %
            % Usage:
            %   value = epicTreeTools.splitOnFlashDelay(epoch)

            V = [];
            params = epicTreeTools.getParams(epoch);

            if isfield(params, 'currentFlashDelay')
                V = params.currentFlashDelay;
            elseif isfield(params, 'flashDelay')
                V = params.flashDelay;
            end
        end

        function V = splitOnStimulusCenter(epoch)
            % SPLITONSTIMULUSENTER Split by stimulus center offset
            %
            % Usage:
            %   value = epicTreeTools.splitOnStimulusCenter(epoch)
            %
            % Returns X coordinate of center offset.

            V = [];
            params = epicTreeTools.getParams(epoch);

            % Check various possible field names
            possibleFields = {
                'background_Microdisplay_Stage_localhost_centerOffset'
                'background_LightCrafter_Stage_localhost_centerOffset'
                'centerOffset'
                'stimulusCenter'
            };

            for i = 1:length(possibleFields)
                if isfield(params, possibleFields{i})
                    offset = params.(possibleFields{i});
                    if isnumeric(offset) && ~isempty(offset)
                        V = offset(1);  % X coordinate
                    end
                    break;
                end
            end
        end

        function V = splitOnTemporalFrequency(epoch)
            % SPLITONTEMPORALFREQUENCY Split by temporal frequency
            %
            % Usage:
            %   value = epicTreeTools.splitOnTemporalFrequency(epoch)

            V = [];
            params = epicTreeTools.getParams(epoch);

            if isfield(params, 'temporal_frequency')
                V = params.temporal_frequency;
            elseif isfield(params, 'temporalFrequency')
                V = params.temporalFrequency;
            end
        end

        function V = splitOnSpatialFrequency(epoch)
            % SPLITONSPATIALFREQUENCY Split by spatial frequency
            %
            % Usage:
            %   value = epicTreeTools.splitOnSpatialFrequency(epoch)

            V = [];
            params = epicTreeTools.getParams(epoch);

            if isfield(params, 'spatial_frequency')
                V = params.spatial_frequency;
            elseif isfield(params, 'spatialFrequency')
                V = params.spatialFrequency;
            end
        end

        function V = splitOnContrast(epoch)
            % SPLITONCONTRAST Split by contrast parameter
            %
            % Usage:
            %   value = epicTreeTools.splitOnContrast(epoch)

            V = [];
            params = epicTreeTools.getParams(epoch);

            if isfield(params, 'contrast')
                V = params.contrast;
            elseif isfield(params, 'currentContrast')
                V = params.currentContrast;
            end
        end

        function V = splitOnProtocol(epoch)
            % SPLITONPROTOCOL Split by protocol name
            %
            % Usage:
            %   value = epicTreeTools.splitOnProtocol(epoch)

            V = '';
            if isfield(epoch, 'blockInfo') && isfield(epoch.blockInfo, 'protocol_name')
                V = epoch.blockInfo.protocol_name;
            elseif isfield(epoch, 'groupInfo') && isfield(epoch.groupInfo, 'protocol_name')
                V = epoch.groupInfo.protocol_name;
            end
        end

        %% ================================================================
        % HELPER METHODS FOR SPLITTERS
        % ================================================================

        function params = getParams(epoch)
            % GETPARAMS Get parameters struct from epoch
            %
            % Handles both 'parameters' and 'protocolSettings' field names.

            params = struct();
            if isfield(epoch, 'parameters')
                params = epoch.parameters;
            elseif isfield(epoch, 'protocolSettings')
                params = epoch.protocolSettings;
            end
        end

        function kw = getKeywordsString(epoch)
            % GETKEYWORDSSTRING Get keywords as a single string
            %
            % Returns lowercase concatenated keywords for pattern matching.

            kw = '';
            if isfield(epoch, 'keywords')
                keywords = epoch.keywords;
                if iscell(keywords)
                    kw = lower(strjoin(keywords, ' '));
                elseif ischar(keywords)
                    kw = lower(keywords);
                end
            end
        end

        function cellType = checkCellTypeKeywords(epoch)
            % CHECKCELLTYPEKEYWORDS Determine cell type from keywords
            %
            % Legacy Symphony 1 compatibility: cell type stored as keyword.

            cellType = 'noCellTypeTag';
            keywords = epicTreeTools.getKeywordsString(epoch);

            if contains(keywords, 'onparasol')
                cellType = 'RGC\ON-parasol';
            elseif contains(keywords, 'offparasol')
                cellType = 'RGC\OFF-parasol';
            elseif contains(keywords, 'onmidget')
                cellType = 'RGC\ON-midget';
            elseif contains(keywords, 'offmidget')
                cellType = 'RGC\OFF-midget';
            elseif contains(keywords, 'horizontal')
                cellType = 'horizontal';
            elseif contains(keywords, 'onp')
                cellType = 'OnP';
            elseif contains(keywords, 'offp')
                cellType = 'OffP';
            elseif contains(keywords, 'onm')
                cellType = 'OnM';
            elseif contains(keywords, 'offm')
                cellType = 'OffM';
            end
        end

        function filepath = findLatestUGM(matFilePath)
            % FINDLATESTUGM Find most recent .ugm file for a .mat file
            %
            % Usage:
            %   ugmPath = epicTreeTools.findLatestUGM('/path/to/data.mat')
            %
            % Returns:
            %   filepath - Path to most recent .ugm file, or '' if none found
            %
            % Searches for .ugm files with pattern: basename_*.ugm
            % Sorts by filename (ISO 8601 timestamps sort lexicographically)

            filepath = '';

            if isempty(matFilePath)
                return;
            end

            % Extract directory and basename
            [directory, basename, ~] = fileparts(matFilePath);

            % Find matching .ugm files
            pattern = fullfile(directory, [basename '_*.ugm']);
            files = dir(pattern);

            if isempty(files)
                return;
            end

            % Sort descending (most recent first)
            % Use cell array sort with proper syntax
            names = {files.name};
            [~, idx] = sort(names);
            idx = flip(idx);  % Reverse to get descending order

            % Return most recent
            filepath = fullfile(directory, files(idx(1)).name);
        end

        function filepath = generateUGMFilename(matFilePath)
            % GENERATEUGMFILENAME Generate timestamped .ugm filename
            %
            % Usage:
            %   ugmPath = epicTreeTools.generateUGMFilename('/path/to/data.mat')
            %
            % Returns:
            %   filepath - Generated .ugm filepath with timestamp
            %
            % Format: basename_YYYY-MM-DD_HH-mm-ss.ugm

            if isempty(matFilePath)
                error('epicTreeTools:EmptyPath', 'matFilePath cannot be empty');
            end

            % Extract directory and basename
            [directory, basename, ~] = fileparts(matFilePath);

            % Generate timestamp
            timestamp = string(datetime('now'), 'uuuu-MM-dd_HH-mm-ss');

            % Build filepath
            filepath = fullfile(directory, sprintf('%s_%s.ugm', basename, timestamp));
        end
    end
end
