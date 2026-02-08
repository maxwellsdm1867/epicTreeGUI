# Requirements: EpicTreeGUI v1.0 Release

**Defined:** 2026-02-06
**Core Value:** Researchers should be able to discover, install, understand, and use epicTreeGUI without prior knowledge of the Rieke Lab system or legacy epoch tree tools.

## v1 Requirements

### Legal & Licensing

- [ ] **LEG-01**: Repository includes MIT LICENSE file at root
- [ ] **LEG-02**: Third-party licenses documented (if any)
- [ ] **LEG-03**: CITATION.cff file added for academic citation

### Repository Cleanup

- [ ] **CLEAN-01**: Remove old_epochtree/ directory (legacy reference code)
- [ ] **CLEAN-02**: Consolidate 30+ root markdown files into docs/ directory
- [ ] **CLEAN-03**: Move scattered test files into tests/ directory
- [ ] **CLEAN-04**: Organize or remove Python code (new_retinanalysis/)
- [ ] **CLEAN-05**: Root directory has < 5 files (clean professional appearance)

### GitHub Presentation (README.md)

- [ ] **README-01**: What is epicTreeGUI (2-3 sentence description)
- [ ] **README-02**: Installation instructions with explicit path setup
- [ ] **README-03**: Quick start example (< 10 lines of code)
- [ ] **README-04**: Screenshots of GUI in action
- [ ] **README-05**: Citation information (how to cite the tool)
- [ ] **README-06**: Links to full documentation
- [ ] **README-07**: Features/capabilities overview
- [ ] **README-08**: System requirements (MATLAB version, toolboxes)

### Examples & Sample Data

- [ ] **EXAM-01**: Fix hardcoded paths in all example scripts
- [ ] **EXAM-02**: Create install.m script for path setup
- [ ] **EXAM-03**: Bundle small sample data file (< 10 MB)
- [ ] **EXAM-04**: Example 1: Basic tree building and navigation
- [ ] **EXAM-05**: Example 2: Data extraction and analysis
- [ ] **EXAM-06**: Example 3: Custom splitter creation
- [ ] **EXAM-07**: examples/README.md with overview of all examples
- [ ] **EXAM-08**: Test all examples in fresh MATLAB session

### User Documentation

- [ ] **GUIDE-01**: QUICKSTART tutorial (30-minute walkthrough)
- [ ] **GUIDE-02**: User guide covers installation and configuration
- [ ] **GUIDE-03**: User guide covers basic usage patterns
- [ ] **GUIDE-04**: User guide covers common workflows
- [ ] **GUIDE-05**: Troubleshooting section with common errors
- [ ] **GUIDE-06**: Migration guide from legacy epoch tree system
- [ ] **GUIDE-07**: Architecture documentation (extract from CLAUDE.md)

### Function Documentation

- [ ] **FUNC-01**: All public functions have help headers
- [ ] **FUNC-02**: Help headers use consistent format (Usage/Inputs/Outputs/Examples)
- [ ] **FUNC-03**: Verify help command works for all functions

### Testing & Validation

- [x] **TEST-01**: Verify all analysis functions work correctly with real data
- [x] **TEST-02**: Test suite covering critical workflows exists
- [ ] **TEST-03**: All examples run without errors on clean install
- [ ] **TEST-04**: Documentation links are valid (no broken links)
- [ ] **TEST-05**: Verify minimum MATLAB version requirement (R2020b)

### Quality Assurance

- [ ] **QA-01**: Consistency review across all documentation
- [ ] **QA-02**: Pre-release checklist completed
- [ ] **QA-03**: Fresh clone test on different machine
- [ ] **QA-04**: CHANGELOG.md initialized for v1.0

## v2 Requirements

Deferred to future release:

### Enhanced Features
- **UI-01**: Multi-device subplot display
- **UI-02**: Epoch slider with keyboard navigation
- **UI-03**: Stimulus overlay toggle
- **UI-04**: Complete analysis menu integration
- **UI-05**: Batch processing across nodes

### Advanced Documentation
- **DOC-01**: Video tutorial walkthrough
- **DOC-02**: GitHub Pages site with searchable docs
- **DOC-03**: FAQ based on user feedback
- **DOC-04**: Contributing guide for community developers

## Out of Scope

| Feature | Reason |
|---------|--------|
| MATLAB File Exchange submission | Separate effort after GitHub release, not blocking v1.0 |
| Live Script (.mlx) tutorials | .m scripts sufficient, .mlx is binary format that complicates version control |
| GitHub Actions CI/CD | MATLAB testing infrastructure complex, manual testing adequate for v1.0 |
| Automated documentation generation | Manual curation provides better quality for v1.0 |
| Sample data download server | Bundle small dataset directly, avoid infrastructure dependency |
| Installers or packaged toolbox | Users can use addpath, no complex installation needed |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| TEST-01 | Phase 0 | Complete |
| TEST-02 | Phase 0 | Complete |
| LEG-01 | Phase 1 | Pending |
| LEG-02 | Phase 1 | Pending |
| LEG-03 | Phase 1 | Pending |
| CLEAN-01 | Phase 1 | Pending |
| CLEAN-02 | Phase 1 | Pending |
| CLEAN-03 | Phase 1 | Pending |
| CLEAN-04 | Phase 1 | Pending |
| CLEAN-05 | Phase 1 | Pending |
| README-01 | Phase 1 | Pending |
| README-02 | Phase 1 | Pending |
| README-03 | Phase 1 | Pending |
| README-08 | Phase 1 | Pending |
| EXAM-01 | Phase 1 | Pending |
| EXAM-02 | Phase 1 | Pending |
| EXAM-03 | Phase 2 | Pending |
| EXAM-04 | Phase 2 | Pending |
| EXAM-05 | Phase 2 | Pending |
| EXAM-06 | Phase 2 | Pending |
| EXAM-07 | Phase 2 | Pending |
| EXAM-08 | Phase 2 | Pending |
| GUIDE-01 | Phase 2 | Pending |
| GUIDE-02 | Phase 2 | Pending |
| GUIDE-03 | Phase 2 | Pending |
| GUIDE-04 | Phase 2 | Pending |
| FUNC-01 | Phase 2 | Pending |
| FUNC-02 | Phase 2 | Pending |
| FUNC-03 | Phase 2 | Pending |
| README-04 | Phase 3 | Pending |
| README-05 | Phase 3 | Pending |
| README-06 | Phase 3 | Pending |
| README-07 | Phase 3 | Pending |
| GUIDE-05 | Phase 3 | Pending |
| GUIDE-06 | Phase 3 | Pending |
| GUIDE-07 | Phase 3 | Pending |
| TEST-03 | Phase 4 | Pending |
| TEST-04 | Phase 4 | Pending |
| TEST-05 | Phase 4 | Pending |
| QA-01 | Phase 4 | Pending |
| QA-02 | Phase 4 | Pending |
| QA-03 | Phase 4 | Pending |
| QA-04 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 38 total
- Mapped to phases: 38/38 (100%)
- Unmapped: 0

**Phase Distribution:**
- Phase 0 (Testing & Validation): 2 requirements
- Phase 1 (Foundation & Legal): 14 requirements
- Phase 2 (User Onboarding): 13 requirements
- Phase 3 (Comprehensive Documentation): 7 requirements
- Phase 4 (Release Polish): 6 requirements

---
*Requirements defined: 2026-02-06*
*Last updated: 2026-02-07 after roadmap creation*
