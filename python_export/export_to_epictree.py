#!/usr/bin/env python3
"""
Export DataJoint Query Results to EpicTreeGUI Standard Format

This script queries the DataJoint database, extracts epoch data from H5 files,
and exports everything to a standardized .mat file that EpicTreeGUI can read.

Usage:
    python export_to_epictree.py

The script will prompt for query parameters and output file name.
"""

import sys
import os
import json
from datetime import datetime
from typing import Dict, List, Any, Optional
import numpy as np

# Add datajoint API to path
sys.path.append('/Users/maxwellsdm/Documents/GitHub/datajoint/next-app/api')

try:
    import datajoint as dj
    import h5py
    import scipy.io
    from helpers.query import (create_query, generate_tree, get_options,
                               fill_tables, get_data_generic)
    from helpers.utils import NAS_DATA_DIR
except ImportError as e:
    print(f"Error importing required modules: {e}")
    print("Make sure datajoint, h5py, and scipy are installed:")
    print("  pip install datajoint h5py scipy")
    sys.exit(1)

# Import cell type name mapping
try:
    from cell_type_names import get_full_cell_type_name
except ImportError:
    # Fallback if file not found
    def get_full_cell_type_name(shorthand, prefix_rgc=True):
        return shorthand


class EpicTreeExporter:
    """Export DataJoint query results to EpicTreeGUI standard format."""

    def __init__(self, username: str, db: dj.VirtualModule):
        """
        Initialize exporter.

        Args:
            username: Database username
            db: DataJoint virtual module
        """
        self.username = username
        self.db = db
        fill_tables(username, db)

    def export_query_to_mat(self, query_obj: Dict, output_file: str,
                            exclude_levels: Optional[List[str]] = None,
                            verbose: bool = True):
        """
        Export query results to .mat file in EpicTreeGUI standard format.

        Args:
            query_obj: DataJoint query object (see create_query documentation)
            output_file: Output .mat file path
            exclude_levels: Optional list of hierarchy levels to exclude
            verbose: Print progress messages
        """
        if exclude_levels is None:
            exclude_levels = []

        if verbose:
            print("Creating DataJoint query...")

        # Create and execute query
        query = create_query(query_obj, self.username, self.db)

        if len(query) == 0:
            print(f"Query returned 0 results!")
            return

        if verbose:
            print(f"Query returned {len(query)} results")
            print("Generating result tree (this may take a while)...")

        # Generate full tree with metadata
        results = generate_tree(query, exclude_levels, include_meta=True)

        if verbose:
            print(f"Processing {len(results)} experiments...")

        # Build standard format
        experiments = []

        for i, exp_node in enumerate(results):
            if verbose:
                print(f"  Processing experiment {i+1}/{len(results)}: {exp_node.get('label', 'N/A')}")

            experiment = self._build_experiment(exp_node, verbose)
            experiments.append(experiment)

        # Create export data structure
        export_data = {
            'format_version': '1.0',
            'metadata': {
                'created_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'data_source': 'DataJoint + H5 files',
                'source_database': str(self.db),
                'export_user': self.username,
                'query_object': json.dumps(query_obj),
                'num_experiments': len(experiments)
            },
            'experiments': experiments
        }

        # Save to .mat file
        if verbose:
            print(f"\nSaving to {output_file}...")

        scipy.io.savemat(output_file, export_data, do_compression=True)

        if verbose:
            print(f"✓ Export complete!")
            self._print_summary(export_data)

    def _build_experiment(self, exp_node: Dict, verbose: bool = False) -> Dict:
        """Build experiment structure from tree node."""
        exp_obj = exp_node['object'][0] if 'object' in exp_node else {}

        experiment = {
            'id': int(exp_node['id']),
            'exp_name': str(exp_obj.get('exp_name', '')),
            'label': str(exp_node.get('label', '')),
            'is_mea': bool(exp_node.get('is_mea', False)),
            'start_time': self._convert_datetime(exp_obj.get('start_time')),
            'experimenter': str(exp_obj.get('experimenter', '')),
            'rig': str(exp_obj.get('rig', '')),
            'institution': str(exp_obj.get('institution', '')),
            'lab': str(exp_obj.get('lab', '')),
            'cells': []
        }

        # Get children (skip Animal and Preparation if excluded)
        children = exp_node.get('children', [])

        # Navigate through hierarchy to cells
        cell_nodes = self._get_cell_nodes(children)

        for cell_node in cell_nodes:
            cell = self._build_cell(cell_node, experiment['id'], experiment['is_mea'], verbose)
            experiment['cells'].append(cell)

        return experiment

    def _get_cell_nodes(self, children: List[Dict]) -> List[Dict]:
        """Navigate hierarchy to find cell nodes."""
        if not children:
            return []

        # Check if children are cells
        if children[0].get('level') == 'cell':
            return children

        # Otherwise, recurse through children
        cell_nodes = []
        for child in children:
            cell_nodes.extend(self._get_cell_nodes(child.get('children', [])))

        return cell_nodes

    def _build_cell(self, cell_node: Dict, experiment_id: int,
                    is_mea: bool, verbose: bool = False) -> Dict:
        """Build cell structure from tree node."""
        cell_obj = cell_node['object'][0] if 'object' in cell_node else {}

        # Get cell type and convert shorthand to full name
        cell_type_raw = str(cell_obj.get('type', ''))
        cell_type_full = get_full_cell_type_name(cell_type_raw, prefix_rgc=True)

        cell = {
            'id': int(cell_node['id']),
            'label': str(cell_node.get('label', '')),
            'type': cell_type_full,  # Use full name instead of shorthand
            'properties': cell_obj.get('properties', {}),
            'noise_id': 0,  # TODO: Get from matching
            'rf_params': {},  # TODO: Get from analysis
            'epoch_groups': []
        }

        # Process epoch groups
        for eg_node in cell_node.get('children', []):
            epoch_group = self._build_epoch_group(eg_node, experiment_id, is_mea, verbose)
            cell['epoch_groups'].append(epoch_group)

        return cell

    def _build_epoch_group(self, eg_node: Dict, experiment_id: int,
                          is_mea: bool, verbose: bool = False) -> Dict:
        """Build epoch group structure from tree node."""
        eg_obj = eg_node['object'][0] if 'object' in eg_node else {}

        epoch_group = {
            'id': int(eg_node['id']),
            'label': str(eg_node.get('label', '')),
            'protocol_name': str(eg_node.get('protocol', '')),
            'start_time': self._convert_datetime(eg_obj.get('start_time')),
            'end_time': self._convert_datetime(eg_obj.get('end_time')),
            'epoch_blocks': []
        }

        # Process epoch blocks
        for eb_node in eg_node.get('children', []):
            epoch_block = self._build_epoch_block(eb_node, experiment_id, is_mea, verbose)
            epoch_group['epoch_blocks'].append(epoch_block)

        return epoch_group

    def _build_epoch_block(self, eb_node: Dict, experiment_id: int,
                          is_mea: bool, verbose: bool = False) -> Dict:
        """Build epoch block structure from tree node."""
        eb_obj = eb_node['object'][0] if 'object' in eb_node else {}

        epoch_block = {
            'id': int(eb_node['id']),
            'label': str(eb_node.get('label', '')),
            'protocol_name': str(eb_node.get('protocol', '')),
            'start_time': self._convert_datetime(eb_obj.get('start_time')),
            'end_time': self._convert_datetime(eb_obj.get('end_time')),
            'parameters': eb_obj.get('parameters', {}),
            'data_dir': str(eb_obj.get('data_dir', '')),
            'epochs': []
        }

        # Process epochs
        epochs = eb_node.get('children', [])

        if verbose and len(epochs) > 10:
            print(f"    Processing {len(epochs)} epochs in block {eb_node['id']}...")

        for epoch_node in epochs:
            epoch = self._build_epoch(epoch_node, experiment_id, is_mea)
            epoch_block['epochs'].append(epoch)

        return epoch_block

    def _build_epoch(self, epoch_node: Dict, experiment_id: int,
                    is_mea: bool) -> Dict:
        """Build epoch structure with actual data from H5 files."""
        epoch_obj = epoch_node['object'][0] if 'object' in epoch_node else {}

        epoch = {
            'id': int(epoch_node['id']),
            'label': str(epoch_node.get('label', '')),
            'start_time': self._convert_datetime(epoch_obj.get('start_time')),
            'end_time': self._convert_datetime(epoch_obj.get('end_time')),
            'epoch_start_ms': 0.0,  # TODO: Extract from timing data
            'epoch_end_ms': 0.0,
            'frame_times_ms': [],
            'parameters': epoch_obj.get('parameters', {}),
            'responses': [],
            'stimuli': []
        }

        # Get H5 data for this epoch (only for patch data, not MEA)
        if not is_mea:
            try:
                options = get_options('epoch', epoch['id'], experiment_id)

                if options:
                    # Process responses
                    for response_data in options.get('responses', []):
                        response = self._extract_response_data(response_data)
                        if response:
                            epoch['responses'].append(response)

                    # Process stimuli
                    for stimulus_data in options.get('stimuli', []):
                        stimulus = self._extract_stimulus_data(stimulus_data)
                        if stimulus:
                            epoch['stimuli'].append(stimulus)
            except Exception as e:
                print(f"Warning: Could not extract data for epoch {epoch['id']}: {e}")

        # For MEA data, responses come from sorted spike data
        # TODO: Implement MEA data extraction

        return epoch

    def _extract_response_data(self, response_data: Dict) -> Optional[Dict]:
        """
        Extract response data from H5 file and include in export.

        The actual data is read from H5 and stored in the .mat file so
        no H5 access is needed at runtime in MATLAB.
        """
        h5_file = response_data.get('h5_file')
        h5_path = response_data.get('h5_path')
        device_name = str(response_data.get('label', ''))

        if not h5_file or not h5_path:
            print(f"    Warning: No H5 path for response {device_name}")
            return None

        # Default values
        data = np.array([])
        sample_rate = 10000
        units = 'unknown'

        # Try to read data from H5 file
        if os.path.exists(h5_file):
            try:
                with h5py.File(h5_file, 'r') as f:
                    # Clean h5_path (remove leading slash)
                    clean_path = h5_path.lstrip('/')

                    if clean_path in f:
                        epoch_group = f[clean_path]

                        if 'data' in epoch_group:
                            data_group = epoch_group['data']

                            # Read the actual data
                            if 'quantity' in data_group:
                                data = np.array(data_group['quantity'][:]).flatten()

                            # Get sample rate
                            if 'sampleRate' in data_group.attrs:
                                sample_rate = float(data_group.attrs['sampleRate'])

                            # Get units
                            if 'units' in data_group.attrs:
                                units = str(data_group.attrs['units'])
                    else:
                        print(f"    Warning: Path {clean_path} not found in H5")

            except Exception as e:
                print(f"    Warning: Error reading H5 for {device_name}: {e}")
        else:
            print(f"    Warning: H5 file not found: {h5_file}")

        # Create response struct with data included
        response = {
            'device_name': device_name,
            'data': data,  # Actual data from H5, not lazy loaded
            'spike_times': np.array([]),
            'sample_rate': sample_rate,
            'sample_rate_units': 'Hz',
            'units': units,
            'offset_ms': 0.0
        }

        return response

    def _extract_stimulus_data(self, stimulus_data: Dict) -> Optional[Dict]:
        """
        Extract stimulus data from H5 file and include in export.
        """
        h5_file = stimulus_data.get('h5_file')
        h5_path = stimulus_data.get('h5_path')
        device_name = str(stimulus_data.get('label', ''))

        if not h5_file or not h5_path:
            return None

        # Default values
        data = np.array([])
        sample_rate = 10000
        units = 'normalized'

        # Try to read data from H5 file
        if os.path.exists(h5_file):
            try:
                with h5py.File(h5_file, 'r') as f:
                    clean_path = h5_path.lstrip('/')
                    if clean_path in f:
                        epoch_group = f[clean_path]
                        if 'data' in epoch_group:
                            data_group = epoch_group['data']

                            # Read the actual data
                            if 'quantity' in data_group:
                                data = np.array(data_group['quantity'][:]).flatten()

                            if 'sampleRate' in data_group.attrs:
                                sample_rate = float(data_group.attrs['sampleRate'])
                            if 'units' in data_group.attrs:
                                units = str(data_group.attrs['units'])
            except Exception:
                pass  # Use defaults

        stimulus = {
            'device_name': device_name,
            'data': data,  # Actual data from H5
            'sample_rate': sample_rate,
            'units': units
        }

        return stimulus

    def _extract_stimulus_data_UNUSED(self, stimulus_data: Dict) -> Optional[Dict]:
        """UNUSED: Old implementation - kept for reference."""
        h5_file = stimulus_data.get('h5_file')
        h5_path = stimulus_data.get('h5_path')

        if not h5_file or not h5_path:
            return None

        try:
            with h5py.File(h5_file, 'r') as f:
                if h5_path not in f:
                    return None

                epoch_group = f[h5_path]

                # Extract data
                data = []
                sample_rate = 10000  # Default
                units = 'normalized'

                if 'data' in epoch_group:
                    data_group = epoch_group['data']

                    if 'quantity' in data_group:
                        data = data_group['quantity'][:].flatten().tolist()

                    if 'sampleRate' in data_group.attrs:
                        sample_rate = float(data_group.attrs['sampleRate'])

                    if 'units' in data_group.attrs:
                        units = str(data_group.attrs['units'])

                stimulus = {
                    'device_name': str(stimulus_data.get('label', '')),
                    'data': data,
                    'sample_rate': sample_rate,
                    'units': units
                }

                return stimulus

        except Exception as e:
            print(f"Warning: Could not read stimulus data from {h5_path}: {e}")
            return None

    def _convert_datetime(self, dt) -> str:
        """Convert datetime to string."""
        if dt is None:
            return ''
        if isinstance(dt, str):
            return dt
        return str(dt)

    def _print_summary(self, export_data: Dict):
        """Print summary of exported data."""
        print("\n" + "="*60)
        print("EXPORT SUMMARY")
        print("="*60)

        metadata = export_data['metadata']
        print(f"Format Version: {export_data['format_version']}")
        print(f"Created: {metadata['created_date']}")
        print(f"User: {metadata['export_user']}")
        print(f"Data Source: {metadata['data_source']}")
        print(f"\nExperiments: {metadata['num_experiments']}")

        # Count totals
        total_cells = 0
        total_epochs = 0

        for exp in export_data['experiments']:
            total_cells += len(exp['cells'])
            for cell in exp['cells']:
                for eg in cell['epoch_groups']:
                    for eb in eg['epoch_blocks']:
                        total_epochs += len(eb['epochs'])

        print(f"Total Cells: {total_cells}")
        print(f"Total Epochs: {total_epochs}")
        print("="*60 + "\n")


def interactive_export():
    """Interactive mode for exporting data."""
    print("="*60)
    print("EpicTreeGUI Data Exporter")
    print("="*60)

    # Connect to database
    print("\nConnecting to database...")
    try:
        db = dj.VirtualModule('schema.py', 'schema')
        print("✓ Connected to database")
    except Exception as e:
        print(f"✗ Error connecting to database: {e}")
        return

    # Get username
    username = input("\nEnter username [guest]: ").strip() or 'guest'

    # Create exporter
    exporter = EpicTreeExporter(username, db)

    # Get query parameters
    print("\nQuery Configuration")
    print("-" * 60)

    exp_name = input("Experiment name (or press Enter for all): ").strip()
    cell_type = input("Cell type (or press Enter for all): ").strip()
    protocol_name = input("Protocol name (or press Enter for all): ").strip()

    # Build query object
    query_obj = {}

    if exp_name:
        query_obj['experiment'] = {'COND': {'type': 'COND', 'value': f'exp_name="{exp_name}"'}}

    if cell_type:
        query_obj['cell'] = {'COND': {'type': 'COND', 'value': f'type="{cell_type}"'}}

    if protocol_name:
        query_obj['epoch_block'] = {'COND': {'type': 'COND', 'value': f'protocol_name="{protocol_name}"'}}

    # Get output file
    default_output = f"epictree_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mat"
    output_file = input(f"\nOutput file [{default_output}]: ").strip() or default_output

    # Export
    print(f"\nStarting export...")
    try:
        exporter.export_query_to_mat(query_obj, output_file, verbose=True)
    except Exception as e:
        print(f"\n✗ Export failed: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    interactive_export()
