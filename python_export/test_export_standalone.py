"""
Standalone test for MATLAB export functionality.
This version doesn't require retinanalysis to be installed.
"""

import numpy as np
import pandas as pd
import scipy.io
import os
import sys
import json

# Add the utils directly to path
matlab_export_path = os.path.abspath('../new_retinanalysis/src/retinanalysis/utils/matlab_export.py')
if not os.path.exists(matlab_export_path):
    print(f"Error: Could not find matlab_export.py at {matlab_export_path}")
    sys.exit(1)

# Load the module directly
import importlib.util
spec = importlib.util.spec_from_file_location("matlab_export", matlab_export_path)
matlab_export = importlib.util.module_from_spec(spec)
sys.modules['matlab_export'] = matlab_export

# Execute the module
try:
    spec.loader.exec_module(matlab_export)
    print("✓ Successfully loaded matlab_export module\n")
except Exception as e:
    print(f"✗ Failed to load module: {e}\n")
    sys.exit(1)

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

    # Create mock pipeline
    print("Creating mock pipeline...")
    pipeline = MockPipeline()
    print("✓ Mock pipeline created")
    print(f"  - {len(pipeline.response_block.df_spike_times)} cells")
    print(f"  - {pipeline.response_block.n_epochs} epochs\n")

    # Create output directory
    output_dir = os.path.join(os.getcwd(), 'test_exports')
    os.makedirs(output_dir, exist_ok=True)

    # Test 1: Full export to MAT
    print("Test 1: Full export to MAT format")
    print("-" * 60)
    mat_file = os.path.join(output_dir, 'test_export.mat')
    try:
        matlab_export.export_pipeline_to_matlab(pipeline, mat_file, format='mat')
        print("✓ MAT export successful\n")
    except Exception as e:
        print(f"✗ MAT export failed: {e}\n")
        import traceback
        traceback.print_exc()
        return False

    # Test 2: Export to JSON
    print("Test 2: Export to JSON format")
    print("-" * 60)
    json_file = os.path.join(output_dir, 'test_export.json')
    try:
        matlab_export.export_pipeline_to_matlab(pipeline, json_file, format='json')
        print("✓ JSON export successful\n")
    except Exception as e:
        print(f"✗ JSON export failed: {e}\n")
        import traceback
        traceback.print_exc()
        return False

    # Test 3: Verify MAT file can be loaded
    print("Test 3: Verifying MAT file contents")
    print("-" * 60)
    try:
        data = scipy.io.loadmat(mat_file, squeeze_me=True, struct_as_record=False)

        # Check basic fields
        required_fields = ['exp_name', 'cell_ids', 'spike_times', 'rf_params',
                          'epoch_params', 'num_cells', 'num_epochs']

        missing_fields = [f for f in required_fields if f not in data]
        if missing_fields:
            print(f"✗ Missing fields: {missing_fields}")
            return False

        print("✓ All required fields present")
        print(f"  - Experiment: {data['exp_name']}")
        print(f"  - Cells: {data['num_cells']}")
        print(f"  - Epochs: {data['num_epochs']}")
        print(f"  - Protocol: {data['protocol_name']}\n")

    except Exception as e:
        print(f"✗ Verification failed: {e}\n")
        import traceback
        traceback.print_exc()
        return False

    # Test 4: Verify spike time access
    print("Test 4: Verifying spike time structure")
    print("-" * 60)
    try:
        spike_times = data['spike_times']

        # Try to access cell_42
        if hasattr(spike_times, 'cell_42'):
            cell_42_data = spike_times.cell_42
            print(f"✓ Cell 42 data accessible")
            print(f"  - Epochs: {cell_42_data.num_epochs}")

            # Access first epoch
            if hasattr(cell_42_data.spike_times, '__len__'):
                first_epoch_spikes = cell_42_data.spike_times[0]
                print(f"  - First epoch has {len(first_epoch_spikes)} spikes")
        else:
            print("✗ Could not access cell_42 in spike_times")
            return False

        print()

    except Exception as e:
        print(f"✗ Spike time verification failed: {e}\n")
        import traceback
        traceback.print_exc()
        return False

    # Test 5: Verify JSON structure
    print("Test 5: Verifying JSON structure")
    print("-" * 60)
    try:
        with open(json_file, 'r') as f:
            json_data = json.load(f)

        print("✓ JSON loads successfully")
        print(f"  - Keys: {len(json_data.keys())} fields")
        print(f"  - Cell IDs: {json_data['cell_ids']}")
        print(f"  - Cell types: {json_data['cell_types']}\n")

    except Exception as e:
        print(f"✗ JSON verification failed: {e}\n")
        return False

    # Test 6: Filtered export
    print("Test 6: Filtered export (OnP cells only)")
    print("-" * 60)
    filtered_file = os.path.join(output_dir, 'test_export_filtered.mat')
    try:
        matlab_export.export_pipeline_to_matlab(
            pipeline,
            filtered_file,
            format='mat',
            cell_types=['OnP']
        )

        # Verify only OnP cells were exported
        data_filtered = scipy.io.loadmat(filtered_file, squeeze_me=True, struct_as_record=False)
        assert data_filtered['num_cells'] == 1, f"Should only have 1 OnP cell, got {data_filtered['num_cells']}"
        print("✓ Filtered export successful")
        print(f"  - Exported {data_filtered['num_cells']} cell(s)\n")

    except Exception as e:
        print(f"✗ Filtered export failed: {e}\n")
        import traceback
        traceback.print_exc()
        return False

    # Test 7: File sizes
    print("Test 7: Checking file sizes")
    print("-" * 60)
    files = {
        'Full MAT': mat_file,
        'Full JSON': json_file,
        'Filtered MAT': filtered_file
    }

    for name, filepath in files.items():
        size_bytes = os.path.getsize(filepath)
        size_kb = size_bytes / 1024
        print(f"  {name:15s}: {size_kb:6.2f} KB")
    print()

    # Success!
    print("="*60)
    print("ALL TESTS PASSED! ✓")
    print("="*60)
    print(f"\nTest files created in: {output_dir}")
    print("  - test_export.mat          (full export)")
    print("  - test_export.json         (full export, JSON)")
    print("  - test_export_filtered.mat (OnP cells only)")
    print("\nNext steps:")
    print("  1. Run the MATLAB test: test_data_loading.m")
    print("  2. Update file path in test_data_loading.m to point to:")
    print(f"     {mat_file}")

    return True

if __name__ == '__main__':
    success = test_export()
    sys.exit(0 if success else 1)
