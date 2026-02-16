# Roadmap: EpicTreeGUI v1.0 Release

## Overview

Transform epicTreeGUI from a working internal tool into a production-ready public GitHub release through systematic documentation consolidation and polish. The tool is functionally complete—this roadmap focuses on making it discoverable, installable, and usable by neuroscience researchers without prior knowledge of the Rieke Lab system. Four phases take us from critical blockers (LICENSE, working examples) through user onboarding (tutorials, examples) to comprehensive reference (architecture, troubleshooting) and final quality assurance (testing, screenshots, consistency checks).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 0: Testing & Validation** - Verify all functions work correctly before documentation
- [ ] **Phase 1: Foundation & Legal** - Critical blockers: LICENSE, README, working setup
- [ ] **Phase 2: User Onboarding** - Learning materials: tutorial, examples, sample data
- [ ] **Phase 3: Comprehensive Documentation** - Reference docs: user guide, architecture, troubleshooting
- [ ] **Phase 4: Release Polish** - Quality assurance: screenshots, consistency validation

## Phase Details

### Phase 0: Testing & Validation
**Goal**: Verify all analysis functions and critical workflows work correctly with real data
**Depends on**: Nothing (first phase)
**Requirements**: TEST-01, TEST-02
**Success Criteria** (what must be TRUE):
  1. User can run all analysis functions (getMeanResponseTrace, getResponseAmplitudeStats, getCycleAverageResponse, getLinearFilterAndPrediction, MeanSelectedNodes) with real data without errors
  2. User can verify tree navigation works correctly (childAt, parentAt, getAllEpochs, leafNodes)
  3. User can verify data extraction functions return correct results (getSelectedData, getResponseMatrix)
  4. User can run test suite and all critical workflow tests pass
  5. Any bugs or issues discovered are documented for fixing
**Plans**: 5 plans

Plans:
- [x] 00-01-PLAN.md -- Test infrastructure and tree navigation tests
- [x] 00-02-PLAN.md -- Splitter functions and data extraction tests
- [x] 00-03-PLAN.md -- Analysis function tests and golden baselines
- [x] 00-04-PLAN.md -- GUI testing utility and automated GUI tests
- [x] 00-05-PLAN.md -- Integration workflow tests and testing report

### Phase 0.1: Critical Bug Fixes - Selection State (INSERTED)
**Goal**: Fix critical selection state bug (BUG-001) that breaks core filtering functionality
**Depends on**: Phase 0
**Requirements**: None (urgent bug fix)
**Success Criteria** (what must be TRUE):
  1. User can deselect epochs and `getAllEpochs(true)` returns only selected epochs
  2. User can call `getSelectedData()` and receive only selected epochs, not all epochs
  3. Selection state persists correctly in tree hierarchy
  4. Tests validate selection filtering works end-to-end
  5. Architecture clearly documents where selection state lives and how it propagates
**Plans**: 4 plans

Plans:
- [ ] 00.1-01-PLAN.md -- Core selection verification, .ugm persistence methods, and LoadUserMetadata constructor option
- [ ] 00.1-02-PLAN.md -- GUI "Save Epoch Mask" button and matFilePath integration
- [ ] 00.1-03-PLAN.md -- Selection state and .ugm persistence test suites
- [ ] 00.1-04-PLAN.md -- Selection state architecture documentation

**Details:**
Phase 0 testing discovered BUG-001: Selection state not persisting/propagating. When users deselect epochs, `selectedCount()` reports correctly but `getAllEpochs(true)` and `getSelectedData()` ignore the selection and return ALL epochs. This breaks the core filtering workflow.

See `BUGS_FOUND_PHASE0.md` for full analysis and architectural options.

### Phase 1: Foundation & Legal
**Goal**: Repository is legally releasable with working installation path
**Depends on**: Phase 0
**Requirements**: LEG-01, LEG-02, LEG-03, CLEAN-01, CLEAN-02, CLEAN-03, CLEAN-04, CLEAN-05, README-01, README-02, README-03, README-08, EXAM-01, EXAM-02
**Success Criteria** (what must be TRUE):
  1. User can clone repository and see MIT LICENSE file at root
  2. User can read README.md and understand what epicTreeGUI is in 30 seconds
  3. User can follow installation instructions and verify setup with provided commands
  4. User can run one complete example from README with bundled data without path errors
  5. Repository root directory has professional appearance with less than 5 loose files
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md -- Repository cleanup: move legacy code, remove Python pipeline, consolidate root files
- [ ] 01-02-PLAN.md -- Legal files and install.m: MIT LICENSE, CITATION.cff, CHANGELOG.md, path setup
- [ ] 01-03-PLAN.md -- README.md, sample data bundle, and quickstart example

### Phase 2: User Onboarding
**Goal**: New users can independently learn and succeed with epicTreeGUI
**Depends on**: Phase 1
**Requirements**: EXAM-03, EXAM-04, EXAM-05, EXAM-06, EXAM-07, EXAM-08, GUIDE-01, GUIDE-02, GUIDE-03, GUIDE-04, FUNC-01, FUNC-02, FUNC-03
**Success Criteria** (what must be TRUE):
  1. User can complete 30-minute quickstart tutorial and produce first analysis result
  2. User can browse 3-5 example scripts demonstrating common workflows
  3. User can run `help epicTreeTools` and see comprehensive usage documentation
  4. User can load bundled sample data or generate test data without external dependencies
  5. User can discover available splitter functions and understand how to use them
**Plans**: TBD

Plans:
- [ ] (Plans will be created during `/gsd:plan-phase 2`)

### Phase 3: Comprehensive Documentation
**Goal**: Power users have complete reference documentation and migration guidance
**Depends on**: Phase 2
**Requirements**: README-04, README-05, README-06, README-07, GUIDE-05, GUIDE-06, GUIDE-07, TEST-01
**Success Criteria** (what must be TRUE):
  1. User can read USER_GUIDE.md and find documentation for every public feature
  2. User can read ARCHITECTURE.md and understand system design and extension points
  3. User can consult TROUBLESHOOTING.md when encountering errors and find solutions
  4. User migrating from legacy epochTreeGUI can read migration guide and adapt workflows
  5. User can cite epicTreeGUI in academic publications with provided citation information
**Plans**: TBD

Plans:
- [ ] (Plans will be created during `/gsd:plan-phase 3`)

### Phase 4: Release Polish
**Goal**: Repository passes quality checks and presents professionally
**Depends on**: Phase 3
**Requirements**: README-04, TEST-03, TEST-04, TEST-05, QA-01, QA-02, QA-03, QA-04
**Success Criteria** (what must be TRUE):
  1. User can see screenshots in README showing GUI in action with real data
  2. User can run all example scripts in fresh MATLAB session without errors
  3. User can read documentation and find consistent terminology and structure across all files
  4. User can review CHANGELOG.md and understand what v1.0 includes
  5. Fresh clone on different machine completes pre-release checklist successfully
**Plans**: TBD

Plans:
- [ ] (Plans will be created during `/gsd:plan-phase 4`)

## Progress

**Execution Order:**
Phases execute in numeric order: 0 → 0.1 → 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. Testing & Validation | 5/5 | Complete | 2026-02-08 |
| 0.1. Critical Bug Fixes - Selection State | 0/4 | Planned | - |
| 1. Foundation & Legal | 0/TBD | Not started | - |
| 2. User Onboarding | 0/TBD | Not started | - |
| 3. Comprehensive Documentation | 0/TBD | Not started | - |
| 4. Release Polish | 0/TBD | Not started | - |
