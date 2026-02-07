# Architecture Patterns: MATLAB Package Documentation

**Domain:** Documentation organization for MATLAB research software
**Researched:** 2026-02-06
**Confidence:** MEDIUM-HIGH

## Recommended Documentation Architecture

Documentation for MATLAB packages follows a hierarchical information architecture that mirrors user journeys from discovery to mastery.

```
Documentation System
├── Discovery Layer (README.md)
│   ├── What/Why/Who (30 seconds)
│   ├── Quick Start (5 minutes)
│   └── Navigation to deeper docs
├── Getting Started Layer (Tutorial/Quickstart)
│   ├── Installation walkthrough
│   ├── First success (30 minutes)
│   └── Common workflow example
├── Reference Layer (User Guide + API)
│   ├── Feature documentation
│   ├── Function reference
│   └── Configuration options
├── Deep Dive Layer (Architecture + Advanced)
│   ├── System design
│   ├── Extension points
│   └── Performance optimization
└── Support Layer (Troubleshooting + FAQ)
    ├── Common errors
    ├── Debugging guide
    └── Getting help
```

## Component Boundaries

### 1. README.md (Discovery Layer)

**Responsibility:**
- Answer "What is this?" in 30 seconds
- Convince user to invest time learning
- Point to installation and next steps
- Provide social proof (citations, usage stats)

**Communicates With:**
- Links to docs/QUICKSTART.md for tutorial
- Links to docs/USER_GUIDE.md for comprehensive reference
- Links to examples/ for runnable code
- Links to LICENSE for legal info
- Links to CITATION.cff for academic citation

**Anti-Pattern:**
- README becomes a wall of text
- README duplicates user guide content
- Installation buried below screenful of prose

**Pattern:**
```markdown
# Project Name
One-sentence description

[Badges: license, MATLAB version, build status]

## What It Does
2-3 sentences explaining purpose and value

## Key Features
- Feature 1 (benefit)
- Feature 2 (benefit)
- Feature 3 (benefit)

## Installation
```matlab
% 3-5 lines of code
```

## Quick Example
```matlab
% 10-15 lines showing basic usage
```

## Documentation
- [Quickstart Tutorial](docs/QUICKSTART.md)
- [User Guide](docs/USER_GUIDE.md)
- [Examples](examples/)

## Citation
[How to cite this software]

## License
MIT - see LICENSE file
```

**Length:** 100-300 lines (fits in 2-3 screen heights)

### 2. docs/QUICKSTART.md (Getting Started Layer)

**Responsibility:**
- Guide user from zero to first successful result
- Build confidence through incremental success
- Explain core concepts just-in-time
- Typical duration: 30-60 minutes

**Communicates With:**
- Assumes user read README installation section
- Links to USER_GUIDE.md for comprehensive reference
- Links to specific example scripts in examples/
- Links to TROUBLESHOOTING.md for errors

**Structure:**
```markdown
# Quickstart: Your First Analysis with epicTreeGUI

**Goal:** Load data, build a tree, extract selected epochs, and plot mean response.

**Time:** ~30 minutes

**Prerequisites:**
- MATLAB R2020b+ installed
- epicTreeGUI installed (see README.md)
- Sample data downloaded

## Step 1: Load Your Data (5 min)
[Instructions with code]

**Expected output:** "Loaded 1915 epochs"

## Step 2: Build Tree Hierarchy (5 min)
[Instructions with code]

**Expected output:** Tree structure printed

## Step 3: Select Epochs (10 min)
[Instructions with code + screenshot]

**Expected output:** Selection count shown

## Step 4: Compute Mean Response (10 min)
[Instructions with code]

**Expected output:** Figure with mean trace

## What You Accomplished
- Loaded neurophysiology data
- Organized epochs hierarchically
- Filtered by selection
- Computed summary statistics

## Next Steps
- [Example scripts](../examples/) for more workflows
- [User Guide](USER_GUIDE.md) for all features
- [Custom Splitters](USER_GUIDE.md#custom-splitters) for advanced organization
```

**Length:** 500-1500 lines

### 3. docs/USER_GUIDE.md (Reference Layer)

**Responsibility:**
- Comprehensive reference for all features
- Searchable (users Ctrl+F to find topics)
- Organized by task, not implementation
- Includes both conceptual explanations and API details

**Communicates With:**
- Cross-references to examples/ for runnable code
- Links to ARCHITECTURE.md for design rationale
- Links to TROUBLESHOOTING.md for errors
- Links to API.md (if separate) for function reference

**Structure:**
```markdown
# User Guide

## Table of Contents
[Auto-generated or manual TOC]

## Installation and Setup
### Requirements
### Installation
### Configuration
### Verification

## Core Concepts
### Tree Structure
### Splitters
### Selection System
### Data Extraction

## Basic Usage
### Loading Data
### Building Trees
### Navigating Trees
### Extracting Data

## Advanced Features
### Custom Splitters
### Batch Processing
### Result Storage
### Performance Tuning

## API Reference
### Tree Navigation Functions
### Data Extraction Functions
### Analysis Functions
### Utility Functions

## Troubleshooting
[Common issues or link to TROUBLESHOOTING.md]
```

**Length:** 2000-5000 lines

### 4. examples/ Directory (Learning Layer)

**Responsibility:**
- Provide copy-paste executable code
- Demonstrate real-world workflows
- Serve as templates for user's own analysis
- Self-contained (each example runs independently)

**Communicates With:**
- Referenced from README quick example
- Referenced from QUICKSTART tutorial
- Referenced from USER_GUIDE sections
- Uses data from examples/data/ or external links

**Structure:**
```
examples/
├── README.md                    # Overview of all examples
├── data/
│   ├── sample_data.mat         # Minimal test dataset
│   └── DATA_README.md          # Describes data structure
├── 01_basic_loading.m          # Simplest possible usage
├── 02_tree_navigation.m        # Navigate and query tree
├── 03_data_extraction.m        # Get selected data
├── 04_batch_analysis.m         # Process multiple conditions
├── 05_custom_splitter.m        # Extend with custom logic
└── 06_comparison_workflow.m    # Compare conditions
```

**Example script pattern:**
```matlab
%% Example 3: Data Extraction and Analysis
% Demonstrates how to extract selected epoch data and compute statistics
%
% This example shows:
%   - Building tree with specific organization
%   - Setting selection state
%   - Extracting data with getSelectedData()
%   - Computing mean response
%
% Expected output:
%   - Figure showing mean ± SEM trace
%   - Command window statistics
%
% Prerequisites:
%   - Sample data in examples/data/ directory
%   - epicTreeGUI on MATLAB path
%
% Author: [Name]
% Date: 2026-02-06

%% Setup
clear; clc; close all;

% Add paths if needed
if ~exist('epicTreeTools', 'file')
    addpath(genpath('../src'));
end

% Load sample data
dataPath = 'data/sample_data.mat';
if ~exist(dataPath, 'file')
    error('Sample data not found. Download from [URL]');
end

%% [Rest of example...]
```

### 5. docs/ARCHITECTURE.md (Deep Dive Layer)

**Responsibility:**
- Explain system design for power users
- Document design decisions and rationale
- Identify extension points
- Enable community contributions

**Communicates With:**
- Referenced from USER_GUIDE for "how it works"
- Links to relevant source files
- Links to examples/ showing patterns
- Referenced from CONTRIBUTING.md

**Structure:**
```markdown
# Architecture

## System Overview
[High-level diagram]

## Core Components
### epicTreeTools
**Purpose:** Hierarchical data organization
**Key Classes:** Node, TreeBuilder
**Responsibilities:** Navigation, selection management

### Data Layer
**Purpose:** Epoch storage and retrieval
**Key Functions:** getSelectedData, loadEpicTreeData
**Responsibilities:** H5 lazy loading, response extraction

### GUI Layer
**Purpose:** Visual tree browsing
**Key Components:** epicTreeGUI, graphicalTree
**Responsibilities:** User interaction, plotting

## Data Flow
1. Load .mat metadata
2. Build tree structure with splitters
3. User navigates and selects
4. Extract data on-demand from H5
5. Compute analysis results
6. Store at tree nodes

## Design Decisions
### Why Pre-Built Tree Pattern?
[Rationale]

### Why H5 Lazy Loading?
[Rationale]

### Why No Java Dependencies?
[Rationale]

## Extension Points
### Adding Custom Splitters
[How to extend]

### Adding Analysis Functions
[Pattern to follow]
```

**Length:** 500-2000 lines

### 6. docs/TROUBLESHOOTING.md (Support Layer)

**Responsibility:**
- Reduce support burden
- Enable user self-service debugging
- Document common mistakes
- Provide clear solutions

**Structure:**
```markdown
# Troubleshooting

## Installation Issues

### Error: "epicTreeTools not found"
**Cause:** Path not configured
**Solution:**
```matlab
addpath(genpath('/full/path/to/epicTreeGUI'));
which epicTreeTools  % Verify
```

### Error: "Requires MATLAB R2020b+"
**Cause:** Old MATLAB version
**Solution:** Upgrade MATLAB or check if older version compatible

## Data Loading Issues

### Error: "H5 file not found"
**Cause:** H5 directory not configured
**Solution:**
```matlab
epicTreeConfig('h5_dir', '/path/to/h5/files');
```

[More issues...]

## Performance Issues

### Slow tree building
**Symptoms:** buildTree() takes > 5 seconds
**Causes:**
1. Too many split levels
2. Large dataset (>10k epochs)
**Solutions:**
1. Reduce split depth
2. Use noEpochs option

[More issues...]

## Getting Help
If not covered here:
1. Check [GitHub Issues](URL) for similar problems
2. Search [Discussions](URL)
3. Open new issue with MWE (minimal working example)
```

**Length:** 500-1500 lines

## Documentation Organization Patterns

### Pattern 1: Progressive Disclosure

Information revealed in layers based on user needs.

**Layer 1 (README):** What, why, install, minimal example
**Layer 2 (Quickstart):** First successful workflow
**Layer 3 (User Guide):** All features, searchable reference
**Layer 4 (Architecture):** Design decisions, internals
**Layer 5 (Source Code):** Implementation details

**Benefit:** Users aren't overwhelmed, find what they need when they need it.

### Pattern 2: Task-Oriented Organization

Organize by user goals, not software structure.

**Anti-Pattern:**
```
# Documentation
## epicTreeTools Class
## epicTreeGUI Class
## getSelectedData Function
```

**Good Pattern:**
```
# Documentation
## Loading Your Data
## Organizing Epochs
## Extracting Selected Data
## Analyzing Results
```

**Benefit:** Users think "I want to do X", not "I want to use class Y".

### Pattern 3: Example-Driven Documentation

Every feature documented with executable code example.

**Anti-Pattern:**
```markdown
The buildTree() method accepts a cell array of split keys.
```

**Good Pattern:**
```markdown
The buildTree() method accepts a cell array of split keys:

```matlab
% Split by cell type, then protocol
tree.buildTree({'cellInfo.type', 'blockInfo.protocol_name'});
```

**Benefit:** Users learn by doing, examples serve as templates.

### Pattern 4: Just-In-Time Concepts

Introduce concepts when needed, not upfront.

**Anti-Pattern:**
```markdown
# Core Concepts
[10 pages of terminology before any examples]
```

**Good Pattern:**
```markdown
# Quick Start
Load data and build a simple tree:
```matlab
tree = epicTreeTools(data);
tree.buildTree({'cellInfo.type'});
```

This creates a **tree** (hierarchical organization) with **nodes**
(groups) split by cell type. [Link to concepts for details]
```

**Benefit:** Users get quick wins before investing in theory.

### Pattern 5: Redundant Navigation

Every doc should link to relevant related docs.

**From README:**
- → Quickstart
- → User Guide
- → Examples
- → License

**From Quickstart:**
- ← Back to README
- → User Guide (for details)
- → Examples (for more workflows)
- → Troubleshooting

**From User Guide:**
- ← Back to README
- → Examples (for code)
- → Architecture (for design)
- → API Reference

**Benefit:** Users never get stuck, always have next steps.

## File Format Standards

### Markdown for Documentation

**Why Markdown:**
- GitHub renders it automatically
- Version control friendly (plain text)
- Searchable via GitHub search and grep
- Cross-platform, readable in any editor
- Can generate PDF/HTML if needed

**Markdown features to use:**
- Headers (`#`, `##`) for structure
- Code blocks (` ```matlab `) for syntax highlighting
- Tables for comparisons
- Links for cross-references
- Lists for step-by-step instructions
- Blockquotes for notes/warnings

**Markdown to avoid:**
- Embedded HTML (not portable)
- Overly complex tables (hard to maintain)
- Inline images without alt text (accessibility)

### .m Files for Examples

**Why .m not .mlx:**
- Plain text (version control friendly)
- Viewable on GitHub without MATLAB
- Searchable with grep
- Editable in any text editor
- No binary diff conflicts

**When .mlx is acceptable:**
- Supplementary to .m version
- Interactive tutorial with rich formatting
- Distributed separately (not primary docs)

### Function Headers for API Docs

**MATLAB help system integration:**
```matlab
function output = myFunction(input)
% MYFUNCTION One-line description
%
% Full documentation here...
```

**This powers:**
- `help myFunction` in command window
- `doc myFunction` in help browser
- Code completion tooltips
- Searchable via `lookfor`

## Scalability Considerations

### At 10 Functions (Current epicTreeGUI)

**Documentation needs:**
- README with overview
- Single USER_GUIDE.md
- 3-5 examples
- Inline function help

**Organization:** Flat structure, docs/ with few files

### At 50 Functions

**Documentation needs:**
- Separate API reference
- Multiple user guide sections
- 10+ examples in categories
- Architecture doc

**Organization:** Categorized, docs/ with subdirectories

### At 100+ Functions (Full toolbox)

**Documentation needs:**
- Searchable API database
- Multiple tutorials by topic
- Gallery of examples
- Video walkthroughs
- Community contributions

**Organization:** Structured hierarchy, possibly docs website

**EpicTreeGUI is in "10 functions" category:** Keep it simple, flat structure sufficient.

## Anti-Patterns to Avoid

### 1. Documentation Drift

**Symptom:** Code changes, docs don't update
**Prevention:**
- Keep docs in repo (not wiki)
- Review docs in PR process
- Test examples before release

### 2. Incomplete Examples

**Symptom:** Code snippets that don't run
**Prevention:**
- Every example is a standalone .m file
- Test all examples on clean install
- Include expected outputs

### 3. Orphan Documentation

**Symptom:** Random .md files with no navigation
**Prevention:**
- Central README links to all docs
- Each doc links to related docs
- Clear Table of Contents

### 4. Assumed Knowledge

**Symptom:** "Obviously you need to..." (not obvious)
**Prevention:**
- Define domain terms
- Explicit prerequisites
- Link to background reading

### 5. Version Confusion

**Symptom:** Docs for v2.0, user has v1.0
**Prevention:**
- Docs in repo travel with code
- Version number in docs
- Changelog for breaking changes

## Recommendations for epicTreeGUI

### Current State Assessment

**Exists and good:**
- README.md (comprehensive, needs polish)
- docs/UserGuide.md (good structure, needs completion)
- examples/ directory (2 scripts, needs 3-5 more)
- CLAUDE.md (excellent architecture info)

**Missing:**
- LICENSE file
- docs/QUICKSTART.md tutorial
- docs/TROUBLESHOOTING.md
- examples/README.md overview
- CITATION.cff

**Needs improvement:**
- README: More user-focused, less developer-focused
- Examples: More variety, better comments
- User Guide: Complete all sections

### Recommended Documentation Structure

```
epicTreeGUI/
├── README.md                      # Polish, user-focused
├── LICENSE                        # Add MIT
├── CITATION.cff                   # Add for academics
├── CHANGELOG.md                   # Create (minimal for v1.0)
├── docs/
│   ├── QUICKSTART.md             # NEW: 30-min tutorial
│   ├── USER_GUIDE.md             # Complete existing
│   ├── ARCHITECTURE.md           # Extract from CLAUDE.md
│   ├── TROUBLESHOOTING.md        # NEW: Common errors
│   ├── DATA_FORMAT.md            # Link existing spec
│   └── API.md                    # Optional: function reference
├── examples/
│   ├── README.md                 # NEW: Overview of examples
│   ├── data/
│   │   ├── sample_data.mat      # Include if < 10 MB
│   │   └── DATA_README.md       # Describe sample data
│   ├── 01_basic_usage.m         # NEW: Simplest case
│   ├── 02_tree_navigation.m     # Adapt existing
│   ├── 03_data_extraction.m     # Adapt existing
│   ├── 04_batch_analysis.m      # NEW: Common pattern
│   └── 05_custom_splitter.m     # NEW: Extension example
├── tests/                         # Separate from examples
│   └── [existing test files]
└── src/                           # Source with inline help
```

### Development Priority

**Week 1:**
1. Add LICENSE file (5 min)
2. Polish README.md (2-3 hours)
3. Create examples/README.md (1 hour)

**Week 2:**
4. Write 3 new example scripts (4-6 hours)
5. Create QUICKSTART.md tutorial (4-6 hours)

**Week 3:**
6. Extract ARCHITECTURE.md from CLAUDE.md (2-3 hours)
7. Create TROUBLESHOOTING.md (2-4 hours)
8. Complete USER_GUIDE.md sections (3-5 hours)

**Week 4:**
9. Review all docs for consistency (2 hours)
10. Test all examples on clean install (2 hours)
11. Create CITATION.cff (30 min)

**Total: ~30-40 hours spread over 4 weeks**

## Sources

**Confidence:** MEDIUM-HIGH

Based on:
- MATLAB documentation best practices (training data)
- Scientific software documentation patterns
- GitHub documentation standards
- Existing epicTreeGUI documentation analysis
- Information architecture principles for technical docs

**Limitations:**
- No verification with current 2026 examples
- Based on established patterns, not cutting-edge trends
- Assumes GitHub-hosted documentation (not separate docs site)
