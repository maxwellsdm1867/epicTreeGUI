#!/usr/bin/env python3
"""
Test Cell Type Name Conversion

This script tests the conversion from RetinAnalysis shorthand cell types
to full descriptive names for MATLAB epicTreeGUI.
"""

import sys
from cell_type_names import get_full_cell_type_name, convert_cell_types_to_full_names


def test_individual_conversions():
    """Test individual cell type conversions."""

    print("="*70)
    print("Testing Individual Cell Type Conversions")
    print("="*70)

    test_cases = [
        # (shorthand, expected_with_prefix, expected_without_prefix)
        ('OnP', 'RGC\\ON-parasol', 'ON-parasol'),
        ('OffP', 'RGC\\OFF-parasol', 'OFF-parasol'),
        ('OnM', 'RGC\\ON-midget', 'ON-midget'),
        ('OffM', 'RGC\\OFF-midget', 'OFF-midget'),
        ('BlueOffM', 'RGC\\Blue OFF-midget', 'Blue OFF-midget'),
        ('SBC', 'RGC\\small-bistratified', 'small-bistratified'),
        ('OnS', 'RGC\\ON-stratified', 'ON-stratified'),
        ('OffS', 'RGC\\OFF-stratified', 'OFF-stratified'),
        ('RB', 'rod-bipolar', 'rod-bipolar'),
        ('OnAmacrine', 'ON-amacrine', 'ON-amacrine'),
        ('OffAmacrine', 'OFF-amacrine', 'OFF-amacrine'),
        ('Tufted', 'RGC\\tufted', 'tufted'),
        ('RGC', 'RGC', 'RGC'),
        ('UnknownType', 'UnknownType', 'UnknownType'),
    ]

    all_passed = True

    print("\nWith RGC prefix (prefix_rgc=True):")
    print("-" * 70)
    for shorthand, expected_with, _ in test_cases:
        result = get_full_cell_type_name(shorthand, prefix_rgc=True)
        status = "✓" if result == expected_with else "✗"
        if result != expected_with:
            all_passed = False
        print(f"{status} {shorthand:15s} → {result:30s} (expected: {expected_with})")

    print("\nWithout RGC prefix (prefix_rgc=False):")
    print("-" * 70)
    for shorthand, _, expected_without in test_cases:
        result = get_full_cell_type_name(shorthand, prefix_rgc=False)
        status = "✓" if result == expected_without else "✗"
        if result != expected_without:
            all_passed = False
        print(f"{status} {shorthand:15s} → {result:30s} (expected: {expected_without})")

    return all_passed


def test_batch_conversion():
    """Test batch conversion of cell type lists."""

    print("\n" + "="*70)
    print("Testing Batch Conversion")
    print("="*70)

    # Test data
    shorthand_types = ['OnP', 'OffP', 'OnM', 'OffM', 'RB', 'OnAmacrine']
    expected_full = [
        'RGC\\ON-parasol',
        'RGC\\OFF-parasol',
        'RGC\\ON-midget',
        'RGC\\OFF-midget',
        'rod-bipolar',
        'ON-amacrine'
    ]

    # Convert
    result = convert_cell_types_to_full_names(shorthand_types, prefix_rgc=True)

    # Check
    all_passed = True
    print("\nBatch conversion results:")
    print("-" * 70)
    for short, full, expected in zip(shorthand_types, result, expected_full):
        status = "✓" if full == expected else "✗"
        if full != expected:
            all_passed = False
        print(f"{status} {short:15s} → {full:30s}")

    if all_passed:
        print("\n✓ All batch conversions passed!")
    else:
        print("\n✗ Some batch conversions failed!")

    return all_passed


def test_with_numpy():
    """Test conversion with numpy arrays (if numpy available)."""

    try:
        import numpy as np

        print("\n" + "="*70)
        print("Testing with NumPy Arrays")
        print("="*70)

        # Create numpy array
        types_array = np.array(['OnP', 'OffP', 'OnM'])
        result = convert_cell_types_to_full_names(types_array, prefix_rgc=True)

        expected = ['RGC\\ON-parasol', 'RGC\\OFF-parasol', 'RGC\\ON-midget']

        print("\nNumPy array conversion:")
        print("-" * 70)
        all_passed = True
        for i, (short, full, exp) in enumerate(zip(types_array, result, expected)):
            status = "✓" if full == exp else "✗"
            if full != exp:
                all_passed = False
            print(f"{status} Index {i}: {short} → {full}")

        if all_passed:
            print("\n✓ NumPy conversion passed!")
        else:
            print("\n✗ NumPy conversion failed!")

        return all_passed

    except ImportError:
        print("\n" + "="*70)
        print("NumPy not available - skipping NumPy tests")
        print("="*70)
        return True


def main():
    """Run all tests."""

    print("\n")
    print("#" * 70)
    print("# Cell Type Name Conversion Test Suite")
    print("#" * 70)
    print("\n")

    # Run tests
    test1_passed = test_individual_conversions()
    test2_passed = test_batch_conversion()
    test3_passed = test_with_numpy()

    # Summary
    print("\n" + "="*70)
    print("Test Summary")
    print("="*70)

    tests = [
        ("Individual conversions", test1_passed),
        ("Batch conversion", test2_passed),
        ("NumPy arrays", test3_passed),
    ]

    all_passed = all(passed for _, passed in tests)

    for test_name, passed in tests:
        status = "✓ PASSED" if passed else "✗ FAILED"
        print(f"{status:10s} - {test_name}")

    print("="*70)

    if all_passed:
        print("\n✓✓✓ ALL TESTS PASSED ✓✓✓\n")
        return 0
    else:
        print("\n✗✗✗ SOME TESTS FAILED ✗✗✗\n")
        return 1


if __name__ == '__main__':
    sys.exit(main())
