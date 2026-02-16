#!/usr/bin/env python3
"""
Add Cell Type Classification to Existing Export

This script loads an existing .mat file export and adds more specific
cell type classification (ON-parasol, OFF-parasol, etc.) based on:
1. RF center diameter
2. Response polarity (ON vs OFF)
3. Manual classification rules

Usage:
    python add_cell_type_classification.py input.mat output.mat
"""

import scipy.io
import numpy as np
import sys
import os


def classify_rgc_subtype(cell_data, rf_params=None):
    """
    Classify RGC into specific subtype based on available data.

    Parameters:
        cell_data: Cell information dict
        rf_params: Optional RF parameters for this cell

    Returns:
        str: Specific cell type like 'RGC\\ON-parasol', 'RGC\\OFF-parasol', etc.
    """

    # Default to generic RGC
    cell_type = 'RGC'

    # Strategy 1: Use RF parameters if available
    if rf_params is not None:
        center_diam = rf_params.get('center_diameter_um', None)
        polarity = rf_params.get('polarity', None)

        if center_diam is not None and polarity is not None:
            # Classification based on center diameter
            # Parasol: Large RF center (> 150-200 μm depending on eccentricity)
            # Midget: Small RF center (< 150 μm)

            if center_diam > 180:
                cell_class = 'parasol'
            elif center_diam < 150:
                cell_class = 'midget'
            else:
                cell_class = 'RGC'  # Ambiguous size

            # Add ON/OFF polarity
            if isinstance(polarity, str):
                pol_str = polarity.upper()
            elif polarity > 0:
                pol_str = 'ON'
            elif polarity < 0:
                pol_str = 'OFF'
            else:
                pol_str = ''

            if cell_class in ['parasol', 'midget'] and pol_str in ['ON', 'OFF']:
                cell_type = f'RGC\\{pol_str}-{cell_class}'
                return cell_type

    # Strategy 2: Use cell_type from data if it's already specific
    if 'type' in cell_data:
        existing_type = cell_data['type']
        if existing_type and existing_type != 'RGC':
            return existing_type

    # Strategy 3: Use keywords if present
    if 'keywords' in cell_data:
        keywords = cell_data['keywords']
        if isinstance(keywords, (list, np.ndarray)):
            kw_str = ' '.join([str(k).lower() for k in keywords])
        else:
            kw_str = str(keywords).lower()

        if 'onparasol' in kw_str or 'on-parasol' in kw_str:
            return 'RGC\\ON-parasol'
        elif 'offparasol' in kw_str or 'off-parasol' in kw_str:
            return 'RGC\\OFF-parasol'
        elif 'onmidget' in kw_str or 'on-midget' in kw_str:
            return 'RGC\\ON-midget'
        elif 'offmidget' in kw_str or 'off-midget' in kw_str:
            return 'RGC\\OFF-midget'

    # If we got here, return generic RGC
    return 'RGC\\unclassified'


def add_cell_types_to_export(input_file, output_file, classification_rules=None):
    """
    Load existing export, classify cells, and save enhanced version.

    Parameters:
        input_file (str): Path to input .mat file
        output_file (str): Path to output .mat file
        classification_rules (dict): Optional manual classification rules
            Example: {cell_id: 'RGC\\ON-parasol', ...}
    """

    print(f"Loading data from {input_file}...")
    data = scipy.io.loadmat(input_file, struct_as_record=False, squeeze_me=True)

    # Check if this is the hierarchical export format
    if 'export_data' in data:
        export_data = data['export_data']
    elif 'format_version' in data:
        # Already in the right format
        export_data = data
    else:
        print("ERROR: Unknown file format")
        return

    print(f"Format version: {export_data.get('format_version', 'unknown')}")

    # Get experiments
    if hasattr(export_data, 'experiments'):
        experiments = export_data.experiments
    elif 'experiments' in export_data:
        experiments = export_data['experiments']
    else:
        print("ERROR: No experiments found")
        return

    # Process each experiment
    total_cells = 0
    total_epochs = 0
    cell_type_counts = {}

    if not isinstance(experiments, (list, np.ndarray)):
        experiments = [experiments]

    for exp_idx, exp in enumerate(experiments):
        print(f"\nProcessing experiment {exp_idx + 1}...")

        cells = exp.cells if hasattr(exp, 'cells') else exp['cells']
        if not isinstance(cells, (list, np.ndarray)):
            cells = [cells]

        for cell_idx, cell in enumerate(cells):
            total_cells += 1

            # Get cell info
            cell_info = cell.cellInfo if hasattr(cell, 'cellInfo') else cell['cellInfo']
            cell_id = cell_info.id if hasattr(cell_info, 'id') else cell_info['id']

            # Check for manual classification rule
            if classification_rules and cell_id in classification_rules:
                new_type = classification_rules[cell_id]
                print(f"  Cell {cell_id}: Manual classification → {new_type}")
            else:
                # Classify based on available data
                # TODO: Add RF params if available
                rf_params = None  # Would come from cell.rf_analysis if present

                new_type = classify_rgc_subtype(
                    {'type': cell_info.type if hasattr(cell_info, 'type') else cell_info.get('type')},
                    rf_params=rf_params
                )

                print(f"  Cell {cell_id}: Auto-classified → {new_type}")

            # Update cell type in all epochs from this cell
            cell_info_dict = {
                'id': str(cell_id),
                'type': new_type,
                'label': str(cell_info.label if hasattr(cell_info, 'label') else cell_info.get('label', f'Cell {cell_id}'))
            }

            # Count cell types
            cell_type_counts[new_type] = cell_type_counts.get(new_type, 0) + 1

            # Update epochs (navigate through hierarchy)
            epoch_groups = cell.epoch_groups if hasattr(cell, 'epoch_groups') else cell['epoch_groups']
            if not isinstance(epoch_groups, (list, np.ndarray)):
                epoch_groups = [epoch_groups]

            for grp in epoch_groups:
                epoch_blocks = grp.epoch_blocks if hasattr(grp, 'epoch_blocks') else grp['epoch_blocks']
                if not isinstance(epoch_blocks, (list, np.ndarray)):
                    epoch_blocks = [epoch_blocks]

                for block in epoch_blocks:
                    epochs = block.epochs if hasattr(block, 'epochs') else block['epochs']
                    if not isinstance(epochs, (list, np.ndarray)):
                        epochs = [epochs]

                    for epoch in epochs:
                        total_epochs += 1
                        # Update cellInfo in this epoch
                        if hasattr(epoch, 'cellInfo'):
                            epoch.cellInfo = type('obj', (object,), cell_info_dict)
                        elif 'cellInfo' in epoch:
                            epoch['cellInfo'] = cell_info_dict

    # Save enhanced export
    print(f"\n{'='*60}")
    print(f"Classification Summary:")
    print(f"  Total cells: {total_cells}")
    print(f"  Total epochs: {total_epochs}")
    print(f"\nCell type distribution:")
    for cell_type, count in sorted(cell_type_counts.items()):
        print(f"  {cell_type}: {count} cells")

    print(f"\nSaving to {output_file}...")
    scipy.io.savemat(output_file, data, do_compression=True)
    print(f"✓ Enhanced export saved!")


def main():
    if len(sys.argv) < 2:
        print("Usage: python add_cell_type_classification.py input.mat [output.mat]")
        print("\nExample:")
        print("  python add_cell_type_classification.py data.mat data_with_types.mat")
        sys.exit(1)

    input_file = sys.argv[1]
    if not os.path.exists(input_file):
        print(f"ERROR: File not found: {input_file}")
        sys.exit(1)

    # Default output file
    if len(sys.argv) >= 3:
        output_file = sys.argv[2]
    else:
        base, ext = os.path.splitext(input_file)
        output_file = f"{base}_with_cell_types{ext}"

    # Optional: Add manual classification rules
    # classification_rules = {
    #     'cell_001': 'RGC\\ON-parasol',
    #     'cell_002': 'RGC\\OFF-midget',
    # }
    classification_rules = None

    add_cell_types_to_export(input_file, output_file, classification_rules)


if __name__ == '__main__':
    main()
