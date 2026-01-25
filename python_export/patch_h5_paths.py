#!/usr/bin/env python3
"""
Patch existing .mat export files to add h5_file path at experiment level.

This script updates existing exported .mat files to add the h5_file field
that's needed for lazy loading of response data in MATLAB.
"""

import sys
import os
import scipy.io
import numpy as np
from datetime import datetime
import h5py


def get_nested_value(arr):
    """Extract value from deeply nested numpy arrays."""
    while isinstance(arr, np.ndarray) and arr.size == 1:
        arr = arr.flat[0]
    return arr


def add_h5_file_to_experiment(exp, h5_file_path):
    """
    Create a new structured array with h5_file field added.

    Since numpy structured arrays are immutable in terms of fields,
    we need to create a new array with the additional field.
    """
    old_dtype = exp.dtype
    new_fields = list(old_dtype.descr) + [('h5_file', 'O')]
    new_dtype = np.dtype(new_fields)

    new_exp = np.zeros(exp.shape, dtype=new_dtype)

    # Copy existing fields
    for name in old_dtype.names:
        new_exp[name] = exp[name]

    # Add new field
    new_exp['h5_file'] = np.array([[h5_file_path]])

    return new_exp


def patch_mat_file(mat_file: str, h5_dir: str, output_file: str = None):
    """
    Add h5_file field to experiment level in .mat file.

    This adds h5_file field so MATLAB can lazy-load response data from H5 files.

    Args:
        mat_file: Path to existing .mat file
        h5_dir: Directory containing H5 files
        output_file: Output path (defaults to overwriting input)
    """
    if output_file is None:
        output_file = mat_file

    print(f"Loading {mat_file}...")

    # Load preserving structure
    data = scipy.io.loadmat(mat_file, squeeze_me=False, struct_as_record=True)

    # Get experiments array
    experiments = data['experiments']

    # Process each experiment
    patched_experiments = []

    for i in range(experiments.shape[0]):
        for j in range(experiments.shape[1]):
            exp = experiments[i, j]

            # Get experiment name
            exp_name = get_nested_value(exp['exp_name'])
            exp_name = str(exp_name)

            # Construct h5_file path
            h5_file = os.path.join(h5_dir, f"{exp_name}.h5")

            print(f"  Experiment '{exp_name}' -> h5_file: {h5_file}")

            # Verify H5 file exists
            if os.path.exists(h5_file):
                print(f"    ✓ H5 file found")
            else:
                print(f"    WARNING: H5 file not found!")

            # Add h5_file field
            patched_exp = add_h5_file_to_experiment(exp, h5_file)
            patched_experiments.append(patched_exp)

    # Rebuild experiments array
    data['experiments'] = np.array(patched_experiments, dtype=object).reshape(experiments.shape)

    # Save
    print(f"\nSaving to {output_file}...")
    scipy.io.savemat(output_file, data, do_compression=True)
    print("Done!")


def verify_mat_file(mat_file: str):
    """Verify the patched .mat file has h5_file field."""
    print(f"\nVerifying {mat_file}...")
    data = scipy.io.loadmat(mat_file, squeeze_me=False, struct_as_record=True)

    experiments = data['experiments']
    exp = experiments[0, 0]

    print(f"Experiment dtype fields: {exp.dtype.names}")

    if 'h5_file' in exp.dtype.names:
        h5_file = get_nested_value(exp['h5_file'])
        print(f"h5_file: {h5_file}")
        return True
    else:
        print("ERROR: h5_file field not found!")
        return False


def verify_data_loading(mat_file: str):
    """Test that we can actually load data from H5 using the paths."""
    print(f"\nTesting data loading from {mat_file}...")
    data = scipy.io.loadmat(mat_file, squeeze_me=False, struct_as_record=True)

    exp = data['experiments'][0, 0]
    h5_file = get_nested_value(exp['h5_file'])

    if not os.path.exists(h5_file):
        print(f"ERROR: H5 file not found: {h5_file}")
        return False

    # Navigate to first response
    cells = exp['cells'][0, 0]
    cell = cells[0, 0]
    egs = cell['epoch_groups'][0, 0]
    eg = egs[0, 0]
    ebs = eg['epoch_blocks'][0, 0]
    eb = ebs[0, 0]
    epochs = eb['epochs'][0, 0]
    ep = epochs[0, 0]

    responses = ep['responses'][0, 0]
    resp = responses[0, 0]

    h5_path = get_nested_value(resp['h5_path'])
    print(f"  H5 file: {h5_file}")
    print(f"  H5 path: {h5_path[:80]}...")

    # Try to load data
    try:
        with h5py.File(h5_file, 'r') as f:
            clean_path = h5_path.lstrip('/')
            grp = f[clean_path]
            data_ds = grp['data']
            raw_data = data_ds[:]

            if 'quantity' in raw_data.dtype.names:
                values = raw_data['quantity']
            else:
                values = raw_data

            print(f"  ✓ Loaded data shape: {values.shape}")
            print(f"  ✓ Data range: [{values.min():.4f}, {values.max():.4f}]")
            return True

    except Exception as e:
        print(f"ERROR: Failed to load data: {e}")
        return False


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python patch_h5_paths.py <mat_file> <h5_dir> [output_file]")
        print("Example: python patch_h5_paths.py data.mat /path/to/h5files/")
        sys.exit(1)

    mat_file = sys.argv[1]
    h5_dir = sys.argv[2]
    output_file = sys.argv[3] if len(sys.argv) > 3 else None

    patch_mat_file(mat_file, h5_dir, output_file)

    result_file = output_file or mat_file
    if verify_mat_file(result_file):
        verify_data_loading(result_file)
