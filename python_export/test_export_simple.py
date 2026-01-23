"""
Simple test script for MATLAB export functionality.

This script creates a minimal mock pipeline and tests the export function.
Useful for verifying the export works without needing real experimental data.
"""

import numpy as np
import pandas as pd
import scipy.io
import os
import sys

# Mock classes for testing
class MockAnalysisChunk:
    def __init__(self):
        self.df_cell_params = pd.DataFrame({
            'cell_id': [1, 2, 3],
            'center_x': [100.0, 150.0, 200.0],
            'center_y': [100.0, 150.0, 200.0],
            'std_x': [20.0, 25.0, 30.0],
            'std_y': [20.0, 25.0, 30.0],
            'rotation': [0.0, 45.0, 90.0]
        })

class MockStimBlock:
    def __init__(self):
        self.protocol_name = 'TestProtocol'
        self.parameter_names = ['contrast', 'size', 'temporal_freq']
        self.df_epochs = pd.DataFrame({
            'epoch_parameters': [
                {'contrast': 0.5, 'size': 200, 'temporal_freq': 4.0},
                {'contrast': 0.8, 'size': 300, 'temporal_freq': 2.0},
                {'contrast': 0.3, 'size': 400, 'temporal_freq': 8.0}
            ]
        })

class MockResponseBlock:
    def __init__(self):
        self.exp_name = 'TEST_EXP'
        self.block_id = 1
        self.datafile_name = 'data_test'
        self.n_epochs = 3

        # Create mock spike times (3 cells, 3 epochs each)
        self.df_spike_times = pd.DataFrame({
            'cell_id': [42, 56, 78],
            'cell_type': ['OnP', 'OffP', 'OnM'],
            'noise_id': [1, 2, 3],
            'spike_times': [
                # Cell 42 - 3 epochs
                [
                    np.array([10.5, 25.3, 45.7, 67.2]),  # Epoch 1
                    np.array([12.1, 28.9, 42.3]),        # Epoch 2
                    np.array([15.2, 35.6, 48.1, 62.3, 75.4])  # Epoch 3
                ],
                # Cell 56 - 3 epochs
                [
                    np.array([8.2, 22.5, 38.9]),
                    np.array([11.3, 27.6, 44.2, 58.7]),
                    np.array([9.8, 31.2])
                ],
                # Cell 78 - 3 epochs
                [
                    np.array([13.4, 29.1, 41.5, 55.8]),
                    np.array([16.7, 32.3, 49.1]),
                    np.array([14.2, 28.5, 43.7, 61.2])
                ]
            ]
        })

        self.d_timing = {
            'epochStarts': np.array([0.0, 1000.0, 2000.0]),
            'epochEnds': np.array([800.0, 1800.0, 2800.0]),
            'frameTimesMs': [
                np.array([0, 16.67, 33.33, 50.0]),
                np.array([0, 16.67, 33.33, 50.0]),
                np.array([0, 16.67, 33.33, 50.0])
            ]
        }

class MockPipeline:
    def __init__(self):
        self.response_block = MockResponseBlock()
        self.stim_block = MockStimBlock()
        self.analysis_chunk = MockAnalysisChunk()

def test_export():
    """Test the MATLAB export functionality with mock data"""

    print("="*60)
    print("Testing MATLAB Export Functionality")
    print("="*60)

    # Add the utils path
    utils_path = os.path.abspath('../new_retinanalysis/src')
    if utils_path not in sys.path:
        sys.path.insert(0, utils_path)

    try:
        from retinanalysis.utils.matlab_export import export_pipeline_to_matlab
        print("✓ Successfully imported export function\n")
    except ImportError as e:
        print(f"✗ Could not import export function: {e}")
        print("  Make sure retinanalysis is installed or add it to your path\n")
        return False

    # Create mock pipeline
    print("Creating mock pipeline...")
    pipeline = MockPipeline()
    print("✓ Mock pipeline created\n")

    # Create output directory
    output_dir = os.path.join(os.getcwd(), 'test_exports')
    os.makedirs(output_dir, exist_ok=True)

    # Test 1: Full export to MAT
    print("Test 1: Full export to MAT format")
    mat_file = os.path.join(output_dir, 'test_export.mat')
    try:
        export_pipeline_to_matlab(pipeline, mat_file, format='mat')
        print("✓ MAT export successful\n")
    except Exception as e:
        print(f"✗ MAT export failed: {e}\n")
        return False

    # Test 2: Export to JSON
    print("Test 2: Export to JSON format")
    json_file = os.path.join(output_dir, 'test_export.json')
    try:
        export_pipeline_to_matlab(pipeline, json_file, format='json')
        print("✓ JSON export successful\n")
    except Exception as e:
        print(f"✗ JSON export failed: {e}\n")
        return False

    # Test 3: Verify MAT file can be loaded
    print("Test 3: Verifying MAT file contents")
    try:
        data = scipy.io.loadmat(mat_file, squeeze_me=True, struct_as_record=False)

        # Check basic fields
        assert 'exp_name' in data, "Missing exp_name"
        assert 'cell_ids' in data, "Missing cell_ids"
        assert 'spike_times' in data, "Missing spike_times"
        assert 'rf_params' in data, "Missing rf_params"
        assert 'epoch_params' in data, "Missing epoch_params"

        print("✓ All required fields present")
        print(f"  - Cells: {data['num_cells']}")
        print(f"  - Epochs: {data['num_epochs']}")
        print(f"  - Protocol: {data['protocol_name']}\n")

    except Exception as e:
        print(f"✗ Verification failed: {e}\n")
        return False

    # Test 4: Filtered export
    print("Test 4: Filtered export (OnP cells only)")
    filtered_file = os.path.join(output_dir, 'test_export_filtered.mat')
    try:
        export_pipeline_to_matlab(
            pipeline,
            filtered_file,
            format='mat',
            cell_types=['OnP']
        )

        # Verify only OnP cells were exported
        data_filtered = scipy.io.loadmat(filtered_file, squeeze_me=True, struct_as_record=False)
        assert data_filtered['num_cells'] == 1, "Should only have 1 OnP cell"
        print("✓ Filtered export successful\n")

    except Exception as e:
        print(f"✗ Filtered export failed: {e}\n")
        return False

    # Success!
    print("="*60)
    print("ALL TESTS PASSED!")
    print("="*60)
    print(f"\nTest files created in: {output_dir}")
    print("  - test_export.mat")
    print("  - test_export.json")
    print("  - test_export_filtered.mat")
    print("\nYou can now test loading these files in MATLAB using:")
    print("  test_data_loading.m")

    return True

if __name__ == '__main__':
    success = test_export()
    sys.exit(0 if success else 1)
