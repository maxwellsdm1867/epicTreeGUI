# Technology Stack: MATLAB Package Documentation

**Project:** epicTreeGUI v1.0 Release
**Researched:** 2026-02-06
**Confidence:** MEDIUM (based on training data through Jan 2025, no external verification available)

## Executive Summary

MATLAB package documentation for GitHub follows distinct patterns that differ from traditional software documentation. The ecosystem has standardized on Markdown for GitHub-facing docs (README, guides) while using MATLAB's native publish system for rendered HTML documentation. Live Scripts (.mlx) are the gold standard for tutorials and examples but require MATLAB to run. The recommended stack balances accessibility (Markdown) with interactive capability (Live Scripts) and professional presentation (MATLAB publish).

**Key Insight:** Academic MATLAB projects use a dual-format strategy:
1. **Markdown** for README, user guides, and reference (GitHub-native, works everywhere)
2. **MATLAB scripts (.m)** for examples (version control friendly, readable as text)
3. **Live Scripts (.mlx)** optional for interactive tutorials (binary format, requires MATLAB)

## Recommended Stack

### Documentation Formats

| Technology | Purpose | Priority | Why |
|------------|---------|----------|-----|
| **Markdown (.md)** | README, user guides, API reference | CRITICAL | GitHub-native rendering, searchable, version control friendly, accessible without MATLAB |
| **MATLAB Scripts (.m)** | Runnable examples, test scripts | CRITICAL | Plain text, version control friendly, executable, readable in any editor |
| **MATLAB Comments** | Inline help system | CRITICAL | Powers `help` and `doc` commands, zero-overhead documentation |
| **HTML (generated)** | Published documentation site | OPTIONAL | Professional presentation via `publish()`, GitHub Pages compatible |
| **Live Scripts (.mlx)** | Interactive tutorials | OPTIONAL | Rich formatting, inline outputs, but binary format complicates version control |

### Documentation Tools

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| **MATLAB publish()** | R2020b+ | Convert .m to HTML | Generate professional docs for GitHub Pages |
| **MATLAB help system** | R2020b+ | Built-in documentation | Function-level help via comments |
| **GitHub Markdown** | GFM | README and guides | All user-facing docs |
| **MATLAB Live Editor** | R2020b+ | Create .mlx tutorials | Interactive walkthroughs (optional) |

### File Structure Standards

| Category | Location | Format | Purpose |
|----------|----------|--------|---------|
| **Landing page** | `/README.md` | Markdown | GitHub front page, quick start |
| **User guide** | `/docs/UserGuide.md` | Markdown | Installation, configuration, usage |
| **Examples** | `/examples/*.m` | MATLAB script | Runnable code demonstrating workflows |
| **Tutorial** | `/docs/Tutorial.md` or `/examples/GettingStarted.mlx` | Markdown or Live Script | Step-by-step walkthrough |
| **API Reference** | `/docs/API.md` or inline comments | Markdown or MATLAB help | Function documentation |
| **License** | `/LICENSE` or `/LICENSE.txt` | Plain text | Open source license |
| **Citation** | `/CITATION.cff` | CFF format | Optional, for academic citation |

## Detailed Recommendations

### 1. README.md Structure

**Confidence:** HIGH (standard across MATLAB projects on GitHub)

**Essential sections** (in order):
```markdown
# Project Title
Brief one-liner description

## Features
- Bullet list of key capabilities
- Focus on user value

## Installation
Step-by-step setup instructions

## Quick Start
Minimal working example (< 10 lines)

## Usage
Common use cases with code examples

## Documentation
Links to detailed guides

## Requirements
- MATLAB version
- Toolboxes (if any)
- Data dependencies

## License
State license type with link to LICENSE file

## Citation
How to cite (if academic)

## Contact
Where to get help
```

**MATLAB-specific best practices:**
- Include `addpath()` setup in installation
- Show function signatures with expected inputs/outputs
- Provide sample data or link to test data
- Mention toolbox dependencies explicitly
- State minimum MATLAB version (R20XXa format)

**Anti-patterns to avoid:**
- Assuming familiarity with internal jargon
- Long code blocks without explanations
- Screenshots that become outdated
- Missing requirements section

### 2. Example Scripts Pattern

**Confidence:** HIGH (industry standard)

**Format:** Plain .m files, not .mlx

**Why .m over .mlx:**
- Version control friendly (plain text)
- Readable in GitHub web UI
- Executable in any MATLAB version
- No binary diff issues
- Searchable via grep/ripgrep

**Example script template:**
```matlab
%% Example: [Descriptive Title]
% Brief description of what this example demonstrates
%
% Prerequisites:
%   - List dependencies
%   - Data requirements
%
% Expected output:
%   - What user should see
%
% Author: [Name], [Date]

%% Setup Section
% Clear workspace and configure paths
clear; clc;
addpath(genpath('../src'));

%% Section 1: Load Data
% Explain what's happening
data = load('example_data.mat');

%% Section 2: Process
% More explanation
result = processData(data);

%% Section 3: Visualize
% Show results
figure;
plot(result);
title('Example Output');
```

**Key features:**
- Sectioned with `%%` for cell-mode execution
- Comments explain WHY, not just WHAT
- Standalone (can run independently)
- Includes expected output descriptions
- Clean workspace at start
- Relative paths for portability

### 3. Inline Documentation (Help System)

**Confidence:** HIGH (MATLAB standard)

**Format:** H1 line + structured comments

**Template:**
```matlab
function [output1, output2] = myFunction(input1, input2, options)
% MYFUNCTION Brief one-line description
%
% Syntax:
%   output = myFunction(input1, input2)
%   [output1, output2] = myFunction(input1, input2, 'Name', Value)
%
% Description:
%   Longer description of what the function does. Explain the purpose
%   and key behavior.
%
% Inputs:
%   input1 - Description (type, size)
%   input2 - Description (type, size)
%
% Name-Value Arguments (optional):
%   'OptionName' - Description (default: value)
%
% Outputs:
%   output1 - Description (type, size)
%   output2 - Description (type, size)
%
% Examples:
%   % Basic usage
%   result = myFunction(data, params);
%
%   % With options
%   [out1, out2] = myFunction(data, params, 'Verbose', true);
%
% See also: RELATEDFUNC1, RELATEDFUNC2

% Implementation code starts here
```

**This powers:**
- `help myFunction` in command window
- `doc myFunction` in documentation browser
- Code completion hints
- Function signature tooltips

**Best practices:**
- H1 line (first comment) is all caps, brief
- Syntax section shows all calling patterns
- Examples use realistic inputs
- See also links related functions
- Consistent formatting across codebase

### 4. User Guide Structure

**Confidence:** HIGH (academic software pattern)

**Format:** Markdown at `/docs/UserGuide.md`

**Sections:**
1. **Installation** - Detailed setup, path configuration, verification
2. **Configuration** - Settings, preferences, data paths
3. **Core Concepts** - Domain-specific knowledge needed
4. **Basic Usage** - Simple workflows with explanations
5. **Advanced Features** - Power-user capabilities
6. **Troubleshooting** - Common errors and solutions
7. **API Reference** - Function documentation (or link to separate doc)

**MATLAB-specific content:**
- Path management (`addpath`, startup.m)
- Data format specifications
- Toolbox dependencies and alternatives
- Performance considerations (vectorization, memory)
- Integration with MATLAB workflows

### 5. Tutorial Format

**Confidence:** MEDIUM (two viable approaches)

**Option A: Markdown Tutorial** (recommended for GitHub)
- `/docs/Tutorial.md` or `/docs/GettingStarted.md`
- Step-by-step narrative with code blocks
- Screenshots of expected output
- Copy-pasteable code snippets
- Progression from simple to complex

**Option B: Live Script Tutorial** (MATLAB-native)
- `/examples/GettingStarted.mlx`
- Interactive with formatted text and code
- Inline outputs and figures
- Rich formatting (equations, images)
- **Downside:** Binary format, not viewable on GitHub

**Hybrid approach:** Both formats
- Markdown tutorial for GitHub browsing
- Live Script for interactive execution
- Keep content synchronized

**Tutorial structure:**
1. **Prerequisites** - What to install, sample data
2. **First Steps** - Absolute minimum to see results
3. **Building Up** - Incremental feature introduction
4. **Common Workflows** - Real-world usage patterns
5. **Next Steps** - Links to advanced topics

### 6. License File

**Confidence:** HIGH (GitHub standard)

**Format:** Plain text at `/LICENSE` or `/LICENSE.txt`

**Recommended for academic/research MATLAB:**
- **MIT License** - Permissive, widely used, simple
- **BSD 3-Clause** - Similar to MIT, explicit patent grant
- **GPL v3** - Copyleft if derivatives must be open

**MIT License for epicTreeGUI:**
```
MIT License

Copyright (c) [Year] [Author/Institution]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

[Standard MIT text]
```

**Why MIT:**
- Most permissive (allows commercial use)
- Compatible with academic research
- Matches existing Rieke Lab projects
- No warranty liability

### 7. Optional: GitHub Pages Documentation

**Confidence:** MEDIUM (MATLAB publish workflow)

**When to use:**
- Project has 10+ functions
- Need searchable API reference
- Want professional presentation
- Multiple interconnected docs

**Workflow:**
```matlab
% In project root
publish('src/myFunction.m', 'html');
publish('examples/example1.m', 'html');
```

**Setup GitHub Pages:**
1. Generate HTML via `publish()`
2. Place in `/docs/` directory
3. Configure repo: Settings → Pages → Source: `docs/`
4. GitHub serves at `username.github.io/repo`

**MATLAB publish() features:**
- Converts .m to HTML with syntax highlighting
- Executes code and embeds outputs
- Generates figure images automatically
- Creates table of contents
- Consistent styling

**Limitations:**
- Requires MATLAB to regenerate
- Manual process (not auto-updated)
- Output files are generated (version control bloat)
- Less flexible than modern static site generators

### 8. Citation File (Optional)

**Confidence:** MEDIUM (emerging standard)

**Format:** YAML at `/CITATION.cff`

**When to include:**
- Academic software
- Publishable research tool
- Want proper citation credit

**Template:**
```yaml
cff-version: 1.2.0
message: "If you use this software, please cite it as below."
authors:
  - family-names: "Your Last Name"
    given-names: "Your First Name"
    orcid: "https://orcid.org/0000-0000-0000-0000"
title: "EpicTreeGUI: Hierarchical Neurophysiology Data Browser"
version: 1.0.0
date-released: 2026-02-06
url: "https://github.com/username/epicTreeGUI"
```

**Not critical for v1.0 release** - can add later if users request citation format.

## Implementation Strategy

### Phase 1: Essential Documentation (MVP)

**Priority 1:**
1. Polish `/README.md` as GitHub landing page
2. Create/update `/docs/UserGuide.md` with installation + configuration
3. Clean up `/examples/` directory with 3-5 .m scripts
4. Add `/LICENSE` file (MIT recommended)
5. Ensure all functions have help comments

**Deliverable:** Users can discover, install, and run basic workflows

### Phase 2: Enhanced Documentation

**Priority 2:**
1. Create `/docs/Tutorial.md` with step-by-step walkthrough
2. Expand examples to cover all major workflows
3. Add API reference document or enhance inline help
4. Consider CITATION.cff if academic publication planned

**Deliverable:** Users can learn advanced features independently

### Phase 3: Optional Polish

**Priority 3:**
1. Convert examples to Live Scripts (.mlx) for interactive version
2. Set up GitHub Pages with published HTML
3. Add badges to README (MATLAB version, license, etc.)
4. Create demo GIFs or videos

**Deliverable:** Professional presentation, multimedia resources

## Alternatives Considered

| Format | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Sphinx + MATLAB** | Professional docs, auto-generation | Complex setup, Python dependency | ❌ Overkill for single toolbox |
| **MkDocs** | Modern static site | Requires Python, manual MATLAB integration | ❌ Not MATLAB-native |
| **ReadTheDocs** | Free hosting, search | Python-focused, MATLAB support limited | ❌ Better for Python projects |
| **Jekyll + GitHub Pages** | Free hosting | Ruby dependency, manual updates | ❌ Complexity not justified |
| **Pure Markdown** | Simple, version control friendly, GitHub-native | No fancy rendering | ✅ **Recommended** |
| **MATLAB publish()** | Native, executes code | Manual regeneration, version control bloat | ⚠️ Optional for HTML output |
| **Live Scripts** | Interactive, rich formatting | Binary format, GitHub doesn't render | ⚠️ Supplementary to .m examples |

## Tools NOT Needed

| Tool | Why Skip |
|------|----------|
| **Doxygen** | Designed for C++, awkward for MATLAB |
| **JavaDoc** | Java-specific, epicTreeGUI is pure MATLAB |
| **MATLAB Toolbox Packaging** | Overkill for GitHub distribution, use File Exchange if needed later |
| **Automated API doc generators** | MATLAB help system + manual docs sufficient for this scale |

## File Organization Recommendations

```
epicTreeGUI/
├── README.md                   # Landing page with quick start
├── LICENSE                     # MIT License
├── CITATION.cff                # Optional: Citation metadata
├── docs/
│   ├── UserGuide.md           # Installation, configuration, usage
│   ├── Tutorial.md            # Step-by-step walkthrough
│   ├── API.md                 # Function reference (or use inline help)
│   └── Troubleshooting.md     # Common issues and solutions
├── examples/
│   ├── basic_usage.m          # Minimal working example
│   ├── tree_navigation.m      # Navigation patterns
│   ├── data_analysis.m        # Analysis workflow
│   ├── custom_splitters.m     # Extending the system
│   └── batch_processing.m     # Advanced usage
├── src/                        # Source code with inline help comments
├── tests/                      # Test scripts (separate from examples)
└── data/                       # Sample/test data (optional)
```

## EpicTreeGUI-Specific Recommendations

### README.md Updates Needed

**Current state:** Comprehensive but developer-focused
**Target:** User-focused with clear value proposition

**Recommended changes:**
1. **Lead with value:** "Browse and analyze neurophysiology data hierarchically"
2. **Quick start:** Show 3-5 line example that works immediately
3. **Features:** Visual tree + lazy loading + dynamic organization
4. **Requirements:** MATLAB R2020b+, no toolboxes
5. **Installation:** Clone + addpath + configuration
6. **Screenshots:** Tree browser + data viewer side-by-side
7. **Links:** Docs, examples, issues
8. **License:** MIT with link to LICENSE file

### User Guide Enhancements

**Current state:** Good structure, needs completion
**Missing sections:**
- Installation verification ("Did it work?")
- Configuration troubleshooting (H5 path issues)
- Data format requirements (link to specification)
- Performance tuning (tree depth, lazy loading)

### Examples Directory Strategy

**Current state:** 2 examples (test_data_loading.m, example_analysis_workflow.m)
**Recommended:** 5 focused examples

1. **basic_usage.m** - Load data, build tree, launch GUI (< 20 lines)
2. **tree_navigation.m** - Navigate, query, store results (existing workflow)
3. **data_analysis.m** - Extract data, compute stats, plot (existing workflow)
4. **custom_splitters.m** - Create custom splitter function
5. **batch_processing.m** - Analyze all conditions systematically

Each example:
- Standalone (runs independently)
- Well-commented (explain WHY)
- Expected output described
- Uses sample data path

### Tutorial Content

**Recommended flow:**

**Part 1: First Steps (10 minutes)**
1. Install and configure
2. Load sample data
3. Launch GUI
4. Navigate tree
5. View response trace

**Part 2: Analysis Workflow (15 minutes)**
6. Select epochs of interest
7. Extract data with getSelectedData()
8. Compute mean response
9. Plot results
10. Store results at node

**Part 3: Advanced (20 minutes)**
11. Build custom tree hierarchy
12. Create custom splitter
13. Batch analysis over conditions
14. Compare conditions with MeanSelectedNodes()

### Documentation Priorities for v1.0

**MUST HAVE (blocks release):**
- [ ] README.md polished and user-focused
- [ ] LICENSE file (MIT)
- [ ] docs/UserGuide.md complete with troubleshooting
- [ ] examples/ directory with 3-5 runnable scripts
- [ ] All src/ functions have help comments

**SHOULD HAVE (strongly recommended):**
- [ ] docs/Tutorial.md with step-by-step walkthrough
- [ ] docs/Troubleshooting.md separate document
- [ ] Example data or clear link to sample data

**NICE TO HAVE (post-v1.0):**
- [ ] CITATION.cff for academic citation
- [ ] GitHub Pages with published HTML docs
- [ ] Live Script tutorials (.mlx)
- [ ] Demo video or animated GIFs

## Quality Checklist

Before release, verify:

- [ ] README renders correctly on GitHub
- [ ] All examples run without modification
- [ ] Help text accessible via `help functionName`
- [ ] No broken links in documentation
- [ ] Sample data paths are configurable
- [ ] Installation instructions tested on clean system
- [ ] License file is valid and complete
- [ ] Documentation uses consistent terminology
- [ ] Code examples use current API (not deprecated)

## Sources and Confidence

**Confidence Assessment:**

| Topic | Confidence | Evidence |
|-------|------------|----------|
| Markdown for README/guides | HIGH | GitHub standard, verified by existing projects |
| .m scripts for examples | HIGH | MATLAB community standard |
| Inline help comments | HIGH | MATLAB documentation system design |
| MIT License for academic | HIGH | Matches existing Rieke Lab projects |
| MATLAB publish() workflow | MEDIUM | Training data, no external verification |
| Live Scripts (.mlx) | MEDIUM | Format exists but pros/cons based on experience |
| GitHub Pages setup | MEDIUM | General GitHub knowledge applied to MATLAB |
| CITATION.cff | LOW | Emerging standard, adoption varies |

**Sources:**
- Training data through January 2025
- Existing epicTreeGUI documentation (README.md, UserGuide.md, examples/)
- Legacy Rieke Lab projects (LICENSE files examined)
- MATLAB documentation patterns (help system, publish())

**Limitations:**
- No access to Context7 or current MATLAB documentation
- No web search verification of 2026 standards
- Recommendations based on training data, not current best practices
- GitHub/MATLAB integration may have changed since training cutoff

**Verification needed:**
- Current MATLAB publish() capabilities in R2020b+
- GitHub Pages markdown rendering features
- Community preferences for .m vs .mlx examples
- CITATION.cff adoption in MATLAB community
