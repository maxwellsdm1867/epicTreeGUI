# Phase 1: Foundation & Legal - Research

**Researched:** 2026-02-16
**Domain:** Repository cleanup, legal licensing, professional presentation, MATLAB toolbox distribution
**Confidence:** HIGH

## Summary

Phase 1 transforms epicTreeGUI from a working internal tool into a legally releasable, professionally presented open-source MATLAB repository. The core technical challenge is **repository cleanup and organization** following MATLAB toolbox best practices while preserving working functionality. The legal aspects (MIT LICENSE, CITATION.cff) are straightforward using industry-standard templates. The critical deliverable is a **minimal, clean root directory** (< 5 files) with professional presentation that allows users to discover, install, and verify the tool in under 5 minutes.

**Primary recommendation:** Follow MathWorks toolbox design best practices—clean root with README/LICENSE/CITATION.cff/install.m, move all development artifacts to organized subdirectories (docs/, tests/), bundle minimal sample data (< 10 MB), and create path setup script that uses relative paths for portability.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Repo cleanup strategy:**
- Move `old_epochtree/` to `docs/legacy/` (preserve as reference, out of the way)
- Root files: README.md, LICENSE, CITATION.cff, CHANGELOG.md, install.m, .gitignore — standard open-source layout
- Move all other markdown files into `docs/`
- Remove `new_retinanalysis/` entirely — Python pipeline code is not part of this MATLAB tool
- Move all scattered test files into `tests/`

**README tone & content:**
- Tone: Academic professional — formal, precise language, like a methods paper
- Identity: "A MATLAB GUI for browsing and analyzing neurophysiology epoch data" — tool-first, not migration-first
- Quick start example: Load → Build tree → Extract data with getSelectedData → Analyze (programmatic workflow, not GUI launch)
- Legacy mention: Brief one-line note that it replaces the legacy Java epoch tree system — helps existing users find it, doesn't dominate
- Reference file `riekesuitworkflow.md` describes the old workflow — use for context when writing README

**Example & sample data:**
- Bundle trimmed real data (small subset of real experiment epochs, authentic but minimal)
- Sample data location: `examples/data/` — examples are self-contained
- Bundled example demonstrates full analysis workflow: load → build → select → getSelectedData → plot mean trace
- Example should be end-to-end science, not just tree navigation

### Claude's Discretion

- Path referencing approach in example scripts (relative to script vs relative to project root)
- install.m implementation details
- Exact README section ordering and formatting
- Which specific epochs to extract for sample data
- CITATION.cff content (standard academic metadata)

### Deferred Ideas (OUT OF SCOPE)

- Migration guide from legacy epochTreeGUI — Phase 3
- Detailed tutorials and multiple example scripts — Phase 2
- Screenshots in README — Phase 4

</user_constraints>

## Current Repository State Analysis

**Root directory inventory (68 items, 23 loose scripts):**
- 30+ markdown documentation files scattered at root
- 23 loose .m and .py scripts (debug files, test files, verification scripts)
- 3 directories to be removed/relocated: `old_epochtree/` (17 MB), `new_retinanalysis/` (282 MB), `test_data/` (251 MB)
- Current test files: Mix of 33 test scripts in `tests/` directory (properly organized) + loose test scripts at root
- Existing example scripts: 2 in `examples/` but with hardcoded absolute paths

**Data files:**
- Test data exists at `test_data/sample_data.mat` (183 KB) — small enough to bundle
- Test data includes H5 directory (251 MB) — too large, should not be committed
- Production test data at `/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat` (344 KB)

**Existing infrastructure:**
- `START_HERE.m` demonstrates quick launch pattern with hardcoded paths
- `examples/example_analysis_workflow.m` shows 10 comprehensive usage patterns but has hardcoded paths
- `docs/` directory exists with UserGuide.md and SELECTION_STATE_ARCHITECTURE.md
- `.planning/` directory has roadmap and requirements documentation

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| MIT License | Current | Open source licensing | Most permissive, academia-friendly, GitHub default |
| CITATION.cff | 1.2.0 | Academic citation metadata | GitHub-integrated, machine-readable, research software standard |
| CHANGELOG.md | Keep a Changelog 1.0.0 | Version history tracking | Community standard for semantic versioning |
| Markdown | CommonMark | Documentation format | GitHub native rendering, universal |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| Git LFS | Latest | Large file storage | Only if sample data > 10 MB (NOT recommended) |
| .gitignore | - | Exclude build artifacts | Standard for MATLAB projects |
| install.m | - | Path setup automation | Standard for MATLAB toolboxes without .mltbx packaging |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| MIT License | BSD-3-Clause | More explicit patent/trademark clauses, but MIT is simpler |
| CITATION.cff | BibTeX only | CFF is machine-readable and GitHub-integrated, BibTeX is manual |
| install.m | .mltbx packaging | Packaging requires MATLAB GUI, install.m is portable and git-friendly |

**Installation:**
```matlab
% User runs from repository root:
run install.m
```

## Architecture Patterns

### Recommended Project Structure

**MathWorks Toolbox Design Best Practices:**

```
epicTreeGUI/
├── README.md              # Project overview, installation, quick start
├── LICENSE                # MIT license (NO .txt extension for GitHub)
├── CITATION.cff           # Academic citation metadata
├── CHANGELOG.md           # Version history
├── install.m              # Path setup script
├── .gitignore             # Exclude .asv, .DS_Store, etc.
├── src/                   # Source code (ALL functional code here)
│   ├── tree/              # epicTreeTools and tree logic
│   ├── gui/               # GUI components
│   ├── splitters/         # Splitter functions
│   ├── utilities/         # Helper functions
│   └── config/            # Configuration management
├── examples/              # User-facing examples (< 5 scripts)
│   ├── data/              # Bundled sample data (< 10 MB total)
│   ├── quickstart.m       # Minimal 10-line example from README
│   └── analysis_workflow.m # End-to-end scientific workflow
├── tests/                 # ALL test files (not distributed to users)
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   └── helpers/           # Test utilities
└── docs/                  # ALL documentation
    ├── legacy/            # old_epochtree reference code (read-only)
    ├── UserGuide.md       # Comprehensive user guide
    └── ARCHITECTURE.md    # Technical architecture (from CLAUDE.md)
```

**Key Principles:**
- **Root clarity:** Only 6 files at root (README, LICENSE, CITATION.cff, CHANGELOG.md, install.m, .gitignore)
- **Single toolbox folder:** `src/` contains everything users need; `tests/` and `docs/` are for developers
- **Self-contained examples:** `examples/data/` co-located with example scripts, no external dependencies
- **Legacy isolation:** Reference code moved to `docs/legacy/`, clearly marked as read-only

### Pattern 1: install.m Path Setup

**What:** Automated MATLAB path configuration script using relative paths
**When to use:** Every MATLAB toolbox without .mltbx packaging
**Example:**

```matlab
function install()
    % install.m - Add epicTreeGUI to MATLAB path
    %
    % Run this script once from the epicTreeGUI root directory:
    %   >> cd /path/to/epicTreeGUI
    %   >> install
    %
    % This adds all necessary paths and saves them to your MATLAB path.

    % Get installation directory
    installDir = fileparts(mfilename('fullpath'));

    % Add source directories
    fprintf('Adding epicTreeGUI to MATLAB path...\n');
    addpath(fullfile(installDir, 'src'));
    addpath(fullfile(installDir, 'src', 'tree'));
    addpath(fullfile(installDir, 'src', 'gui'));
    addpath(fullfile(installDir, 'src', 'splitters'));
    addpath(fullfile(installDir, 'src', 'utilities'));
    addpath(fullfile(installDir, 'src', 'config'));

    % Verify installation
    if exist('epicTreeTools', 'file') && exist('epicTreeGUI', 'file')
        fprintf('✓ Installation successful!\n');
        fprintf('  Try: help epicTreeTools\n');
        fprintf('  Run examples: cd examples; edit quickstart.m\n');

        % Optionally save path
        response = input('Save path for future MATLAB sessions? (y/n): ', 's');
        if strcmpi(response, 'y')
            savepath;
            fprintf('✓ Path saved\n');
        end
    else
        error('Installation verification failed. Check directory structure.');
    end
end
```

**Why this pattern:**
- `mfilename('fullpath')` makes paths relative to install.m location (portable across systems)
- Explicit subdirectory paths (not `genpath()`) prevents namespace pollution
- Verification step catches structural errors immediately
- Optional `savepath` gives user control over MATLAB path modifications

**Source:** Adapted from [FieldTrip toolbox installation patterns](https://www.fieldtriptoolbox.org/faq/matlab/installation/) and MathWorks toolbox design recommendations

### Pattern 2: Minimal Sample Data

**What:** Bundle authentic but minimal dataset for examples
**When to use:** GitHub repositories without external download infrastructure
**Example:**

```matlab
% Extract minimal sample from production data
fullData = load('/path/to/2025-12-02_F.mat');

% Filter to smallest meaningful subset
% Strategy: 1 cell type, 2 protocols, ~50 total epochs
sampleEpochs = {};
for i = 1:length(fullData.epochs)
    ep = fullData.epochs{i};
    % Include only RGC, SingleSpot and ExpandingSpots protocols
    if strcmp(ep.cellInfo.type, 'RGC') && ...
       (strcmp(ep.blockInfo.protocol_name, 'SingleSpot') || ...
        strcmp(ep.blockInfo.protocol_name, 'ExpandingSpots'))
        sampleEpochs{end+1} = ep;
        if length(sampleEpochs) >= 50
            break;
        end
    end
end

% Package for distribution
sampleData = struct();
sampleData.epochs = sampleEpochs;
% Copy minimal metadata (no full experiments array)
sampleData.export_timestamp = fullData.export_timestamp;

save('examples/data/sample_epochs.mat', '-struct', 'sampleData', '-v7.3');
fprintf('Sample data: %d epochs, %d KB\n', ...
    length(sampleEpochs), round(dir('examples/data/sample_epochs.mat').bytes/1024));
```

**Why this pattern:**
- Real experiment data maintains authenticity for testing
- < 10 MB keeps repository clone fast (GitHub best practice)
- Subset strategy: 1 cell type, 2-3 protocols, 50-100 epochs = full functionality demo
- Excludes H5 files (too large); examples demonstrate lazy loading but don't require it

**Source:** [GitHub best practices for repositories](https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories) - avoid large binary files

### Pattern 3: Academic Professional README

**What:** README structure for research software
**When to use:** MATLAB tools for scientific community
**Example structure:**

```markdown
# EpicTreeGUI

A MATLAB GUI for browsing and analyzing neurophysiology epoch data.

## Overview

EpicTreeGUI provides hierarchical organization and analysis of neurophysiology
experiments exported from electrophysiology data pipelines. The system organizes
epochs into dynamic tree structures using configurable splitting criteria,
enabling efficient data subset selection and comparative analysis.

*Replaces the legacy Rieke Lab Java-based epoch tree system.*

## Installation

**Requirements:** MATLAB R2019b or later (no toolboxes required)

1. Clone repository:
   ```bash
   git clone https://github.com/username/epicTreeGUI.git
   cd epicTreeGUI
   ```

2. Run installation script:
   ```matlab
   install
   ```

3. Verify installation:
   ```matlab
   help epicTreeTools
   ```

## Quick Start

```matlab
% Load data and build tree
[data, ~] = loadEpicTreeData('examples/data/sample_epochs.mat');
tree = epicTreeTools(data);
tree.buildTreeWithSplitters({@epicTreeTools.splitOnCellType, ...
                              @epicTreeTools.splitOnProtocol});

% Extract data subset
leaves = tree.leafNodes();
[dataMatrix, epochs, fs] = getSelectedData(leaves{1}, 'Amp1');

% Analyze
meanTrace = mean(dataMatrix, 1);
plot((1:length(meanTrace))/fs*1000, meanTrace);
xlabel('Time (ms)'); ylabel('Response');
```

## Citation

If you use this software, please cite:

```bibtex
@software{epicTreeGUI,
  author = {Author Names},
  title = {EpicTreeGUI: Hierarchical Browser for Neurophysiology Data},
  year = {2026},
  url = {https://github.com/username/epicTreeGUI}
}
```

See `CITATION.cff` for full metadata.

## Documentation

- [User Guide](docs/UserGuide.md) - Comprehensive usage documentation
- [Examples](examples/) - Analysis workflow demonstrations
- [Architecture](docs/ARCHITECTURE.md) - Technical implementation details

## License

MIT License - see [LICENSE](LICENSE) file.
```

**Why this pattern:**
- **30-second comprehension:** First paragraph answers "What is this?"
- **Tool-first identity:** Describes capabilities, not legacy migration
- **Programmatic quick start:** Shows core workflow, not GUI launching (demonstrates power)
- **Academic citation:** BibTeX + CITATION.cff reference (research software standard)
- **Formal tone:** Methods paper style, not marketing copy

**Source:** Adapted from [The Turing Way - Software Citation](https://book.the-turing-way.org/communication/citable/citable-cff/)

### Anti-Patterns to Avoid

- **Don't use `addpath(genpath(...))`** - Adds private folders, legacy code, test helpers to path causing namespace pollution ([FieldTrip FAQ](https://www.fieldtriptoolbox.org/faq/matlab/installation/))
- **Don't commit derived files** - .mex binaries, .asv autosaves, slprj folders ([MathWorks source control guide](https://www.mathworks.com/help/matlab/matlab_prog/use-source-control-with-projects.html))
- **Don't bundle large datasets** - Use download scripts or Git LFS for data > 10 MB ([GitHub best practices](https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories))
- **Don't put "Toolbox" in folder name** - MathWorks convention is to drop "Toolbox" from folder name ([MathWorks toolbox design](https://github.com/mathworks/toolboxdesign))

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| License text | Custom license | MIT template from choosealicense.com | Legal review, OSI-approved, GitHub-recognized |
| Citation format | Custom BibTeX | CITATION.cff 1.2.0 | GitHub integration, machine-readable, auto-converts to BibTeX |
| Changelog format | Custom versioning | Keep a Changelog 1.0.0 | Community standard, semantic versioning compatible |
| Path setup | Manual addpath list | install.m with mfilename('fullpath') | Portable across systems, verifiable installation |
| Sample data hosting | External server | Git repository (< 10 MB) | Zero infrastructure, clone-and-run workflow |

**Key insight:** Academic software repositories have well-established conventions. Using standard formats (CITATION.cff, MIT LICENSE, Keep a Changelog) provides **zero-config integration** with GitHub, Zenodo, and academic reference managers. Custom formats require user education and tool support.

## Common Pitfalls

### Pitfall 1: Absolute Paths in Examples

**What goes wrong:** Example scripts contain hardcoded paths like `/Users/maxwellsdm/Documents/...`, making them unusable for other users

**Why it happens:** Development scripts copy-pasted into examples without path sanitization

**How to avoid:**
```matlab
% BAD - Hardcoded absolute path
dataPath = '/Users/maxwellsdm/Documents/epicTreeTest/analysis/2025-12-02_F.mat';

% GOOD - Relative to example script location
exampleDir = fileparts(mfilename('fullpath'));
dataPath = fullfile(exampleDir, 'data', 'sample_epochs.mat');

% BETTER - With existence check
if ~exist(dataPath, 'file')
    error('Sample data not found. Expected: %s', dataPath);
end
```

**Warning signs:**
- User reports "file not found" when running examples
- Grep reveals: `grep -r '/Users/' examples/` returns matches
- Example scripts fail on different machines

**Current state:** Both `examples/example_analysis_workflow.m` and `START_HERE.m` have hardcoded paths that need fixing

### Pitfall 2: Large Files in Git History

**What goes wrong:** Committing `test_data/h5/` (251 MB) makes repository clone slow and bloats history even after deletion

**Why it happens:** `git add .` without checking .gitignore coverage

**How to avoid:**
```bash
# Add to .gitignore BEFORE any commits
echo "test_data/" >> .gitignore
echo "*.h5" >> .gitignore
echo "**/*.asv" >> .gitignore

# If already committed, must purge history
git filter-branch --tree-filter 'rm -rf test_data' HEAD
# OR use BFG Repo-Cleaner for large repos
```

**Warning signs:**
- `git clone` takes > 30 seconds for a MATLAB project
- `.git` directory > 100 MB for a code-only repository
- `du -sh .git` reveals large packfiles

**Current state:** `test_data/` directory exists (251 MB) and should be removed before Phase 1 completion

### Pitfall 3: Legacy Code Pollution

**What goes wrong:** Users accidentally use deprecated `old_epochtree/` code instead of new system, causing confusing errors

**Why it happens:** Legacy code still on MATLAB path via `addpath(genpath(...))` or left at accessible location

**How to avoid:**
1. **Move** `old_epochtree/` to `docs/legacy/` (out of MATLAB path)
2. **Add README** explaining it's reference-only: `docs/legacy/README.md`
3. **Never add to path** in install.m
4. **Document clearly** in main README that it's superseded

**Warning signs:**
- User reports Java class errors or riekesuite namespace conflicts
- Functions named graphicalTree conflict with epicGraphicalTree
- GitHub Issues mention "old_epochtree" usage

**Current state:** `old_epochtree/` (17 MB) at root needs moving to `docs/legacy/`

### Pitfall 4: "Install.m ran but nothing works"

**What goes wrong:** User runs install.m, sees "Installation successful!" but functions are not found

**Why it happens:** Path added to session but not saved, or verification checks are insufficient

**How to avoid:**
```matlab
% In install.m verification section:

% Test 1: File existence (NOT just 'file' type - could be on path from elsewhere)
epicTreeToolsPath = which('epicTreeTools');
if isempty(epicTreeToolsPath) || ...
   ~contains(epicTreeToolsPath, installDir)
    error('epicTreeTools not found in expected location');
end

% Test 2: Run simple operation
try
    testData = struct('epochs', {{}});
    tree = epicTreeTools(testData);
    fprintf('✓ Basic functionality verified\n');
catch ME
    error('Verification failed: %s', ME.message);
end

% Test 3: Warn if path not saved
if ~savepath_was_confirmed
    warning(['Path added to current session only. ' ...
             'Run "savepath" to make permanent.']);
end
```

**Warning signs:**
- User reports "Undefined function 'epicTreeTools'" after installation
- Functions work in installation session but not in new MATLAB session
- `which epicTreeTools` returns path outside repository

## Code Examples

### Example 1: Minimal Quick Start (from README)

```matlab
% Load data and build tree
[data, ~] = loadEpicTreeData('examples/data/sample_epochs.mat');
tree = epicTreeTools(data);
tree.buildTreeWithSplitters({@epicTreeTools.splitOnCellType, ...
                              @epicTreeTools.splitOnProtocol});

% Extract data subset
leaves = tree.leafNodes();
[dataMatrix, epochs, fs] = getSelectedData(leaves{1}, 'Amp1');

% Analyze
meanTrace = mean(dataMatrix, 1);
plot((1:length(meanTrace))/fs*1000, meanTrace);
xlabel('Time (ms)'); ylabel('Response');
```

**Usage:** README.md quick start section - must work without any external setup

### Example 2: Relative Path Pattern for Examples

```matlab
function runQuickstart()
    % Get example directory location
    exampleDir = fileparts(mfilename('fullpath'));

    % Add paths if not already added
    if ~exist('epicTreeTools', 'file')
        repoRoot = fileparts(exampleDir);
        addpath(fullfile(repoRoot, 'src'));
        addpath(fullfile(repoRoot, 'src', 'tree'));
        % ... other paths
    end

    % Load sample data (relative to example script)
    dataPath = fullfile(exampleDir, 'data', 'sample_epochs.mat');
    if ~exist(dataPath, 'file')
        error('Sample data not found: %s\nRun from examples/ directory', dataPath);
    end

    [data, ~] = loadEpicTreeData(dataPath);
    % ... rest of example
end
```

**Usage:** All example scripts in `examples/` directory - portable across installations

### Example 3: CITATION.cff Template

```yaml
cff-version: 1.2.0
message: "If you use this software, please cite it as below."
type: software
title: "EpicTreeGUI: Hierarchical Browser for Neurophysiology Data"
version: 1.0.0
date-released: 2026-02-28
authors:
  - family-names: "Author1"
    given-names: "FirstName"
    orcid: "https://orcid.org/0000-0000-0000-0001"
  - family-names: "Author2"
    given-names: "FirstName"
    orcid: "https://orcid.org/0000-0000-0000-0002"
repository-code: "https://github.com/username/epicTreeGUI"
keywords:
  - neuroscience
  - electrophysiology
  - data analysis
  - MATLAB
  - neurophysiology
license: MIT
abstract: >
  EpicTreeGUI is a pure MATLAB GUI for hierarchical browsing and analysis
  of neurophysiology epoch data. It provides dynamic tree organization
  using configurable splitting criteria and integrates with H5-based data
  storage for efficient lazy loading.
```

**Usage:** CITATION.cff at repository root - automatically parsed by GitHub and Zenodo

**Source:** [Citation File Format specification](https://citation-file-format.github.io/) and [GitHub CITATION files documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-citation-files)

### Example 4: .gitignore for MATLAB Projects

```gitignore
# MATLAB autosave files
*.asv
*.autosave

# MATLAB compiled files
*.mex*
*.p

# MATLAB code generation
codegen/
slprj/
sccprj/

# macOS system files
.DS_Store
.AppleDouble
.LSOverride

# Test data (too large to commit)
test_data/
*.h5

# User-specific configuration
*.mat.user
config_local.m

# Build artifacts
build/
dist/
```

**Usage:** .gitignore at repository root

**Source:** [MathWorks source control best practices](https://www.mathworks.com/help/matlab/matlab_prog/use-source-control-with-projects.html)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| BibTeX only for citation | CITATION.cff + BibTeX | ~2021 | GitHub auto-generates citation, Zenodo integration |
| .mltbx packaging | install.m script | Ongoing | Git-friendly, version control compatible, no GUI needed |
| Large sample data in repo | Data download scripts or Git LFS | ~2015 | Faster clone times, better repository performance |
| Monolithic README | README + docs/ directory | ~2018 | Cleaner root, structured documentation |
| LICENSE.txt | LICENSE (no extension) | ~2014 | GitHub auto-detection, ecosystem standard |

**Deprecated/outdated:**
- **Toolbox Packaging (.mltbx):** Still supported but git-unfriendly (binary format). Modern open-source MATLAB projects use install.m scripts instead.
- **All-caps files with extensions:** `LICENSE.txt`, `README.txt` → Use `LICENSE`, `README.md` for GitHub integration
- **Hosting sample data externally:** Pre-2015 pattern when GitHub had strict size limits. Now < 10 MB is acceptable in repo.

## Open Questions

1. **Author attribution for CITATION.cff**
   - What we know: Need author names and optionally ORCID identifiers
   - What's unclear: Who are the primary authors/contributors?
   - Recommendation: Use placeholder in template, populate during plan execution with actual names

2. **Version numbering for v1.0 release**
   - What we know: Roadmap calls this "v1.0 release"
   - What's unclear: Should CITATION.cff and CHANGELOG.md use 1.0.0 or wait for actual git tag?
   - Recommendation: Use 1.0.0 in Phase 1, create git tag in Phase 4 after quality assurance

3. **Sample data extraction criteria**
   - What we know: Need < 10 MB, authentic data, demonstrates full workflow
   - What's unclear: Which specific epochs/protocols to include for maximum pedagogical value?
   - Recommendation: Extract during plan execution - 1 cell type (RGC), 2-3 protocols (SingleSpot, ExpandingSpots), ~50 epochs

4. **Legacy code preservation details**
   - What we know: Move to `docs/legacy/`, preserve for reference
   - What's unclear: Should we preserve git history in a separate branch?
   - Recommendation: No separate branch needed - just move files, history preserved in git

## Sources

### Primary (HIGH confidence)

- [MIT License - choosealicense.com](https://choosealicense.com/licenses/mit/) - Official OSI-approved template
- [Citation File Format](https://citation-file-format.github.io/) - Official CFF specification v1.2.0
- [GitHub CITATION files](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-citation-files) - GitHub integration documentation
- [MathWorks Toolbox Design](https://github.com/mathworks/toolboxdesign) - Official best practices repository
- [MathWorks Source Control](https://www.mathworks.com/help/matlab/matlab_prog/use-source-control-with-projects.html) - Official documentation

### Secondary (MEDIUM confidence)

- [GitHub Best Practices for Repositories](https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories) - File size recommendations
- [The Turing Way - Software Citation](https://book.the-turing-way.org/communication/citable/citable-cff/) - Academic software citation practices
- [FieldTrip Toolbox Installation](https://www.fieldtriptoolbox.org/faq/matlab/installation/) - Real-world MATLAB toolbox path setup patterns

### Tertiary (LOW confidence)

- Community discussions on MATLAB Central about repository structure - informative but not authoritative

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All recommendations from official sources (MIT, CFF, MathWorks)
- Architecture: HIGH - MathWorks toolbox design guide + verified ecosystem patterns
- Pitfalls: HIGH - Derived from current repository analysis + MATLAB Central common issues
- Sample data strategy: MEDIUM - Best practices clear, specific extraction strategy is Claude's discretion

**Research date:** 2026-02-16
**Valid until:** 90 days (stable domain - licensing and repository practices change slowly)

**Current repository metrics:**
- Root files: 68 items (target: 6)
- Loose scripts: 23 (target: 0)
- Markdown files: 30+ scattered (target: all in docs/)
- Large directories: old_epochtree (17 MB), new_retinanalysis (282 MB), test_data (251 MB)
- Sample data available: 183 KB .mat file (usable as-is)
- Examples: 2 scripts with hardcoded paths (need fixing)
