#!/usr/bin/env python3
"""
Convert Symphony2Reader JSON output to EpicTreeGUI standard .mat format.

This script transforms the JSON structure from Symphony2Reader into the
standardized .mat format defined in DATA_FORMAT_SPECIFICATION.md.

Usage:
    python json_to_mat.py <input_json> <output_mat>

Example:
    python json_to_mat.py experiment.json experiment.mat
"""

import json
import os
import sys
import argparse
from datetime import datetime
from typing import Dict, List, Any, Optional

import numpy as np
import scipy.io as sio


def convert_json_to_mat(json_path: str, mat_path: str, username: str = 'user') -> None:
    """
    Convert Symphony2Reader JSON to EpicTreeGUI .mat format.

    Args:
        json_path: Path to input JSON file
        mat_path: Path to output .mat file
        username: Username for metadata
    """
    print(f"Loading JSON from: {json_path}")

    with open(json_path, 'r') as f:
        json_data = json.load(f)

    # Extract experiment name from filename
    exp_name = os.path.splitext(os.path.basename(json_path))[0]

    # Map to standard format
    experiments = map_experiments(json_data, exp_name)

    # Build output structure
    output = {
        'format_version': '1.0',
        'metadata': {
            'created_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'data_source': 'Symphony H5 + JSON',
            'source_database': 'local',
            'export_user': username,
            'notes': f'Converted from {os.path.basename(json_path)}'
        },
        'experiments': np.array(experiments, dtype=object)
    }

    # Clean None values before saving (scipy.io.savemat can't handle None)
    output = clean_for_matlab(output)

    # Save to .mat file
    print(f"Saving .mat file to: {mat_path}")
    sio.savemat(mat_path, output, do_compression=True)

    # Print summary
    print_summary(output)


def map_experiments(json_data: Dict, exp_name: str) -> List[Dict]:
    """
    Map JSON structure to experiments array.

    The JSON from Symphony2Reader has structure:
        animals[] → preparations[] → cells[] → epoch_groups[] → ...

    We flatten this to:
        experiments[] → cells[] → epoch_groups[] → ...
    """
    experiments = []
    exp_id = 1

    # Determine rig type
    rig_type = json_data.get('rig_type', 'PATCH')
    is_mea = (rig_type == 'MEA')

    # Create experiment from the top level
    experiment = {
        'id': np.int32(exp_id),
        'exp_name': exp_name,
        'label': json_data.get('label', ''),
        'is_mea': is_mea,
        'start_time': json_data.get('start_time', ''),
        'experimenter': '',
        'rig': rig_type,
        'institution': '',
        'cells': []
    }

    # Flatten animals/preparations/cells into cells
    cell_id = 1
    animals = json_data.get('animals', [])

    for animal in animals:
        preparations = animal.get('preparations', [])
        for prep in preparations:
            cells = prep.get('cells', [])
            for cell_data in cells:
                cell = map_cell(cell_data, cell_id)
                experiment['cells'].append(cell)
                cell_id += 1

    # Convert cells list to numpy array for MATLAB
    experiment['cells'] = np.array(experiment['cells'], dtype=object)
    experiments.append(experiment)

    return experiments


def map_cell(cell_data: Dict, cell_id: int) -> Dict:
    """Map cell data to standard format."""
    cell = {
        'id': np.int32(cell_id),
        'label': cell_data.get('label', f'Cell{cell_id}'),
        'type': cell_data.get('type', ''),
        'properties': cell_data.get('properties', {}),
        'noise_id': np.int32(0),
        'rf_params': {},
        'epoch_groups': []
    }

    # Map epoch groups
    eg_id = 1
    epoch_groups = cell_data.get('epoch_groups', [])

    for eg_data in epoch_groups:
        eg = map_epoch_group(eg_data, eg_id)
        cell['epoch_groups'].append(eg)
        eg_id += 1

    cell['epoch_groups'] = np.array(cell['epoch_groups'], dtype=object)
    return cell


def map_epoch_group(eg_data: Dict, eg_id: int) -> Dict:
    """Map epoch group data to standard format."""
    epoch_group = {
        'id': np.int32(eg_id),
        'label': eg_data.get('label', f'Group{eg_id}'),
        'protocol_name': '',  # Will be set from first epoch block
        'protocol_id': np.int32(0),
        'start_time': eg_data.get('start_time', ''),
        'end_time': eg_data.get('end_time', ''),
        'epoch_blocks': []
    }

    # Map epoch blocks
    eb_id = 1
    epoch_blocks = eg_data.get('epoch_blocks', [])

    for eb_data in epoch_blocks:
        eb = map_epoch_block(eb_data, eb_id)
        epoch_group['epoch_blocks'].append(eb)

        # Set protocol name from first block
        if eb_id == 1 and eb.get('protocol_name'):
            epoch_group['protocol_name'] = eb['protocol_name']

        eb_id += 1

    epoch_group['epoch_blocks'] = np.array(epoch_group['epoch_blocks'], dtype=object)
    return epoch_group


def map_epoch_block(eb_data: Dict, eb_id: int) -> Dict:
    """Map epoch block data to standard format."""
    # Extract protocol name from protocolID (e.g., "edu.washington.riekelab.protocols.SingleSpot")
    protocol_id = eb_data.get('protocolID', '')
    protocol_name = protocol_id.split('.')[-1] if protocol_id else ''

    epoch_block = {
        'id': np.int32(eb_id),
        'label': f'Block{eb_id}',
        'protocol_name': protocol_name,
        'protocol_id': np.int32(eb_id),
        'start_time': eb_data.get('start_time', ''),
        'end_time': eb_data.get('end_time', ''),
        'parameters': convert_parameters(eb_data.get('parameters', {})),
        'data_dir': eb_data.get('dataFile', '') or '',
        'sorting_algorithm': '',
        'epochs': []
    }

    # Map epochs
    epoch_id = 1
    epochs = eb_data.get('epochs', [])

    for epoch_data in epochs:
        epoch = map_epoch(epoch_data, epoch_id)
        epoch_block['epochs'].append(epoch)
        epoch_id += 1

    epoch_block['epochs'] = np.array(epoch_block['epochs'], dtype=object)
    return epoch_block


def map_epoch(epoch_data: Dict, epoch_id: int) -> Dict:
    """Map epoch data to standard format."""
    epoch = {
        'id': np.int32(epoch_id),
        'label': epoch_data.get('label', f'Epoch{epoch_id}'),
        'start_time': epoch_data.get('start_time', ''),
        'end_time': epoch_data.get('end_time', ''),
        'epoch_start_ms': np.float64(0.0),
        'epoch_end_ms': np.float64(0.0),
        'frame_times_ms': np.array(epoch_data.get('frameTimesMs', []), dtype=np.float64),
        'parameters': convert_parameters(epoch_data.get('parameters', {})),
        'responses': [],
        'stimuli': []
    }

    # Map responses - handle both dict (keyed by device name) and list formats
    resp_id = 1
    responses = epoch_data.get('responses', {})

    if isinstance(responses, dict):
        # JSON format: {'Amp1': {...}, 'Frame Monitor': {...}}
        for device_name, resp_data in responses.items():
            resp = map_response(resp_data, resp_id, device_name)
            epoch['responses'].append(resp)
            resp_id += 1
    elif isinstance(responses, list):
        # List format
        for resp_data in responses:
            resp = map_response(resp_data, resp_id)
            epoch['responses'].append(resp)
            resp_id += 1

    epoch['responses'] = np.array(epoch['responses'], dtype=object) if epoch['responses'] else np.array([], dtype=object)

    # Map stimuli - handle both dict and list formats
    stim_id = 1
    stimuli = epoch_data.get('stimuli', {})

    if isinstance(stimuli, dict):
        # JSON format: {'Amp1': {...}, 'Stage': {...}}
        for device_name, stim_data in stimuli.items():
            stim = map_stimulus(stim_data, stim_id, device_name)
            epoch['stimuli'].append(stim)
            stim_id += 1
    elif isinstance(stimuli, list):
        # List format
        for stim_data in stimuli:
            stim = map_stimulus(stim_data, stim_id)
            epoch['stimuli'].append(stim)
            stim_id += 1

    epoch['stimuli'] = np.array(epoch['stimuli'], dtype=object) if epoch['stimuli'] else np.array([], dtype=object)

    return epoch


def map_response(resp_data: Dict, resp_id: int, device_name: str = None) -> Dict:
    """Map response data to standard format."""
    # Extract data array (may be empty if data is in H5 file)
    data = resp_data.get('data', [])
    if isinstance(data, list):
        data = np.array(data, dtype=np.float64)

    # Extract spike times if available
    spike_times = resp_data.get('spike_times', [])
    if isinstance(spike_times, list):
        spike_times = np.array(spike_times, dtype=np.float64)

    # Determine device name
    if device_name is None:
        device_name = resp_data.get('device_name', resp_data.get('label', f'Response{resp_id}'))

    response = {
        'id': np.int32(resp_id),
        'device_name': device_name,
        'label': resp_data.get('label', device_name),
        'data': data,
        'spike_times': spike_times,
        'sample_rate': np.float64(resp_data.get('sampleRate', resp_data.get('sample_rate', 10000))),
        'sample_rate_units': resp_data.get('sampleRateUnits', 'Hz'),
        'units': resp_data.get('units', 'pA'),
        'offset_ms': np.float64(0.0),
        'h5_path': resp_data.get('h5path', '')  # Store H5 path for data access
    }

    return response


def map_stimulus(stim_data: Dict, stim_id: int, device_name: str = None) -> Dict:
    """Map stimulus data to standard format."""
    # Extract data array (may be empty if data is in H5 file)
    data = stim_data.get('data', [])
    if isinstance(data, list):
        data = np.array(data, dtype=np.float64)

    # Determine device name
    if device_name is None:
        device_name = stim_data.get('device_name', stim_data.get('label', f'Stimulus{stim_id}'))

    stimulus = {
        'id': np.int32(stim_id),
        'device_name': device_name,
        'label': stim_data.get('label', device_name),
        'data': data,
        'sample_rate': np.float64(stim_data.get('sampleRate', stim_data.get('sample_rate', 10000))),
        'units': stim_data.get('units', 'normalized'),
        'h5_path': stim_data.get('h5path', '')  # Store H5 path for data access
    }

    return stimulus


def convert_parameters(params: Dict) -> Dict:
    """Convert parameter values to MATLAB-compatible types."""
    converted = {}

    for key, value in params.items():
        if value is None:
            converted[key] = ''
        elif isinstance(value, bool):
            converted[key] = np.int32(1 if value else 0)
        elif isinstance(value, int):
            converted[key] = np.int32(value)
        elif isinstance(value, float):
            converted[key] = np.float64(value)
        elif isinstance(value, (list, tuple)):
            converted[key] = np.array(value)
        elif isinstance(value, dict):
            converted[key] = convert_parameters(value)
        else:
            converted[key] = str(value)

    return converted


def clean_for_matlab(obj: Any) -> Any:
    """
    Recursively clean data structure for MATLAB compatibility.
    - Replace None with empty string or empty array
    - Convert dicts to have consistent types
    """
    if obj is None:
        return ''
    elif isinstance(obj, dict):
        return {k: clean_for_matlab(v) for k, v in obj.items()}
    elif isinstance(obj, np.ndarray):
        if obj.dtype == object:
            # Clean each element in object array
            cleaned = []
            for item in obj.flat:
                cleaned.append(clean_for_matlab(item))
            return np.array(cleaned, dtype=object).reshape(obj.shape) if cleaned else np.array([], dtype=object)
        return obj
    elif isinstance(obj, list):
        return [clean_for_matlab(item) for item in obj]
    else:
        return obj


def print_summary(output: Dict) -> None:
    """Print summary of converted data."""
    print("\n" + "=" * 50)
    print("Conversion Complete")
    print("=" * 50)
    print(f"Format Version: {output['format_version']}")
    print(f"Created: {output['metadata']['created_date']}")

    experiments = output['experiments']
    print(f"\nExperiments: {len(experiments)}")

    total_cells = 0
    total_epochs = 0

    for exp in experiments:
        cells = exp['cells']
        total_cells += len(cells)
        print(f"  - {exp['exp_name']}: {len(cells)} cells")

        for cell in cells:
            for eg in cell['epoch_groups']:
                for eb in eg['epoch_blocks']:
                    total_epochs += len(eb['epochs'])

    print(f"\nTotal Cells: {total_cells}")
    print(f"Total Epochs: {total_epochs}")
    print("=" * 50 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description='Convert Symphony2Reader JSON to EpicTreeGUI .mat format'
    )
    parser.add_argument('input_json', help='Path to input JSON file')
    parser.add_argument('output_mat', help='Path to output .mat file')
    parser.add_argument('-u', '--user', default='user', help='Username for metadata')

    args = parser.parse_args()

    # Validate input
    if not os.path.exists(args.input_json):
        print(f"Error: Input file not found: {args.input_json}")
        sys.exit(1)

    # Create output directory if needed
    output_dir = os.path.dirname(args.output_mat)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Convert
    convert_json_to_mat(args.input_json, args.output_mat, args.user)


if __name__ == '__main__':
    main()
