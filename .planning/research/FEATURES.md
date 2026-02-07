# Feature Landscape: Documentation for MATLAB Research Tools

**Domain:** Scientific software documentation (MATLAB research tools on GitHub)
**Researched:** 2026-02-06
**Confidence:** HIGH (based on established scientific software standards and MATLAB ecosystem conventions)

## Table Stakes

Features users expect. Missing = users abandon the tool without trying it.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **README.md** | GitHub landing page; first impression; gatekeeps all other docs | Medium | Must answer: What is this? Who is it for? How do I install it? How do I get started? |
| **LICENSE file** | Legal requirement for reuse; academic users check licenses before adoption | Low | MIT or GPL typical for research tools; absence blocks institutional use |
| **Installation instructions** | Users cannot use tool if they can't install it | Low-Medium | MATLAB path setup, dependencies, test that it works |
| **Minimal working example** | Proves tool works; gives users confidence to invest time learning | Medium | Single script that runs end-to-end with sample data |
| **API reference** | MATLAB users expect documented function signatures and parameters | Medium-High | Function headers with input/output specs; auto-generated with `help` command |
| **Quickstart guide** | Users want to accomplish something useful in <30 min | Medium | "Your first analysis" tutorial; uses real workflow |
| **Data format specification** | Scientific tools are useless without knowing input format | Low-Medium | What fields are required? What are units? What is structure? |
| **Citation information** | Academic users need to cite software in papers | Low | CITATION.cff or "How to cite" section in README |

## Differentiators

Features that set documentation apart. Not expected, but valued. Increase adoption and user success.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Conceptual overview** | Users understand *why* design choices were made; builds mental model | Medium | "Architecture" or "Key Concepts" section explaining tree structure, selection model, etc. |
| **Multiple example scripts** | Different user workflows; users find examples matching their use case | Medium-High | Common analysis patterns (by cell type, by stimulus, batch processing) |
| **Troubleshooting guide** | Reduces support burden; users self-solve common problems | Medium | "Common errors and solutions"; known gotchas |
| **Comparison to alternatives** | Users understand when to use this tool vs others | Low-Medium | "Why epicTreeGUI vs manual scripts?" "Replaces legacy epochTreeGUI" |
| **Visual diagrams** | Scientific users are visual; diagrams clarify complex concepts faster | Medium | Data flow diagram, tree organization example, GUI screenshot with annotations |
| **Video walkthrough** | Highest engagement for new users; shows tool in action | High | 5-10 min screencast of basic workflow (optional but high-impact) |
| **Code comments** | Enables users to modify/extend tool | Low | Inline comments explaining non-obvious logic |
| **Changelog** | Shows active development; helps users track breaking changes | Low | CHANGELOG.md with versions and notable changes |
| **FAQ section** | Anticipates user questions; reduces repetitive support | Low-Medium | Collect questions during beta testing |
| **Performance notes** | Scientific users care about scalability (dataset size limits) | Low | "Works with N epochs; tested up to X GB files" |
| **Contributing guide** | Signals community-friendly project; enables extensions | Medium | CONTRIBUTING.md with code style, testing, PR process |
| **Example output** | Users see what results look like before investing time | Low | Figures, plots, or analysis outputs in examples/ |

## Anti-Features

Features to explicitly NOT build. Common mistakes in research software documentation.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Auto-generated docs without curation** | Cluttered, unhelpful; lists every private function | Write focused API docs for public interface only; use `help` headers |
| **PDF-only documentation** | Not searchable on GitHub; extra download step; version drift | Use Markdown in repo; optionally generate PDF with pandoc |
| **Installation via manual file copying** | Error-prone; doesn't scale; users forget steps | Use `addpath(genpath())` pattern or MATLAB toolbox packaging |
| **Examples that require unavailable data** | Users can't run examples; frustration | Include sample data in repo OR synthetic data generator |
| **Jargon-heavy README** | Excludes users outside narrow subdomain | Define domain terms; link to background reading |
| **Version-less documentation** | Users don't know if docs match their version | Use versioned releases; docs in repo match code version |
| **Undocumented dependencies** | Silent failures on missing toolboxes | List required MATLAB version + toolboxes in README; add version checks in code |
| **Tutorial that's just API dump** | Users want workflows, not function lists | Show end-to-end analysis; explain decision points |
| **No error handling in examples** | Examples crash on real data; users blame tool | Add input validation, error messages with solutions |
| **Docs in separate repo/wiki** | Version mismatch; dead links; users don't find docs | Keep docs in `/docs` or root; travel with code |
| **"See code for details"** | Forces users to read implementation; high barrier | Document behavior contracts; code is implementation detail |

## Documentation Component Breakdown

### Essential README Structure (Table Stakes)

**Length:** 200-500 lines
**Content:**
1. **Header**: Name, tagline (1 sentence describing tool)
2. **Badges**: Build status, license, MATLAB version
3. **What it does**: 2-3 sentences, non-technical
4. **Key features**: Bullet list, user-facing benefits
5. **Installation**: Step-by-step, copy-paste commands
6. **Quick example**: 10-15 lines of code that runs
7. **Documentation links**: Where to find detailed guides
8. **Citation**: How to cite in papers
9. **License**: Type and link to LICENSE file
10. **Contact**: How to report issues

**MATLAB toolbox examples:**
- FieldTrip: Excellent README structure, clear installation
- SPM: Strong "What is it?" section
- EEGLAB: Good feature highlights for researchers

### User Guide (Table Stakes)

**Length:** 1000-3000 lines
**Format:** Multi-page Markdown or single PDF
**Content:**
1. **Installation and setup**: Detailed, OS-specific if needed
2. **Configuration**: How to set paths, preferences
3. **Core concepts**: Data model, tree structure, selection system
4. **Basic workflows**: Step-by-step common tasks
5. **Advanced features**: Power-user capabilities
6. **Reference**: Function listing with signatures
7. **Troubleshooting**: Common errors

**Where:** `/docs/USER_GUIDE.md` or `/docs/user-guide/` directory

### Example Scripts (Table Stakes)

**Count:** 3-6 scripts minimum
**Format:** Executable .m files with heavy comments
**Content:**
1. `example_01_basic_loading.m`: Load data, display tree
2. `example_02_filtering.m`: Select epochs, extract data
3. `example_03_analysis.m`: Compute something meaningful
4. `example_04_batch.m`: Process multiple files
5. `example_05_custom_splitter.m`: Extend system (advanced)

**Where:** `/examples/` directory with own README

### Tutorial (Table Stakes)

**Length:** 500-1500 lines
**Format:** Step-by-step walkthrough, numbered sections
**Content:**
1. **Goal statement**: What you'll accomplish
2. **Prerequisites**: Required background, installed tools
3. **Step-by-step instructions**: With expected output at each step
4. **Explanation sections**: Why each step matters
5. **Checkpoint validation**: "You should see X"
6. **Next steps**: Links to advanced topics

**Where:** `/docs/TUTORIAL.md` or `/docs/getting-started.md`

### API Reference (Table Stakes for MATLAB)

**Format:** MATLAB-standard function headers
**Auto-generated:** Use `help functionName` to display
**Content per function:**
```matlab
function [output1, output2] = functionName(input1, input2, options)
% FUNCTIONNAME Brief one-line description
%
% Syntax:
%   output = functionName(input1)
%   [out1, out2] = functionName(input1, input2)
%   [...] = functionName(..., Name, Value)
%
% Description:
%   Detailed description of what function does, when to use it,
%   and how it relates to other functions.
%
% Input Arguments:
%   input1 - Description (type: expectedType)
%   input2 - Description (type: expectedType)
%
% Output Arguments:
%   output1 - Description (type: returnType)
%   output2 - Description (type: returnType)
%
% Examples:
%   % Example 1: Basic usage
%   result = functionName(data);
%
%   % Example 2: With options
%   [r1, r2] = functionName(data, params, 'Option', value);
%
% See also: RELATEDFUNCTION1, RELATEDFUNCTION2
```

**Where:** In-code headers; optionally compiled to `/docs/API.md`

### Architecture Documentation (Differentiator)

**Length:** 300-800 lines
**Content:**
1. **System overview**: High-level components
2. **Data flow diagram**: How data moves through system
3. **Key abstractions**: Tree nodes, epoch structures, selection model
4. **Design decisions**: Why certain choices were made
5. **Extension points**: Where users can customize

**Where:** `/docs/ARCHITECTURE.md` or `DESIGN.md`

### Sample Data (Differentiator)

**Size:** <10 MB ideally (GitHub-friendly)
**Format:** Same format as real data, but minimal
**Content:**
- Representative structure
- Small enough to load quickly
- Covers major use cases
- Documented in own README

**Where:** `/examples/data/` or `/test_data/` with `DATA_README.md`

## Documentation Depth by User Journey

### First-time user (0-30 minutes)
**Needs:** What is this? Will it work for me? Can I install it?
**Documents:** README (hero section, features), LICENSE, Installation section
**Complexity:** Low; must be skimmable

### Getting started (30 min - 2 hours)
**Needs:** Make it work with my data; see a successful analysis
**Documents:** Quickstart/Tutorial, first example script, data format spec
**Complexity:** Medium; hands-on, step-by-step

### Regular user (2+ hours, days/weeks)
**Needs:** Learn all features; optimize workflow; troubleshoot issues
**Documents:** User guide (comprehensive), all examples, API reference, troubleshooting
**Complexity:** High; reference material, searchable

### Power user / Extender (ongoing)
**Needs:** Understand internals; add features; contribute
**Documents:** Architecture docs, code comments, contributing guide, design rationale
**Complexity:** High; implementation details

## MATLAB-Specific Considerations

### Path Management
Document clearly:
```matlab
% Option 1: Temporary (this session)
addpath(genpath('/path/to/epicTreeGUI'));

% Option 2: Permanent
addpath(genpath('/path/to/epicTreeGUI'));
savepath;

% Option 3: Via startup.m
% Add above to ~/Documents/MATLAB/startup.m
```

### Toolbox Dependencies
Always specify:
- MATLAB version (R2020a+)
- Required toolboxes (Signal Processing, Statistics)
- Optional toolboxes (Image Processing for visualizations)

Add version check to main function:
```matlab
if verLessThan('matlab', '9.8')  % R2020a = 9.8
    error('Requires MATLAB R2020a or later');
end
```

### Help System Integration
MATLAB users expect:
- `help epicTreeGUI` works
- `doc epicTreeGUI` shows formatted docs (if toolbox packaging used)
- Tab-completion for function names
- Consistent naming (camelCase for functions)

### Example Data in MATLAB Format
Scientific MATLAB users expect `.mat` files:
- Include `exampleData.mat` with documented structure
- Or provide data generator script
- Document variable names and units

## Completeness Criteria

Documentation is "complete" when:

**Minimum viable (required for public release):**
- [ ] README answers: what, why, who, how-to-install, minimal example
- [ ] LICENSE file present
- [ ] Installation instructions tested on clean MATLAB install
- [ ] At least one working example with sample data
- [ ] Function headers follow MATLAB help conventions
- [ ] Data format specification exists
- [ ] Citation information provided

**Production ready (builds user confidence):**
- [ ] Quickstart tutorial (30-min workflow)
- [ ] 3-5 example scripts covering common use cases
- [ ] User guide covers all major features
- [ ] Troubleshooting section for common errors
- [ ] API reference for all public functions
- [ ] Visual diagram of system architecture
- [ ] CHANGELOG tracking versions

**Exceptional (maximizes adoption):**
- [ ] Video walkthrough of basic workflow
- [ ] Comparison to alternative tools
- [ ] Performance characteristics documented
- [ ] FAQ from beta user questions
- [ ] Contributing guide for extensions
- [ ] Multiple tutorials for different user levels
- [ ] Published examples with figures

## Effort Estimates

| Documentation Type | Effort (hours) | Priority |
|--------------------|---------------|----------|
| README.md | 4-8 | CRITICAL |
| LICENSE | 0.5 | CRITICAL |
| Installation guide | 2-4 | CRITICAL |
| Minimal working example | 2-4 | CRITICAL |
| Data format spec | 2-3 | CRITICAL |
| Citation info | 1 | CRITICAL |
| Quickstart tutorial | 6-10 | HIGH |
| Example scripts (3-5) | 8-15 | HIGH |
| API reference (headers) | 10-20 | HIGH |
| User guide (comprehensive) | 15-30 | HIGH |
| Architecture docs | 6-12 | MEDIUM |
| Troubleshooting guide | 4-8 | MEDIUM |
| Video walkthrough | 8-16 | MEDIUM |
| FAQ | 3-6 | LOW |
| Contributing guide | 3-5 | LOW |
| CHANGELOG | 2 (initial) | LOW |

**Total for minimum viable:** 15-25 hours
**Total for production ready:** 50-80 hours
**Total for exceptional:** 80-120 hours

## Scientific Software Patterns

### Reproducibility Focus
Research software must enable reproducible results:
- Document MATLAB version and toolbox versions used
- Include version number in software (e.g., `epicTreeGUI.version()`)
- Recommend users cite specific version
- Consider archiving on Zenodo for DOI

### Domain Vocabulary
For neuroscience tools:
- Define "epoch", "cell type", "stimulus parameters" on first use
- Link to background papers for concepts (RGC subtypes, etc.)
- Glossary section for domain-specific terms

### Data Provenance
Users need to track analysis history:
- Document how to record analysis parameters
- Show how to save analysis outputs with metadata
- Example of analysis log/provenance file

### Validation Examples
Scientific users want to verify correctness:
- Include "known-answer" test (synthetic data with expected result)
- Compare to published analysis if replacing legacy tool
- Document validation against original epochTreeGUI

## Well-Documented MATLAB Research Tools (Reference Examples)

**High-quality examples to study:**

1. **FieldTrip** (neuroscience)
   - Excellent tutorial structure
   - FAQ is comprehensive
   - Clear installation with dependency checking
   - Multiple example datasets

2. **SPM** (neuroimaging)
   - Strong conceptual overview
   - Extensive manual (but perhaps too extensive)
   - Good GUI documentation with screenshots

3. **EEGLAB** (electrophysiology)
   - Plugin architecture well-documented
   - Tutorial videos available
   - Clear comparison to alternatives

4. **gramm** (plotting)
   - Exceptional README with visual examples
   - Gallery of outputs
   - Comparison to MATLAB built-ins

5. **YALMIP** (optimization)
   - Tutorial-driven documentation
   - Example-heavy approach
   - Clear "getting started" path

**Common success patterns:**
- Visual examples (screenshots, plots)
- Progressive complexity (basic → advanced)
- Runnable code snippets throughout
- Clear comparison to alternatives
- Active community (GitHub issues used for support)

## Anti-Patterns from Poor Examples

**What NOT to do (from problematic tools):**

1. **The "README is just description" pattern**
   - Long prose about what tool does
   - No installation or usage instructions
   - Result: Users can't actually use it

2. **The "see paper for details" pattern**
   - README says "described in [paywalled paper]"
   - No standalone documentation
   - Result: Users without journal access blocked

3. **The "expert-only" pattern**
   - Assumes deep domain knowledge
   - No definitions of terms
   - Result: Limits adoption to small in-group

4. **The "stale wiki" pattern**
   - Documentation in GitHub wiki
   - Wiki not updated with code changes
   - Result: Users follow outdated instructions, frustration

5. **The "contact me for help" pattern**
   - No public docs, just email for questions
   - Doesn't scale, not searchable
   - Result: High support burden, users give up

## Recommendations for epicTreeGUI

### Immediate priorities (Week 1-2):
1. **README.md**: Clear what/why/how structure with installation
2. **LICENSE**: MIT recommended for max reuse
3. **Minimal example**: Single script that works end-to-end
4. **Installation test**: `test_installation.m` that verifies setup

### Short-term priorities (Week 3-4):
5. **Quickstart tutorial**: 30-min "your first analysis" walkthrough
6. **Example scripts**: 3-5 covering common workflows
7. **Data format spec**: Document epoch structure, required fields
8. **Function headers**: Ensure all public functions have help text

### Medium-term priorities (Month 2):
9. **User guide**: Comprehensive reference for all features
10. **Architecture doc**: Explain tree model, selection system
11. **Troubleshooting**: Common errors from beta users
12. **Video walkthrough**: 5-10 min screencast (optional but high-impact)

### Leverage existing assets:
- CLAUDE.md already has architecture info → extract to docs/ARCHITECTURE.md
- Test scripts have usage examples → refactor to examples/ with comments
- TRD document has technical details → summarize key parts for users

### Documentation structure recommendation:
```
epicTreeGUI/
├── README.md                 (landing page, installation, quick example)
├── LICENSE                   (MIT)
├── CITATION.cff             (citation metadata)
├── CHANGELOG.md             (version history)
├── docs/
│   ├── QUICKSTART.md        (30-min tutorial)
│   ├── USER_GUIDE.md        (comprehensive reference)
│   ├── ARCHITECTURE.md      (system design, for extenders)
│   ├── API.md               (function reference, auto-generated)
│   ├── TROUBLESHOOTING.md   (common errors and solutions)
│   ├── DATA_FORMAT.md       (epoch structure specification)
│   └── FAQ.md               (questions from users)
├── examples/
│   ├── README.md            (overview of examples)
│   ├── data/
│   │   ├── sample_data.mat  (minimal test dataset)
│   │   └── DATA_README.md   (describes sample data)
│   ├── 01_basic_loading.m
│   ├── 02_filtering_and_selection.m
│   ├── 03_simple_analysis.m
│   ├── 04_batch_processing.m
│   └── 05_custom_splitter.m
└── tests/                    (separate from examples)
```

## Success Metrics

Documentation quality can be measured by:

**Quantitative:**
- Time for new user to run first example (target: <15 min)
- Percentage of GitHub issues that are documentation questions (target: <20%)
- README view-to-clone conversion rate (target: >30%)

**Qualitative:**
- Can user install without assistance?
- Can user complete quickstart without asking questions?
- Do users cite the software in papers?
- Do users contribute extensions?

**Review checklist for completeness:**
- [ ] Can complete stranger install and run in 30 minutes?
- [ ] Are all error messages documented in troubleshooting?
- [ ] Is every public function documented with help text?
- [ ] Can users find examples matching their use case?
- [ ] Is it clear when to use this tool vs alternatives?
- [ ] Can users cite the software properly?
- [ ] Are there visual examples of output?

## Sources

**Confidence level:** HIGH

This research is based on:
- MATLAB documentation standards (official MathWorks guidelines)
- Scientific software best practices (Software Carpentry, rOpenSci)
- Open-source project patterns (GitHub community standards)
- Neuroinformatics tool conventions (INCF, NeuroImaging community)
- Analysis of successful MATLAB research tools in neuroscience domain

Note: Due to tool access limitations, this research draws on established standards and patterns from my training rather than 2026-specific sources. These standards are stable and widely adopted across the scientific software community. Verification with current tool examples (FieldTrip, EEGLAB, etc.) recommended for confirmation of best practices.
