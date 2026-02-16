#!/usr/bin/env python3
"""
Export RetinAnalysis data with full cell type names

This script exports your existing MEA data with cell types converted
from shorthand (OnP, OffP) to full names (RGC\ON-parasol, RGC\OFF-parasol).
"""

import sys
import os

# Add retinanalysis to path
sys.path.append('/Users/maxwellsdm/Documents/GitHub/epicTreeGUI/new_retinanalysis/src')

try:
    import retinanalysis as ra
    from retinanalysis.utils.matlab_export import export_pipeline_to_matlab
    print("✓ RetinAnalysis imported successfully")
except ImportError as e:
    print(f"ERROR: Could not import retinanalysis: {e}")
    sys.exit(1)


def main():
    print("="*70)
    print("Exporting MEA Data with Full Cell Type Names")
    print("="*70)
    print()

    # Configuration
    exp_name = '2025-12-02_F'
    data_name = 'data000'  # Adjust if needed
    output_file = '/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F_with_full_names.mat'

    print(f"Experiment: {exp_name}")
    print(f"Data: {data_name}")
    print(f"Output: {output_file}")
    print()

    # Create pipeline
    print("Creating MEA pipeline...")
    try:
        pipeline = ra.create_mea_pipeline(exp_name, data_name)
        print(f"✓ Pipeline created")
        print(f"  Experiment: {pipeline.response_block.exp_name}")
        print(f"  Protocol: {pipeline.stim_block.protocol_name}")
        print(f"  Epochs: {pipeline.response_block.n_epochs}")
    except Exception as e:
        print(f"ERROR creating pipeline: {e}")
        sys.exit(1)

    # Check cell types in pipeline
    print()
    print("Cell types in pipeline:")
    print("-"*70)
    df = pipeline.response_block.df_spike_times
    cell_types = df['cell_type'].unique()
    for ct in sorted(cell_types):
        count = (df['cell_type'] == ct).sum()
        print(f"  {ct:15s} - {count} cells")

    # Export with full names
    print()
    print("="*70)
    print("Exporting to MATLAB format...")
    print("="*70)
    print()
    print("NOTE: Cell types will be converted:")
    print("  OnP  → RGC\\ON-parasol")
    print("  OffP → RGC\\OFF-parasol")
    print("  OnM  → RGC\\ON-midget")
    print("  OffM → RGC\\OFF-midget")
    print("  etc.")
    print()

    try:
        export_pipeline_to_matlab(
            pipeline,
            output_file,
            format='mat'
        )
        print()
        print("="*70)
        print("✓✓✓ Export Complete! ✓✓✓")
        print("="*70)
        print()
        print(f"File saved: {output_file}")
        print()
        print("Next steps:")
        print("  1. In MATLAB, run:")
        print(f"     [data, ~] = loadEpicTreeData('{output_file}');")
        print("     tree = epicTreeTools(data);")
        print("     tree.buildTreeWithSplitters({@epicTreeTools.splitOnCellType});")
        print("     gui = epicTreeGUI(tree);")
        print()
        print("  2. Check that cell types show as:")
        print("     RGC\\ON-parasol, RGC\\OFF-parasol, etc.")
        print()

    except Exception as e:
        print(f"ERROR during export: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
