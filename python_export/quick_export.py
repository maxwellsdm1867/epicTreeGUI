#!/usr/bin/env python3
"""
Quick export script using retinanalysis to create test data.

This creates a minimal .mat file that EpicTreeGUI can load.
"""

import sys
import os

# Add retinanalysis to path
sys.path.insert(0, '/Users/maxwellsdm/Documents/GitHub/epicTreeGUI/new_retinanalysis/src')

import numpy as np
import scipy.io
import h5py
from datetime import datetime

def export_experiment(exp_name, h5_dir, output_file):
    """
    Export experiment data to .mat file format for EpicTreeGUI.

    This reads directly from H5 files and creates the hierarchical structure.
    """
    h5_file = os.path.join(h5_dir, f'{exp_name}.h5')

    if not os.path.exists(h5_file):
        print(f"ERROR: H5 file not found: {h5_file}")
        return False

    print(f"Reading from H5 file: {h5_file}")

    # Build experiment structure by parsing H5 file
    experiment = {
        'id': 1,
        'exp_name': exp_name,
        'label': exp_name,
        'is_mea': False,
        'start_time': '',
        'experimenter': '',
        'rig': '',
        'institution': '',
        'h5_file': h5_file,
        'cells': []
    }

    with h5py.File(h5_file, 'r') as f:
        # Find the experiment group
        exp_groups = [k for k in f.keys() if k.startswith('experiment-')]
        if not exp_groups:
            print("ERROR: No experiment group found in H5 file")
            return False

        exp_key = exp_groups[0]
        print(f"Found experiment: {exp_key}")

        # Navigate to sources
        sources_path = f'{exp_key}/sources'
        if sources_path not in f:
            print(f"ERROR: No sources found at {sources_path}")
            return False

        sources = f[sources_path]
        source_keys = [k for k in sources.keys() if k.startswith('source-')]

        for source_idx, source_key in enumerate(source_keys):
            source = sources[source_key]

            # Check for experiment subgroup (this is where cells are)
            if 'experiment' not in source:
                continue

            exp_subgroup = source['experiment']

            # Find epoch groups
            if 'epochGroups' not in exp_subgroup:
                continue

            epoch_groups_grp = exp_subgroup['epochGroups']
            eg_keys = [k for k in epoch_groups_grp.keys() if k.startswith('epochGroup-')]

            # Create cell structure (one "cell" per source for patch data)
            cell = {
                'id': source_idx + 1,
                'label': f'Cell {source_idx + 1}',
                'type': 'RGC',
                'properties': {},
                'noise_id': 0,
                'rf_params': {},
                'epoch_groups': []
            }

            for eg_key in eg_keys:
                eg_grp = epoch_groups_grp[eg_key]

                epoch_group = {
                    'id': hash(eg_key) % 100000,
                    'label': eg_key,
                    'protocol_name': '',
                    'start_time': '',
                    'end_time': '',
                    'epoch_blocks': []
                }

                # Find epoch blocks
                if 'epochBlocks' not in eg_grp:
                    continue

                epoch_blocks_grp = eg_grp['epochBlocks']

                for eb_key in epoch_blocks_grp.keys():
                    eb_grp = epoch_blocks_grp[eb_key]

                    # Extract protocol name from key
                    protocol_name = eb_key.split('-')[0] if '-' in eb_key else eb_key

                    epoch_block = {
                        'id': hash(eb_key) % 100000,
                        'label': eb_key,
                        'protocol_name': protocol_name,
                        'start_time': '',
                        'end_time': '',
                        'parameters': {},
                        'data_dir': '',
                        'epochs': []
                    }

                    # Find epochs
                    if 'epochs' not in eb_grp:
                        continue

                    epochs_grp = eb_grp['epochs']

                    for ep_key in epochs_grp.keys():
                        if not ep_key.startswith('epoch-'):
                            continue

                        ep_grp = epochs_grp[ep_key]

                        epoch = {
                            'id': hash(ep_key) % 100000,
                            'label': ep_key,
                            'start_time': '',
                            'end_time': '',
                            'epoch_start_ms': 0.0,
                            'epoch_end_ms': 0.0,
                            'frame_times_ms': [],
                            'parameters': {},
                            'responses': [],
                            'stimuli': []
                        }

                        # Find responses
                        if 'responses' in ep_grp:
                            responses_grp = ep_grp['responses']

                            for resp_key in responses_grp.keys():
                                resp_grp = responses_grp[resp_key]

                                # Extract device name from key
                                device_name = resp_key.split('-')[0] if '-' in resp_key else resp_key

                                # Get h5 path
                                h5_path = f'/{sources_path}/{source_key}/experiment/epochGroups/{eg_key}/epochBlocks/{eb_key}/epochs/{ep_key}/responses/{resp_key}'

                                # Get sample rate if available
                                sample_rate = 10000  # default

                                response = {
                                    'id': hash(resp_key) % 100000,
                                    'device_name': device_name,
                                    'label': device_name,
                                    'data': np.array([]),  # Empty - will lazy load
                                    'spike_times': np.array([]),
                                    'sample_rate': sample_rate,
                                    'sample_rate_units': 'Hz',
                                    'units': 'mV',
                                    'offset_ms': 0.0,
                                    'h5_path': h5_path
                                }

                                epoch['responses'].append(response)

                        epoch_block['epochs'].append(epoch)

                    if epoch_block['epochs']:
                        epoch_group['epoch_blocks'].append(epoch_block)

                if epoch_group['epoch_blocks']:
                    cell['epoch_groups'].append(epoch_group)

            if cell['epoch_groups']:
                experiment['cells'].append(cell)

    # Count epochs
    total_epochs = 0
    for cell in experiment['cells']:
        for eg in cell['epoch_groups']:
            for eb in eg['epoch_blocks']:
                total_epochs += len(eb['epochs'])

    print(f"Found {len(experiment['cells'])} cells, {total_epochs} epochs")

    if total_epochs == 0:
        print("WARNING: No epochs found!")
        return False

    # Create export data structure
    export_data = {
        'format_version': '1.0',
        'metadata': {
            'created_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'data_source': 'H5 file direct parse',
            'source_database': '',
            'export_user': os.getenv('USER', 'guest'),
            'notes': f'Exported from {h5_file}'
        },
        'experiments': [experiment]
    }

    # Save to .mat file
    print(f"Saving to {output_file}...")
    scipy.io.savemat(output_file, export_data, do_compression=True)
    print(f"Done! Exported {total_epochs} epochs")

    return True


if __name__ == '__main__':
    exp_name = '2025-12-02_F'
    h5_dir = '/Users/maxwellsdm/Documents/epicTreeTest/h5'
    output_file = '/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat'

    export_experiment(exp_name, h5_dir, output_file)
