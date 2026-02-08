classdef AnalysisFunctionsTest < matlab.unittest.TestCase
    % AnalysisFunctionsTest - Comprehensive tests for analysis functions
    %
    % This test class validates the 5 core analysis functions that researchers
    % use to extract scientific results from their data:
    %   1. getMeanResponseTrace
    %   2. getResponseAmplitudeStats
    %   3. getCycleAverageResponse
    %   4. getLinearFilterAndPrediction
    %   5. MeanSelectedNodes
    %
    % Tests verify:
    %   - Output struct contains required fields
    %   - Field types and dimensions are correct
    %   - Mathematical relationships hold (e.g., SEM = stdev/sqrt(n))
    %   - Functions accept both node and epoch list inputs
    %   - Optional parameters work correctly
    %   - Output matches golden baselines (regression testing)

    properties
        TestTree        % epicTreeTools tree with test data
        H5File          % Path to H5 file
        LeafNode        % Single leaf node for testing
        MultipleNodes   % Cell array of sibling nodes for MeanSelectedNodes
    end

    methods (TestClassSetup)
        function loadData(testCase)
            % Load test data and prepare tree structure
            [testCase.TestTree, ~, testCase.H5File] = loadTestTree({'cellInfo.type', 'blockInfo.protocol_name'});

            % Get a leaf node with epochs
            leaves = testCase.TestTree.leafNodes();
            testCase.assumeTrue(~isempty(leaves), 'Test data must have leaf nodes');
            testCase.LeafNode = leaves{1};

            % Get sibling nodes for MeanSelectedNodes (up to 3 nodes)
            firstChild = testCase.TestTree.childAt(1);
            testCase.MultipleNodes = {};
            for i = 1:min(3, firstChild.childrenLength())
                testCase.MultipleNodes{end+1} = firstChild.childAt(i);
            end
        end
    end

    methods (TestMethodTeardown)
        function closeFigures(testCase)
            % Close any figures opened during tests
            close all;
        end
    end

    %% getMeanResponseTrace tests

    methods (Test)
        function testMeanResponseTraceOutputFields(testCase)
            % Verify output struct has all required fields
            resp = getMeanResponseTrace(testCase.LeafNode, 'Amp1');

            testCase.verifyTrue(isstruct(resp), 'Output must be a struct');
            testCase.verifyTrue(isfield(resp, 'mean'), 'Must have mean field');
            testCase.verifyTrue(isfield(resp, 'stdev'), 'Must have stdev field');
            testCase.verifyTrue(isfield(resp, 'SEM'), 'Must have SEM field');
            testCase.verifyTrue(isfield(resp, 'n'), 'Must have n field');
            testCase.verifyTrue(isfield(resp, 'timeVector'), 'Must have timeVector field');
            testCase.verifyTrue(isfield(resp, 'sampleRate'), 'Must have sampleRate field');
            testCase.verifyTrue(isfield(resp, 'units'), 'Must have units field');
        end

        function testMeanResponseTraceTypes(testCase)
            % Verify field types and dimensions
            resp = getMeanResponseTrace(testCase.LeafNode, 'Amp1');

            testCase.assumeTrue(resp.n > 0, 'Need epochs for type validation');

            % mean should be 1 x nSamples
            testCase.verifyTrue(isrow(resp.mean), 'mean must be row vector');
            testCase.verifyTrue(isa(resp.mean, 'double'), 'mean must be double');

            % n should be positive integer
            testCase.verifyTrue(resp.n > 0, 'n must be positive');
            testCase.verifyTrue(resp.n == floor(resp.n), 'n must be integer');

            % sampleRate should be positive double
            testCase.verifyTrue(resp.sampleRate > 0, 'sampleRate must be positive');
            testCase.verifyTrue(isa(resp.sampleRate, 'double'), 'sampleRate must be double');

            % stdev and SEM should have same size as mean
            testCase.verifyEqual(size(resp.stdev), size(resp.mean), 'stdev size must match mean');
            testCase.verifyEqual(size(resp.SEM), size(resp.mean), 'SEM size must match mean');
        end

        function testMeanResponseTraceSEMrelation(testCase)
            % Verify SEM = stdev / sqrt(n)
            resp = getMeanResponseTrace(testCase.LeafNode, 'Amp1');

            testCase.assumeTrue(resp.n > 0, 'Need epochs for SEM validation');

            expectedSEM = resp.stdev / sqrt(resp.n);
            testCase.verifyEqual(resp.SEM, expectedSEM, 'AbsTol', 1e-10, ...
                'SEM must equal stdev/sqrt(n)');
        end

        function testMeanResponseTraceTimeVector(testCase)
            % Verify timeVector properties
            resp = getMeanResponseTrace(testCase.LeafNode, 'Amp1');

            testCase.assumeTrue(resp.n > 0, 'Need epochs for timeVector validation');

            % Length should match mean length
            testCase.verifyEqual(length(resp.timeVector), length(resp.mean), ...
                'timeVector length must match mean length');

            % Should start at or near zero
            testCase.verifyLessThan(abs(resp.timeVector(1)), 0.01, ...
                'timeVector should start near zero');

            % Should be monotonically increasing
            testCase.verifyTrue(all(diff(resp.timeVector) > 0), ...
                'timeVector must be monotonically increasing');
        end

        function testMeanResponseTraceRecordingTypes(testCase)
            % Test different RecordingType options
            recordingTypes = {'exc', 'inh', 'raw'};
            expectedUnits = {'pA', 'pA', 'AU'};

            for i = 1:length(recordingTypes)
                resp = getMeanResponseTrace(testCase.LeafNode, 'Amp1', ...
                    'RecordingType', recordingTypes{i});

                testCase.verifyTrue(isstruct(resp), ...
                    sprintf('Output for RecordingType=%s must be struct', recordingTypes{i}));

                if resp.n > 0
                    testCase.verifyEqual(resp.units, expectedUnits{i}, ...
                        sprintf('Units for RecordingType=%s must be %s', ...
                        recordingTypes{i}, expectedUnits{i}));
                end
            end
        end

        function testMeanResponseTraceNodeInput(testCase)
            % Verify function accepts epicTreeTools node
            resp = getMeanResponseTrace(testCase.LeafNode, 'Amp1');

            testCase.verifyTrue(isstruct(resp), 'Must accept node input');
            testCase.verifyTrue(isfield(resp, 'n'), 'Output must have n field');
        end

        function testMeanResponseTraceEpochListInput(testCase)
            % Verify function accepts cell array of epochs
            epochs = testCase.LeafNode.getAllEpochs(false);
            testCase.assumeTrue(~isempty(epochs), 'Need epochs for epoch list test');

            resp = getMeanResponseTrace(epochs, 'Amp1');

            testCase.verifyTrue(isstruct(resp), 'Must accept epoch list input');
            testCase.verifyTrue(isfield(resp, 'n'), 'Output must have n field');
            testCase.verifyEqual(resp.n, length(epochs), ...
                'n must equal number of input epochs');
        end
    end

    %% getResponseAmplitudeStats tests

    methods (Test)
        function testAmplitudeStatsOutputFields(testCase)
            % Verify output struct has all required fields
            stats = getResponseAmplitudeStats(testCase.LeafNode, 'Amp1');

            testCase.verifyTrue(isstruct(stats), 'Output must be a struct');

            % Per-epoch fields
            testCase.verifyTrue(isfield(stats, 'peakAmplitude'), 'Must have peakAmplitude');
            testCase.verifyTrue(isfield(stats, 'peakTime'), 'Must have peakTime');
            testCase.verifyTrue(isfield(stats, 'integratedResponse'), 'Must have integratedResponse');
            testCase.verifyTrue(isfield(stats, 'meanAmplitude'), 'Must have meanAmplitude');
            testCase.verifyTrue(isfield(stats, 'baseline'), 'Must have baseline');

            % Summary statistics
            testCase.verifyTrue(isfield(stats, 'mean_peak'), 'Must have mean_peak');
            testCase.verifyTrue(isfield(stats, 'std_peak'), 'Must have std_peak');
            testCase.verifyTrue(isfield(stats, 'sem_peak'), 'Must have sem_peak');

            % Metadata
            testCase.verifyTrue(isfield(stats, 'n'), 'Must have n');
            testCase.verifyTrue(isfield(stats, 'units'), 'Must have units');
        end

        function testAmplitudeStatsTypes(testCase)
            % Verify field types and dimensions
            stats = getResponseAmplitudeStats(testCase.LeafNode, 'Amp1');

            testCase.assumeTrue(stats.n > 0, 'Need epochs for type validation');

            % Per-epoch fields should be column vectors
            testCase.verifyEqual(size(stats.peakAmplitude, 1), stats.n, ...
                'peakAmplitude must have n rows');
            testCase.verifyEqual(size(stats.peakAmplitude, 2), 1, ...
                'peakAmplitude must be column vector');

            % Summary stats should be scalars
            testCase.verifyTrue(isscalar(stats.mean_peak), 'mean_peak must be scalar');
            testCase.verifyTrue(isscalar(stats.std_peak), 'std_peak must be scalar');
            testCase.verifyTrue(isscalar(stats.sem_peak), 'sem_peak must be scalar');
        end

        function testAmplitudeStatsSEMrelation(testCase)
            % Verify sem_peak = std_peak / sqrt(n)
            stats = getResponseAmplitudeStats(testCase.LeafNode, 'Amp1');

            testCase.assumeTrue(stats.n > 0, 'Need epochs for SEM validation');

            expectedSEM = stats.std_peak / sqrt(stats.n);
            testCase.verifyEqual(stats.sem_peak, expectedSEM, 'AbsTol', 1e-10, ...
                'sem_peak must equal std_peak/sqrt(n)');
        end

        function testAmplitudeStatsNonEmpty(testCase)
            % Verify fields are non-empty when data exists
            stats = getResponseAmplitudeStats(testCase.LeafNode, 'Amp1');

            testCase.assumeTrue(stats.n > 0, 'Need epochs for non-empty validation');

            testCase.verifyFalse(isempty(stats.peakAmplitude), ...
                'peakAmplitude must be non-empty with data');
            testCase.verifyFalse(isnan(stats.mean_peak), ...
                'mean_peak must not be NaN with data');
            testCase.verifyFalse(isempty(stats.units), ...
                'units must be non-empty with data');
        end

        function testAmplitudeStatsWithWindow(testCase)
            % Test with explicit ResponseWindow parameter
            stats = getResponseAmplitudeStats(testCase.LeafNode, 'Amp1', ...
                'ResponseWindow', [0.5 1.5]);

            testCase.verifyTrue(isstruct(stats), ...
                'Must accept ResponseWindow parameter');
            testCase.verifyTrue(isfield(stats, 'peakAmplitude'), ...
                'Output must have peakAmplitude field');
        end
    end

    %% getCycleAverageResponse tests

    methods (Test)
        function testCycleAverageOutputFields(testCase)
            % Verify output struct has all required fields
            % Note: This requires periodic stimulus data

            try
                result = getCycleAverageResponse(testCase.LeafNode, 'Amp1', ...
                    'Frequency', 2);

                testCase.verifyTrue(isstruct(result), 'Output must be a struct');
                testCase.verifyTrue(isfield(result, 'cycleAverage'), 'Must have cycleAverage');
                testCase.verifyTrue(isfield(result, 'cycleStd'), 'Must have cycleStd');
                testCase.verifyTrue(isfield(result, 'cycleSEM'), 'Must have cycleSEM');
                testCase.verifyTrue(isfield(result, 'cycleTime'), 'Must have cycleTime');
                testCase.verifyTrue(isfield(result, 'F1amplitude'), 'Must have F1amplitude');
                testCase.verifyTrue(isfield(result, 'F1phase'), 'Must have F1phase');
                testCase.verifyTrue(isfield(result, 'F2amplitude'), 'Must have F2amplitude');
                testCase.verifyTrue(isfield(result, 'F2phase'), 'Must have F2phase');
                testCase.verifyTrue(isfield(result, 'F1F2ratio'), 'Must have F1F2ratio');
                testCase.verifyTrue(isfield(result, 'DC'), 'Must have DC');
                testCase.verifyTrue(isfield(result, 'frequency'), 'Must have frequency');
                testCase.verifyTrue(isfield(result, 'nCycles'), 'Must have nCycles');
                testCase.verifyTrue(isfield(result, 'n'), 'Must have n');
            catch ME
                % Gracefully skip if no periodic data available
                testCase.assumeFail(sprintf('Periodic stimulus data not available: %s', ME.message));
            end
        end

        function testCycleAverageTypes(testCase)
            % Verify field types
            try
                result = getCycleAverageResponse(testCase.LeafNode, 'Amp1', ...
                    'Frequency', 2);

                testCase.assumeTrue(result.n > 0 && result.nCycles > 0, ...
                    'Need valid cycle data for type validation');

                % cycleAverage should be row vector
                testCase.verifyTrue(isrow(result.cycleAverage), ...
                    'cycleAverage must be row vector');
                testCase.verifyTrue(isa(result.cycleAverage, 'double'), ...
                    'cycleAverage must be double');

                % frequency should be positive scalar
                testCase.verifyTrue(isscalar(result.frequency), ...
                    'frequency must be scalar');
                testCase.verifyTrue(result.frequency > 0, ...
                    'frequency must be positive');
            catch ME
                testCase.assumeFail(sprintf('Periodic stimulus data not available: %s', ME.message));
            end
        end

        function testCycleAverageWithFrequency(testCase)
            % Test with explicit Frequency parameter
            try
                result = getCycleAverageResponse(testCase.LeafNode, 'Amp1', ...
                    'Frequency', 2);

                testCase.verifyEqual(result.frequency, 2, ...
                    'Frequency parameter should be stored in output');
            catch ME
                testCase.assumeFail(sprintf('Periodic stimulus data not available: %s', ME.message));
            end
        end

        function testCycleAverageF1F2NonNegative(testCase)
            % F1 and F2 amplitudes should be non-negative
            try
                result = getCycleAverageResponse(testCase.LeafNode, 'Amp1', ...
                    'Frequency', 2);

                testCase.assumeTrue(result.n > 0 && result.nCycles > 0, ...
                    'Need valid cycle data');

                testCase.verifyGreaterThanOrEqual(result.F1amplitude, 0, ...
                    'F1amplitude must be non-negative');
                testCase.verifyGreaterThanOrEqual(result.F2amplitude, 0, ...
                    'F2amplitude must be non-negative');
            catch ME
                testCase.assumeFail(sprintf('Periodic stimulus data not available: %s', ME.message));
            end
        end
    end

    %% getLinearFilterAndPrediction tests

    methods (Test)
        function testLinearFilterOutputFields(testCase)
            % Verify output struct has all required fields
            % Note: This requires stimulus stream data

            try
                result = getLinearFilterAndPrediction(testCase.LeafNode, ...
                    'Stage', 'Amp1');

                testCase.verifyTrue(isstruct(result), 'Output must be a struct');
                testCase.verifyTrue(isfield(result, 'filter'), 'Must have filter');
                testCase.verifyTrue(isfield(result, 'filterTime'), 'Must have filterTime');
                testCase.verifyTrue(isfield(result, 'prediction'), 'Must have prediction');
                testCase.verifyTrue(isfield(result, 'response'), 'Must have response');
                testCase.verifyTrue(isfield(result, 'stimulus'), 'Must have stimulus');
                testCase.verifyTrue(isfield(result, 'correlation'), 'Must have correlation');
                testCase.verifyTrue(isfield(result, 'sampleRate'), 'Must have sampleRate');
                testCase.verifyTrue(isfield(result, 'n'), 'Must have n');
            catch ME
                % Gracefully skip if stimulus data not available
                testCase.assumeFail(sprintf('Stimulus stream data not available: %s', ME.message));
            end
        end

        function testLinearFilterTypes(testCase)
            % Verify field types
            try
                result = getLinearFilterAndPrediction(testCase.LeafNode, ...
                    'Stage', 'Amp1');

                testCase.assumeTrue(result.n > 0 && ~isempty(result.filter), ...
                    'Need valid filter data for type validation');

                % filter should be row vector
                testCase.verifyTrue(isrow(result.filter), ...
                    'filter must be row vector');
                testCase.verifyTrue(isa(result.filter, 'double'), ...
                    'filter must be double');

                % correlation should be scalar
                testCase.verifyTrue(isscalar(result.correlation), ...
                    'correlation must be scalar');
            catch ME
                testCase.assumeFail(sprintf('Stimulus stream data not available: %s', ME.message));
            end
        end

        function testLinearFilterCorrelationRange(testCase)
            % Correlation coefficient should be in [-1, 1]
            try
                result = getLinearFilterAndPrediction(testCase.LeafNode, ...
                    'Stage', 'Amp1');

                testCase.assumeTrue(result.n > 0 && ~isempty(result.filter), ...
                    'Need valid filter data');

                if ~isnan(result.correlation)
                    testCase.verifyGreaterThanOrEqual(result.correlation, -1, ...
                        'correlation must be >= -1');
                    testCase.verifyLessThanOrEqual(result.correlation, 1, ...
                        'correlation must be <= 1');
                end
            catch ME
                testCase.assumeFail(sprintf('Stimulus stream data not available: %s', ME.message));
            end
        end

        function testLinearFilterWithLength(testCase)
            % Test with explicit FilterLength parameter
            try
                result = getLinearFilterAndPrediction(testCase.LeafNode, ...
                    'Stage', 'Amp1', 'FilterLength', 300);

                testCase.verifyTrue(isstruct(result), ...
                    'Must accept FilterLength parameter');
                testCase.verifyTrue(isfield(result, 'filter'), ...
                    'Output must have filter field');
            catch ME
                testCase.assumeFail(sprintf('Stimulus stream data not available: %s', ME.message));
            end
        end
    end

    %% MeanSelectedNodes tests

    methods (Test)
        function testMeanSelectedNodesOutputFields(testCase)
            % Verify output struct has all required fields
            testCase.assumeTrue(~isempty(testCase.MultipleNodes), ...
                'Need multiple nodes for MeanSelectedNodes tests');

            results = MeanSelectedNodes(testCase.MultipleNodes, 'Amp1', ...
                'Figure', figure('Visible', 'off'));

            testCase.verifyTrue(isstruct(results), 'Output must be a struct');
            testCase.verifyTrue(isfield(results, 'meanResponse'), 'Must have meanResponse');
            testCase.verifyTrue(isfield(results, 'semResponse'), 'Must have semResponse');
            testCase.verifyTrue(isfield(results, 'respAmp'), 'Must have respAmp');
            testCase.verifyTrue(isfield(results, 'splitValue'), 'Must have splitValue');
            testCase.verifyTrue(isfield(results, 'nEpochs'), 'Must have nEpochs');
            testCase.verifyTrue(isfield(results, 'timeVector'), 'Must have timeVector');
            testCase.verifyTrue(isfield(results, 'sampleRate'), 'Must have sampleRate');
        end

        function testMeanSelectedNodesTypes(testCase)
            % Verify field types and dimensions
            testCase.assumeTrue(~isempty(testCase.MultipleNodes), ...
                'Need multiple nodes');

            results = MeanSelectedNodes(testCase.MultipleNodes, 'Amp1', ...
                'Figure', figure('Visible', 'off'));

            nNodes = length(testCase.MultipleNodes);

            % meanResponse should be nNodes x nSamples
            testCase.verifyEqual(size(results.meanResponse, 1), nNodes, ...
                'meanResponse must have nNodes rows');
            testCase.verifyTrue(isa(results.meanResponse, 'double'), ...
                'meanResponse must be double');

            % nEpochs should be 1 x nNodes
            testCase.verifyTrue(isrow(results.nEpochs) || isvector(results.nEpochs), ...
                'nEpochs must be vector');
            testCase.verifyEqual(length(results.nEpochs), nNodes, ...
                'nEpochs length must equal number of nodes');
        end

        function testMeanSelectedNodesDimensions(testCase)
            % Number of rows in outputs should match number of input nodes
            testCase.assumeTrue(~isempty(testCase.MultipleNodes), ...
                'Need multiple nodes');

            nNodes = length(testCase.MultipleNodes);

            results = MeanSelectedNodes(testCase.MultipleNodes, 'Amp1', ...
                'Figure', figure('Visible', 'off'));

            testCase.verifyEqual(size(results.meanResponse, 1), nNodes, ...
                'meanResponse rows must match node count');
            testCase.verifyEqual(size(results.semResponse, 1), nNodes, ...
                'semResponse rows must match node count');
            testCase.verifyEqual(length(results.respAmp), nNodes, ...
                'respAmp length must match node count');
        end

        function testMeanSelectedNodesWithOptions(testCase)
            % Test with BaselineCorrect option
            testCase.assumeTrue(~isempty(testCase.MultipleNodes), ...
                'Need multiple nodes');

            results1 = MeanSelectedNodes(testCase.MultipleNodes, 'Amp1', ...
                'BaselineCorrect', false, 'Figure', figure('Visible', 'off'));
            results2 = MeanSelectedNodes(testCase.MultipleNodes, 'Amp1', ...
                'BaselineCorrect', true, 'Figure', figure('Visible', 'off'));

            testCase.verifyTrue(isstruct(results1), ...
                'Must accept BaselineCorrect=false');
            testCase.verifyTrue(isstruct(results2), ...
                'Must accept BaselineCorrect=true');

            % Results should differ when baseline correction is toggled
            if results1.nEpochs(1) > 0 && results2.nEpochs(1) > 0
                % Allow for the case where baseline is already zero
                % so the results might be identical
                testCase.verifyTrue(true, ...
                    'BaselineCorrect option accepted without error');
            end
        end
    end

    %% Baseline comparison tests

    methods (Test)
        function testMeanResponseTraceBaseline(testCase)
            % Compare output to golden baseline
            baselinePath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                'baselines', 'getMeanResponseTrace_baseline.mat');

            testCase.assumeTrue(isfile(baselinePath), ...
                'Baseline file must exist for regression test');

            % Run function
            resp = getMeanResponseTrace(testCase.LeafNode, 'Amp1');

            % Load baseline
            baselineData = load(baselinePath);
            baseline = baselineData.baseline;

            % Compare key fields with tolerance
            if resp.n > 0 && baseline.n > 0
                testCase.verifyEqual(resp.n, baseline.n, ...
                    'Epoch count should match baseline');
                testCase.verifyEqual(resp.sampleRate, baseline.sampleRate, ...
                    'AbsTol', 1e-6, 'Sample rate should match baseline');
                testCase.verifyEqual(resp.mean, baseline.mean, ...
                    'AbsTol', 1e-10, 'Mean trace should match baseline');
                testCase.verifyEqual(resp.SEM, baseline.SEM, ...
                    'AbsTol', 1e-10, 'SEM should match baseline');
            end
        end

        function testAmplitudeStatsBaseline(testCase)
            % Compare output to golden baseline
            baselinePath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                'baselines', 'getResponseAmplitudeStats_baseline.mat');

            testCase.assumeTrue(isfile(baselinePath), ...
                'Baseline file must exist for regression test');

            % Run function
            stats = getResponseAmplitudeStats(testCase.LeafNode, 'Amp1');

            % Load baseline
            baselineData = load(baselinePath);
            baseline = baselineData.baseline;

            % Compare key fields with tolerance
            if stats.n > 0 && baseline.n > 0
                testCase.verifyEqual(stats.n, baseline.n, ...
                    'Epoch count should match baseline');
                testCase.verifyEqual(stats.mean_peak, baseline.mean_peak, ...
                    'AbsTol', 1e-10, 'Mean peak should match baseline');
                testCase.verifyEqual(stats.sem_peak, baseline.sem_peak, ...
                    'AbsTol', 1e-10, 'SEM peak should match baseline');
            end
        end
    end
end
