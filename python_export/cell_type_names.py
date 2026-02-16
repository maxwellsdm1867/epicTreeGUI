"""
Cell Type Name Mapping

Maps shorthand cell type codes (OnP, OffP, etc.) to full descriptive names
for export to MATLAB epicTreeGUI.

This is a standalone version that can be used without the retinanalysis package.
"""

# Mapping from shorthand to full names
CELL_TYPE_FULL_NAMES = {
    # Parasol cells
    'OnP': 'ON-parasol',
    'OffP': 'OFF-parasol',

    # Midget cells
    'OnM': 'ON-midget',
    'OffM': 'OFF-midget',
    'BlueOffM': 'Blue OFF-midget',

    # Stratified cells
    'OnS': 'ON-stratified',
    'OffS': 'OFF-stratified',

    # Small bistratified
    'SBC': 'small-bistratified',

    # Other RGC types
    'BT': 'bistratified-transient',
    'Tufted': 'tufted',
    'OnLarge': 'ON-large',
    'OffLarge': 'OFF-large',

    # Mystery/unclassified
    'OnMystery': 'ON-mystery',
    'OffMystery': 'OFF-mystery',
    'OffBoring': 'OFF-boring',
    'OnWiggles': 'ON-wiggles',
    'InterestingIfTrue': 'interesting-if-true',
    'BigMas': 'big-mas',
    'Spotty': 'spotty',
    'Shadow': 'shadow',
    'Blobby': 'blobby',
    'Xmas': 'xmas',

    # Amacrine cells
    'OnAmacrine': 'ON-amacrine',
    'OffAmacrine': 'OFF-amacrine',
    'BlueAmacrine': 'blue-amacrine',
    'Amacrine': 'amacrine',
    'A1': 'A1-amacrine',

    # Other
    'RB': 'rod-bipolar',
    'BlueMystery': 'blue-mystery',
    'BluePeaky': 'blue-peaky',

    # Generic fallbacks
    'RGC': 'RGC',
    'Unknown': 'unknown',
}

# RGC types that should get the RGC\ prefix
RGC_TYPES = [
    'OnP', 'OffP', 'OnM', 'OffM', 'BlueOffM',
    'OnS', 'OffS', 'SBC', 'BT', 'Tufted',
    'OnLarge', 'OffLarge', 'OnMystery', 'OffMystery',
    'OffBoring', 'OnWiggles', 'InterestingIfTrue',
    'BigMas', 'Spotty', 'Shadow', 'Blobby', 'Xmas'
]


def get_full_cell_type_name(shorthand: str, prefix_rgc: bool = True) -> str:
    """
    Convert shorthand cell type code to full descriptive name.

    Parameters:
        shorthand (str): Shorthand code (e.g., 'OnP', 'OffM')
        prefix_rgc (bool): If True, prefix RGC types with 'RGC\\'. Default True.

    Returns:
        str: Full cell type name (e.g., 'RGC\\ON-parasol', 'rod-bipolar')

    Examples:
        >>> get_full_cell_type_name('OnP')
        'RGC\\ON-parasol'
        >>> get_full_cell_type_name('OnP', prefix_rgc=False)
        'ON-parasol'
        >>> get_full_cell_type_name('RB')
        'rod-bipolar'
        >>> get_full_cell_type_name('UnknownType')
        'UnknownType'
    """

    # Check if we have a mapping
    if shorthand in CELL_TYPE_FULL_NAMES:
        full_name = CELL_TYPE_FULL_NAMES[shorthand]

        # Add RGC prefix for ganglion cells (if requested)
        if prefix_rgc and shorthand in RGC_TYPES:
            full_name = f'RGC\\{full_name}'

        return full_name
    else:
        # Return as-is if no mapping
        return shorthand


def convert_cell_types_to_full_names(cell_types, prefix_rgc: bool = True):
    """
    Convert list or array of shorthand cell types to full names.

    Parameters:
        cell_types: List, array, or Series of shorthand codes
        prefix_rgc (bool): If True, prefix RGC types with 'RGC\\'. Default True.

    Returns:
        List of full cell type names

    Example:
        >>> types = ['OnP', 'OffP', 'OnM', 'RB']
        >>> convert_cell_types_to_full_names(types)
        ['RGC\\ON-parasol', 'RGC\\OFF-parasol', 'RGC\\ON-midget', 'rod-bipolar']
    """

    if hasattr(cell_types, 'tolist'):
        # numpy array or pandas Series
        cell_types = cell_types.tolist()

    return [get_full_cell_type_name(ct, prefix_rgc=prefix_rgc) for ct in cell_types]
