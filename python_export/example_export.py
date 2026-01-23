"""
Example script demonstrating how to export MEAPipeline data to MATLAB format.

This script shows:
1. How to create an MEAPipeline
2. How to export to .mat format (full export)
3. How to export with filters (cell types, specific cells, specific epochs)
4. How to export to JSON format
5. How to verify the export
"""

import sys
import os

# Add retinanalysis to path if needed
# sys.path.insert(0, '/path/to/new_retinanalysis/src')

import retinanalysis as ra
from retinanalysis.utils.matlab_export import export_pipeline_to_matlab, print_export_summary

def main():
    """
    Main export example.

    Replace exp_name and datafile_name with your actual experiment data.
    """

    # ========================================
    # 1. Create MEAPipeline
    # ========================================
    print("=" * 60)
    print("STEP 1: Creating MEAPipeline")
    print("=" * 60)

    # Replace these with your actual experiment name and datafile
    exp_name = '20250115A'  # Example: your experiment name
    datafile_name = 'data000'  # Example: your protocol datafile

    # Create pipeline (this loads spike times, stimulus params, RF params)
    pipeline = ra.create_mea_pipeline(exp_name, datafile_name)

    print(f"\nPipeline created successfully!")
    print(f"  Cells: {pipeline.response_block.num_cells}")
    print(f"  Epochs: {pipeline.response_block.n_epochs}")
    print(f"  Protocol: {pipeline.stim_block.protocol_name}")

    # ========================================
    # 2. Full Export to MAT format
    # ========================================
    print("\n" + "=" * 60)
    print("STEP 2: Full Export to MAT format")
    print("=" * 60)

    output_dir = os.path.join(os.getcwd(), 'matlab_exports')
    os.makedirs(output_dir, exist_ok=True)

    mat_file = os.path.join(output_dir, f'{exp_name}_{datafile_name}_full.mat')
    export_pipeline_to_matlab(pipeline, mat_file, format='mat')

    # ========================================
    # 3. Filtered Export (specific cell types)
    # ========================================
    print("\n" + "=" * 60)
    print("STEP 3: Filtered Export (OnP and OffP cells only)")
    print("=" * 60)

    mat_file_filtered = os.path.join(output_dir, f'{exp_name}_{datafile_name}_OnOffP.mat')
    export_pipeline_to_matlab(
        pipeline,
        mat_file_filtered,
        format='mat',
        cell_types=['OnP', 'OffP']  # Only export OnP and OffP cells
    )

    # ========================================
    # 4. Export specific epochs
    # ========================================
    print("\n" + "=" * 60)
    print("STEP 4: Export first 10 epochs only")
    print("=" * 60)

    mat_file_epochs = os.path.join(output_dir, f'{exp_name}_{datafile_name}_first10.mat')
    export_pipeline_to_matlab(
        pipeline,
        mat_file_epochs,
        format='mat',
        epoch_indices=list(range(10))  # Only first 10 epochs
    )

    # ========================================
    # 5. Export to JSON (for inspection)
    # ========================================
    print("\n" + "=" * 60)
    print("STEP 5: Export to JSON format")
    print("=" * 60)

    json_file = os.path.join(output_dir, f'{exp_name}_{datafile_name}_full.json')
    export_pipeline_to_matlab(pipeline, json_file, format='json')

    # ========================================
    # 6. Verify exports
    # ========================================
    print("\n" + "=" * 60)
    print("STEP 6: Verify Exports")
    print("=" * 60)

    print_export_summary(mat_file)

    # ========================================
    # Summary
    # ========================================
    print("\n" + "=" * 60)
    print("EXPORT COMPLETE!")
    print("=" * 60)
    print(f"\nFiles created in: {output_dir}")
    print(f"  1. {os.path.basename(mat_file)} - Full export")
    print(f"  2. {os.path.basename(mat_file_filtered)} - OnP/OffP only")
    print(f"  3. {os.path.basename(mat_file_epochs)} - First 10 epochs")
    print(f"  4. {os.path.basename(json_file)} - JSON format")

    print("\nNext steps:")
    print("  1. Open MATLAB")
    print(f"  2. Load the data: data = load('{mat_file}');")
    print("  3. Inspect the data: disp(fieldnames(data))")
    print("  4. Access spike times: data.spike_times.cell_<ID>.spike_times")
    print("  5. Access RF params: data.rf_params.noise_<ID>")


if __name__ == '__main__':
    main()
