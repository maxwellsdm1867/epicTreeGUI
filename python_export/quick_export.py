#!/usr/bin/env python3
"""
Quick export script using retinanalysis to create test data.

This creates a .mat file that EpicTreeGUI can load, extracting all available
metadata from the H5 file at every level of the hierarchy.
"""

import sys
import os

# Add retinanalysis to path
sys.path.insert(0, '/Users/maxwellsdm/Documents/GitHub/epicTreeGUI/new_retinanalysis/src')

import numpy as np
import scipy.io
import h5py
from datetime import datetime


def _convert_h5_attr(val):
    """Convert HDF5 attribute value to a Python/scipy-compatible type."""
    # h5py.Empty is returned for empty datasets — convert to empty string
    if hasattr(h5py, 'Empty') and isinstance(val, h5py.Empty):
        return ''
    if isinstance(val, bytes):
        return val.decode('utf-8')
    if isinstance(val, np.bytes_):
        return val.decode('utf-8')
    if isinstance(val, np.dtype):
        return str(val)
    if isinstance(val, np.ndarray):
        if val.dtype.kind == 'S':  # byte string array
            if val.size == 1:
                return val.flat[0].decode('utf-8') if val.flat[0] else ''
            return [x.decode('utf-8') if x else '' for x in val.flat]
        if val.ndim == 0:
            return val.item()
        if val.size == 1:
            return val.item()
        # Multi-element arrays: keep as numpy array (scipy.io handles them)
        return val
    if isinstance(val, (np.integer, np.floating, np.bool_)):
        return val.item()
    return val


def _read_all_attrs(grp):
    """Read all attributes from an HDF5 group into a dict."""
    result = {}
    for k, v in grp.attrs.items():
        result[k] = _convert_h5_attr(v)
    return result


def _read_properties(grp):
    """Read a 'properties' HDF5 group: attrs from the group + attrs from each child group."""
    props = {}
    if not isinstance(grp, h5py.Group):
        return props
    # Group-level attrs
    props.update(_read_all_attrs(grp))
    # Each child in properties is typically a scalar dataset or a group with attrs
    for key in grp.keys():
        item = grp[key]
        if isinstance(item, h5py.Dataset):
            try:
                val = item[()]
                props[key] = _convert_h5_attr(val)
            except Exception:
                props[key] = ''
        elif isinstance(item, h5py.Group):
            # Some properties are stored as groups with their own attrs
            child_attrs = _read_all_attrs(item)
            if child_attrs:
                props[key] = child_attrs
    return props


def _sanitize_for_mat(obj):
    """Recursively sanitize data for scipy.io.savemat compatibility.

    Converts any remaining numpy bytes, dtypes, or other problematic types
    to plain Python types that savemat can handle.
    """
    if isinstance(obj, dict):
        return {k: _sanitize_for_mat(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_sanitize_for_mat(v) for v in obj]
    if isinstance(obj, (bytes, np.bytes_)):
        return obj.decode('utf-8') if isinstance(obj, bytes) else obj.decode('utf-8')
    if hasattr(h5py, 'Empty') and isinstance(obj, h5py.Empty):
        return ''
    if isinstance(obj, np.dtype):
        return str(obj)
    if isinstance(obj, np.ndarray):
        if obj.dtype.kind == 'S':  # byte string array
            return [x.decode('utf-8') if x else '' for x in obj.flat]
        if obj.dtype.kind == 'V':  # structured/void
            return str(obj)
        return obj
    if isinstance(obj, (np.integer, np.floating, np.bool_)):
        return obj.item()
    return obj


def _find_cell_source(eg_grp):
    """Walk the epochGroup's source chain to find cell label and type.

    The H5 source hierarchy is: Primate -> Preparation -> Cell
    The epochGroup links to the deepest source (Cell level).
    """
    cell_label = ''
    cell_type = ''
    source_props = {}

    if 'source' not in eg_grp:
        return cell_label, cell_type, source_props

    source = eg_grp['source']

    # Read this source's label and properties
    source_attrs = _read_all_attrs(source)
    cell_label = source_attrs.get('label', '')

    if 'properties' in source:
        source_props = _read_properties(source['properties'])
        cell_type = source_props.get('type', '')
        if isinstance(cell_type, bytes):
            cell_type = cell_type.decode('utf-8')

    return cell_label, cell_type, source_props


def export_experiment(exp_name, h5_dir, output_file):
    """
    Export experiment data to .mat file format for EpicTreeGUI.

    Reads directly from H5 files and creates the hierarchical structure,
    extracting all available metadata at every level.
    """
    h5_file = os.path.join(h5_dir, f'{exp_name}.h5')

    if not os.path.exists(h5_file):
        print(f"ERROR: H5 file not found: {h5_file}")
        return False

    print(f"Reading from H5 file: {h5_file}")

    with h5py.File(h5_file, 'r') as f:
        # Find the experiment group
        exp_groups = [k for k in f.keys() if k.startswith('experiment-')]
        if not exp_groups:
            print("ERROR: No experiment group found in H5 file")
            return False

        exp_key = exp_groups[0]
        print(f"Found experiment: {exp_key}")

        # --- Experiment-level metadata ---
        exp_grp = f[exp_key]
        exp_attrs = _read_all_attrs(exp_grp)

        exp_properties = {}
        if 'properties' in exp_grp:
            exp_properties = _read_properties(exp_grp['properties'])

        experiment = {
            'id': 1,
            'exp_name': exp_name,
            'label': exp_name,
            'is_mea': False,
            'start_time': exp_attrs.get('startTimeDotNetDateTimeOffsetTicks', ''),
            'purpose': exp_attrs.get('purpose', ''),
            'experimenter': exp_properties.get('experimenter', ''),
            'rig': exp_properties.get('rig', ''),
            'institution': exp_properties.get('institution', ''),
            'lab': exp_properties.get('lab', ''),
            'project': exp_properties.get('project', ''),
            'h5_file': h5_file,
            'cells': []
        }

        # Navigate to sources
        sources_path = f'{exp_key}/sources'
        if sources_path not in f:
            print(f"ERROR: No sources found at {sources_path}")
            return False

        sources = f[sources_path]
        source_keys = [k for k in sources.keys() if k.startswith('source-')]

        # Track cell info discovered from epoch group sources
        cell_registry = {}  # cell_label -> cell dict

        for source_idx, source_key in enumerate(source_keys):
            source = sources[source_key]

            # --- Top-level source metadata (animal info) ---
            source_attrs = _read_all_attrs(source)
            source_props = {}
            if 'properties' in source:
                source_props = _read_properties(source['properties'])

            animal_info = {
                'label': source_attrs.get('label', ''),
                'species': source_props.get('species', ''),
                'age': source_props.get('age', ''),
                'sex': source_props.get('sex', ''),
                'weight': source_props.get('weight', ''),
                'description': source_props.get('description', ''),
            }

            # Check for experiment subgroup (this is where epoch groups live)
            if 'experiment' not in source:
                continue

            exp_subgroup = source['experiment']

            # Find epoch groups
            if 'epochGroups' not in exp_subgroup:
                continue

            epoch_groups_grp = exp_subgroup['epochGroups']
            eg_keys = [k for k in epoch_groups_grp.keys() if k.startswith('epochGroup-')]

            for eg_key in eg_keys:
                eg_grp = epoch_groups_grp[eg_key]

                # --- Epoch group metadata ---
                eg_attrs = _read_all_attrs(eg_grp)
                eg_label = eg_attrs.get('label', eg_key)

                eg_properties = {}
                if 'properties' in eg_grp:
                    eg_properties = _read_properties(eg_grp['properties'])

                # --- Discover cell from epoch group's source reference ---
                cell_label, cell_type, cell_source_props = _find_cell_source(eg_grp)

                # Use cell_label as the key to group epoch groups under cells
                if not cell_label:
                    cell_label = f'Cell {source_idx + 1}'

                if cell_label not in cell_registry:
                    cell_registry[cell_label] = {
                        'id': len(cell_registry) + 1,
                        'label': cell_label,
                        'type': cell_type,
                        'properties': cell_source_props,
                        'animal_info': animal_info,
                        'noise_id': 0,
                        'rf_params': {},
                        'epoch_groups': []
                    }
                # Update type if we find it later
                if cell_type and not cell_registry[cell_label]['type']:
                    cell_registry[cell_label]['type'] = cell_type

                epoch_group = {
                    'id': hash(eg_key) % 100000,
                    'label': eg_label,
                    'protocol_name': '',
                    'start_time': eg_attrs.get('startTimeDotNetDateTimeOffsetTicks', ''),
                    'end_time': eg_attrs.get('endTimeDotNetDateTimeOffsetTicks', ''),
                    'recording_technique': eg_properties.get('recordingTechnique', ''),
                    'external_solution': eg_properties.get('externalSolutionAdditions', ''),
                    'internal_solution': eg_properties.get('internalSolutionAdditions', ''),
                    'pipette_solution': eg_properties.get('pipetteSolution', ''),
                    'series_resistance_comp': eg_properties.get('seriesResistanceCompensation', 0),
                    'epoch_blocks': []
                }

                # Find epoch blocks
                if 'epochBlocks' not in eg_grp:
                    cell_registry[cell_label]['epoch_groups'].append(epoch_group)
                    continue

                epoch_blocks_grp = eg_grp['epochBlocks']

                for eb_key in epoch_blocks_grp.keys():
                    eb_grp = epoch_blocks_grp[eb_key]

                    # --- Epoch block metadata ---
                    eb_attrs = _read_all_attrs(eb_grp)

                    # Protocol name: use protocolID attr if available, else parse from key
                    protocol_id = eb_attrs.get('protocolID', '')
                    if protocol_id:
                        # Full: edu.washington.riekelab.protocols.SingleSpot -> SingleSpot
                        protocol_name = protocol_id.split('.')[-1] if '.' in protocol_id else protocol_id
                    else:
                        protocol_name = eb_key.split('-')[0] if '-' in eb_key else eb_key

                    # Read protocol parameters from epoch block level
                    block_params = {}
                    if 'protocolParameters' in eb_grp:
                        block_params = _read_all_attrs(eb_grp['protocolParameters'])

                    # Read epoch block properties
                    eb_properties = {}
                    if 'properties' in eb_grp:
                        eb_properties = _read_properties(eb_grp['properties'])

                    epoch_block = {
                        'id': hash(eb_key) % 100000,
                        'label': eb_key,
                        'protocol_name': protocol_name,
                        'protocol_id': protocol_id,
                        'start_time': eb_attrs.get('startTimeDotNetDateTimeOffsetTicks', ''),
                        'end_time': eb_attrs.get('endTimeDotNetDateTimeOffsetTicks', ''),
                        'parameters': block_params,
                        'properties': eb_properties,
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

                        # --- Epoch-level metadata ---
                        ep_attrs = _read_all_attrs(ep_grp)

                        # Read epoch-level protocol parameters and combine with block params
                        epoch_params = dict(block_params)  # Start with block-level params
                        if 'protocolParameters' in ep_grp:
                            epoch_level = _read_all_attrs(ep_grp['protocolParameters'])
                            epoch_params.update(epoch_level)  # Epoch-level overrides block-level

                        # Read epoch properties (e.g., bathTemperature)
                        ep_properties = {}
                        if 'properties' in ep_grp:
                            ep_properties = _read_properties(ep_grp['properties'])

                        # --- Backgrounds (device states during epoch) ---
                        backgrounds = {}
                        if 'backgrounds' in ep_grp:
                            bg_grp = ep_grp['backgrounds']
                            for bg_key in bg_grp.keys():
                                bg = bg_grp[bg_key]
                                bg_attrs = _read_all_attrs(bg)
                                bg_name = bg_key.split('-')[0] if '-' in bg_key else bg_key
                                backgrounds[bg_name] = {
                                    'value': bg_attrs.get('value', 0.0),
                                    'units': bg_attrs.get('valueUnits', ''),
                                    'sample_rate': bg_attrs.get('sampleRate', 0.0),
                                }

                        epoch = {
                            'id': hash(ep_key) % 100000,
                            'label': ep_key,
                            'start_time': ep_attrs.get('startTimeDotNetDateTimeOffsetTicks', ''),
                            'end_time': ep_attrs.get('endTimeDotNetDateTimeOffsetTicks', ''),
                            'epoch_start_ms': 0.0,
                            'epoch_end_ms': 0.0,
                            'frame_times_ms': [],
                            'parameters': epoch_params,
                            'properties': ep_properties,
                            'backgrounds': backgrounds,
                            'responses': [],
                            'stimuli': []
                        }

                        # --- Responses ---
                        if 'responses' in ep_grp:
                            responses_grp = ep_grp['responses']

                            for resp_key in responses_grp.keys():
                                resp_grp = responses_grp[resp_key]
                                resp_attrs = _read_all_attrs(resp_grp)

                                # Extract device name from key
                                device_name = resp_key.split('-')[0] if '-' in resp_key else resp_key

                                # Get h5 path for lazy loading
                                h5_path = f'/{sources_path}/{source_key}/experiment/epochGroups/{eg_key}/epochBlocks/{eb_key}/epochs/{ep_key}/responses/{resp_key}'

                                # Read actual sample rate from response attrs
                                sample_rate = resp_attrs.get('sampleRate', 10000)

                                # Read units from the data dataset if available
                                units = 'mV'  # default
                                if 'data' in resp_grp:
                                    data_ds = resp_grp['data']
                                    # Compound dtype with 'quantity' and 'units' fields
                                    if data_ds.dtype.names and 'units' in data_ds.dtype.names:
                                        try:
                                            raw_unit = data_ds[0]['units']
                                            if isinstance(raw_unit, (bytes, np.bytes_)):
                                                units = raw_unit.decode('utf-8')
                                            elif isinstance(raw_unit, str):
                                                units = raw_unit
                                            else:
                                                units = str(raw_unit)
                                        except Exception:
                                            pass

                                # Read device info
                                device_info = {}
                                if 'device' in resp_grp:
                                    device_info = _read_all_attrs(resp_grp['device'])

                                response = {
                                    'id': hash(resp_key) % 100000,
                                    'device_name': device_name,
                                    'label': device_name,
                                    'data': np.array([]),  # Empty - will lazy load
                                    'spike_times': np.array([]),
                                    'sample_rate': sample_rate,
                                    'sample_rate_units': 'Hz',
                                    'units': units,
                                    'offset_ms': 0.0,
                                    'h5_path': h5_path,
                                    'device_info': device_info
                                }

                                epoch['responses'].append(response)

                        # --- Stimuli ---
                        if 'stimuli' in ep_grp:
                            stimuli_grp = ep_grp['stimuli']

                            for stim_key in stimuli_grp.keys():
                                stim_grp = stimuli_grp[stim_key]
                                stim_attrs = _read_all_attrs(stim_grp)

                                stim_name = stim_key.split('-')[0] if '-' in stim_key else stim_key

                                # Read stimulus parameters
                                stim_params = {}
                                if 'parameters' in stim_grp:
                                    stim_params = _read_all_attrs(stim_grp['parameters'])
                                    # Also read child groups/datasets
                                    for pk in stim_grp['parameters'].keys():
                                        item = stim_grp['parameters'][pk]
                                        if isinstance(item, h5py.Dataset):
                                            try:
                                                stim_params[pk] = _convert_h5_attr(item[()])
                                            except Exception:
                                                pass

                                stimulus = {
                                    'device_name': stim_name,
                                    'stimulus_id': stim_attrs.get('stimulusID', ''),
                                    'duration_seconds': stim_attrs.get('durationSeconds', 0.0),
                                    'units': stim_attrs.get('units', ''),
                                    'parameters': stim_params,
                                }

                                epoch['stimuli'].append(stimulus)

                        epoch_block['epochs'].append(epoch)

                    if epoch_block['epochs']:
                        epoch_group['epoch_blocks'].append(epoch_block)

                if epoch_group['epoch_blocks']:
                    cell_registry[cell_label]['epoch_groups'].append(epoch_group)

        # Convert cell_registry to list
        experiment['cells'] = list(cell_registry.values())

    # Count epochs
    total_epochs = 0
    for cell in experiment['cells']:
        for eg in cell['epoch_groups']:
            for eb in eg['epoch_blocks']:
                total_epochs += len(eb['epochs'])

    # Print summary
    print(f"Found {len(experiment['cells'])} cells, {total_epochs} epochs")
    for cell in experiment['cells']:
        n_eg = len(cell['epoch_groups'])
        n_ep = sum(len(eb['epochs']) for eg in cell['epoch_groups'] for eb in eg['epoch_blocks'])
        print(f"  {cell['label']} ({cell['type']}): {n_eg} groups, {n_ep} epochs")

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

    # Sanitize all values for scipy.io.savemat compatibility
    export_data = _sanitize_for_mat(export_data)

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
