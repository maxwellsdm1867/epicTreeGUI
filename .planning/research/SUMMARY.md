# Project Research Summary

**Project:** epicTreeGUI v1.0 Documentation and Release
**Domain:** MATLAB neurophysiology research tool - Public GitHub release
**Researched:** 2026-02-06
**Confidence:** MEDIUM-HIGH

## Executive Summary

EpicTreeGUI is a pure MATLAB replacement for a legacy Java-based neurophysiology data browser that requires professional documentation for public GitHub release. Research reveals this is a **documentation project**, not a greenfield software build. The tool itself is functionally complete but currently has 30+ scattered markdown files, hardcoded paths, no LICENSE, and examples that work only on the developer's machine. This is the classic "works on my machine" problem that kills research software adoption.

The recommended approach is a **documentation consolidation and polish strategy** rather than building new features. MATLAB research tools on GitHub follow a well-established pattern: Markdown documentation (README, User Guide, Tutorial), plain .m example scripts (not Live Scripts for version control), inline function help comments, and MIT licensing. The dual-format strategy balances GitHub accessibility (Markdown) with MATLAB's native help system. Success requires ruthless consolidation of the 30+ docs into 5-8 focused files, bundled example data (<10 MB), and testing all examples in a fresh MATLAB session.

The critical risk is **documentation drift and path hell**. Users will clone the repo, try the README example, hit path errors or missing data, and abandon within 5 minutes. This is preventable through: (1) explicit setup instructions with verification, (2) bundled example data or generator script, (3) testing all examples in clean MATLAB session before release, (4) LICENSE file in root, and (5) consolidating the scattered docs into a clear hierarchy.

## Key Findings

### Recommended Stack

The MATLAB documentation ecosystem has standardized around a three-tier approach: Markdown for GitHub-facing docs (README, guides), plain .m scripts for examples (version control friendly), and MATLAB's native help system for API documentation. Live Scripts (.mlx) are optional for tutorials but their binary format complicates version control.

**Core technologies:**
- **Markdown (.md)** for README, User Guide, Tutorial — GitHub-native rendering, searchable, accessible without MATLAB
- **MATLAB Scripts (.m)** for runnable examples — plain text, version control friendly, executable, readable in any editor
- **MATLAB Comments** for inline help — powers `help` and `doc` commands, zero-overhead documentation
- **MIT License** for legal clarity — permissive, widely used in research, matches Rieke Lab patterns
- **GitHub Pages (optional)** via MATLAB publish() — professional presentation for 50+ function projects (not needed for epicTreeGUI's scale)

**Critical insight:** Academic MATLAB projects avoid complexity. No Sphinx, no MkDocs, no Jekyll. Just Markdown + .m scripts + inline help. The ecosystem values simplicity and MATLAB-native tools over modern documentation frameworks.

### Expected Features

Documentation for MATLAB research tools must balance discoverability (so users find the tool) with hands-on learning (so users succeed quickly). The baseline is surprisingly high: users expect professional documentation or they abandon immediately.

**Must have (table stakes):**
- **README.md** answering: What is this? Who is it for? How do I install? How do I start?
- **LICENSE file** for legal clarity (absence blocks institutional adoption)
- **Installation instructions** with exact path setup and verification step
- **Minimal working example** proving the tool works (<15 lines, runs in <5 min)
- **API reference** via MATLAB function headers (powers `help` command)
- **Quickstart guide** achieving something useful in 30 min
- **Data format specification** explaining input structure requirements
- **Citation information** for academic credit (text + BibTeX)

**Should have (competitive):**
- **Conceptual overview** explaining design decisions (why pre-built trees, why H5 lazy loading)
- **Multiple example scripts** (3-5) covering common workflows (basic usage, navigation, analysis, batch, custom)
- **Troubleshooting guide** with common errors and solutions
- **Visual diagrams** of system architecture and data flow
- **Comparison to alternatives** (epicTreeGUI vs manual scripts, vs legacy epochTreeGUI)
- **Changelog** tracking versions
- **FAQ section** from beta user questions
- **Performance notes** (dataset size limits, scalability)

**Defer (v2+):**
- **Video walkthrough** (high-impact but time-consuming: 8-16 hours)
- **Live Script tutorials** (.mlx format for interactive learning)
- **Contributing guide** (not critical until community adoption grows)
- **GitHub Pages site** with published HTML (overkill for 10-20 function toolbox)

**Anti-features to avoid:**
- Auto-generated docs without curation (cluttered, unhelpful)
- PDF-only documentation (not searchable on GitHub)
- Examples requiring unavailable data
- Jargon-heavy README excluding non-experts
- Documentation in separate repo/wiki (version drift)
- Hardcoded developer-specific paths

### Architecture Approach

MATLAB package documentation follows a **hierarchical information architecture** mirroring user journeys from discovery (30 seconds) to mastery (ongoing). This is a well-established pattern across successful neuroinformatics tools (FieldTrip, EEGLAB, SPM).

**Documentation layers:**
1. **Discovery Layer (README.md):** What/Why/Who in 30 seconds, quick start in 5 min, navigation to deeper docs
2. **Getting Started Layer (Tutorial/Quickstart):** Installation walkthrough, first success in 30 min, common workflow
3. **Reference Layer (User Guide + API):** Comprehensive feature docs, function reference, configuration options
4. **Deep Dive Layer (Architecture + Advanced):** System design, extension points, performance optimization
5. **Support Layer (Troubleshooting + FAQ):** Common errors, debugging guide, getting help

**Organization pattern:**
```
epicTreeGUI/
├── README.md                   # Landing page (100-300 lines)
├── LICENSE                     # MIT License
├── CITATION.cff                # Citation metadata (optional)
├── docs/
│   ├── QUICKSTART.md          # 30-min tutorial (500-1500 lines)
│   ├── USER_GUIDE.md          # Comprehensive reference (2000-5000 lines)
│   ├── ARCHITECTURE.md        # System design (500-2000 lines)
│   ├── TROUBLESHOOTING.md     # Common errors (500-1500 lines)
│   └── DATA_FORMAT.md         # Input spec (link existing)
├── examples/
│   ├── README.md              # Overview
│   ├── data/sample_data.mat   # <10 MB example
│   ├── 01_basic_usage.m
│   ├── 02_tree_navigation.m
│   ├── 03_data_extraction.m
│   ├── 04_batch_analysis.m
│   └── 05_custom_splitter.m
├── src/                        # Source with inline help
└── tests/                      # Separate from examples
```

**Key patterns:**
- **Progressive disclosure:** Information revealed in layers based on user needs
- **Task-oriented organization:** By user goals ("Loading Data"), not software structure ("epicTreeTools class")
- **Example-driven:** Every feature documented with executable code
- **Just-in-time concepts:** Introduce terminology when needed, not upfront
- **Redundant navigation:** Every doc links to related docs (users never stuck)

**Current epicTreeGUI state:** 30+ markdown files at root (documentation explosion). Needs consolidation to 5-8 focused files with clear hierarchy.

### Critical Pitfalls

Research identified 14 pitfalls for MATLAB research tool releases. The top 5 are immediate-abandonment risks:

1. **Path Hell - Unclear Setup Instructions** — Users get "Undefined function" errors, don't know which directories to add to path, give up in 5 minutes. **Prevention:** Provide setup.m script, document exact path commands with verification (`which epicTreeTools`), show both addpath() and addpath(genpath()) patterns.

2. **The Invisible Data Format** — Tool crashes with cryptic struct field errors because users don't know required data structure. **Prevention:** Provide example data (<10 MB), document format explicitly with struct hierarchy, provide validation function, show conversion guidance. **epicTreeGUI status:** Has DATA_FORMAT_SPECIFICATION.md (good) but needs bundled sample dataset.

3. **The "It Worked on My Machine" Demo** — README example uses hardcoded paths (`/Users/maxwellsdm/Documents/epicTreeTest/`) that don't exist on user's machine. **Prevention:** Test examples in fresh MATLAB session, make examples self-contained, provide bundled data, use relative paths. **epicTreeGUI status:** START_HERE.m exists but has absolute paths. CRITICAL FIX needed.

4. **Silent Dependency on MATLAB Toolboxes** — Code uses Signal Processing or Statistics Toolbox functions, README says "no toolboxes required", crashes for users without them. **Prevention:** Test on minimal MATLAB install, document required vs optional toolboxes, check programmatically with `license('test')`. **epicTreeGUI status:** Claims pure MATLAB, should verify with `matlab.codetools.requiredFilesAndProducts()`.

5. **The Stale README Problem** — Documentation describes old version, examples throw errors because API changed. **Prevention:** Test documentation examples as part of release process, version docs explicitly, mark deprecated features, pre-release audit in fresh session. **epicTreeGUI status:** Has multiple doc versions (README.md, README_NEW.md, QUICK_START.md, RUN_ME_FIRST.md) showing signs of drift. Needs consolidation.

**Additional critical pitfalls:**
- **No LICENSE file** (blocks institutional adoption) — epicTreeGUI has licenses in subdirs but NOT root. MUST ADD.
- **Function discoverability gap** (20+ splitters exist but users only find 3) — needs function gallery
- **Inconsistent documentation** (30+ files with conflicting info) — needs consistency review pass
- **Missing migration guide** from legacy epochTreeGUI — existing users resist adoption without guidance
- **Example data too large or missing** — references unavailable paths, no bundled data

## Implications for Roadmap

Based on combined research, this is a **4-week documentation consolidation and polish project**, not a multi-phase software build. The tool is functionally complete. The work is making it publicly releasable.

### Suggested Phase Structure

#### Phase 1: Critical Blockers (Week 1)
**Rationale:** These items will cause immediate abandonment if missing. Nothing else matters if users can't install or run the tool.

**Delivers:**
- LICENSE file in repository root (MIT)
- README.md polished and user-focused (not developer-focused)
- Setup instructions with exact path commands and verification
- One working example with bundled data or generator script
- Consolidate 30+ docs: identify user-facing vs internal, establish hierarchy

**Addresses (from FEATURES.md):**
- README.md (table stakes)
- LICENSE file (table stakes)
- Installation instructions (table stakes)
- Minimal working example (table stakes)

**Avoids (from PITFALLS.md):**
- Pitfall 10: Missing LICENSE file
- Pitfall 3: "It worked on my machine" demo
- Pitfall 9: Inconsistent documentation across files

**Phase flag:** Standard patterns, NO research needed. Well-documented process.

---

#### Phase 2: User Onboarding (Week 2)
**Rationale:** Once users can install, they need to learn. Tutorial and examples enable independent success.

**Delivers:**
- docs/QUICKSTART.md tutorial (30-min first analysis)
- 3-5 example scripts covering common workflows
- examples/README.md overview
- Example data bundled (<10 MB) or clear download/generation
- Function help headers complete and tested

**Addresses (from FEATURES.md):**
- Quickstart guide (table stakes)
- Multiple example scripts (differentiator)
- API reference via help comments (table stakes)
- Data format specification (table stakes)

**Avoids (from PITFALLS.md):**
- Pitfall 2: The invisible data format
- Pitfall 6: Function discoverability gap
- Pitfall 13: Example data missing

**Uses (from STACK.md):**
- MATLAB Scripts (.m) for examples (version control friendly)
- MATLAB Comments for inline help (powers `help` command)

**Phase flag:** Standard patterns, NO research needed. Well-documented tutorial structure.

---

#### Phase 3: Comprehensive Reference (Week 3)
**Rationale:** Power users and extenders need deep documentation. Troubleshooting reduces support burden.

**Delivers:**
- docs/USER_GUIDE.md completed (all sections)
- docs/ARCHITECTURE.md (extract from CLAUDE.md)
- docs/TROUBLESHOOTING.md (common errors and solutions)
- Migration guide from legacy epochTreeGUI
- Citation information (CITATION.cff + README section)

**Addresses (from FEATURES.md):**
- Conceptual overview (differentiator)
- Troubleshooting guide (differentiator)
- Comparison to alternatives (differentiator)
- Citation information (table stakes)

**Avoids (from PITFALLS.md):**
- Pitfall 7: No error message translation
- Pitfall 8: Missing migration guide
- Pitfall 12: No citation information

**Implements (from ARCHITECTURE.md):**
- Deep Dive Layer (system design, extension points)
- Support Layer (troubleshooting, debugging)

**Phase flag:** Standard patterns, NO research needed. Extract from existing CLAUDE.md.

---

#### Phase 4: Release Polish (Week 4)
**Rationale:** Final quality pass ensures professional presentation and catches issues before public release.

**Delivers:**
- All examples tested in fresh MATLAB session
- Documentation consistency review (README/Guide/Tutorial aligned)
- Visual documentation (screenshots of GUI, example outputs)
- CHANGELOG.md initialized
- Pre-release audit checklist completed
- Version number consistency across all docs

**Addresses (from FEATURES.md):**
- Visual diagrams (differentiator)
- Changelog (differentiator)

**Avoids (from PITFALLS.md):**
- Pitfall 5: The stale README problem
- Pitfall 14: No visual documentation
- All pitfalls via pre-release checklist

**Phase flag:** Standard patterns, NO research needed. Quality assurance process.

---

### Phase Ordering Rationale

**Why this sequence:**
1. **Week 1 first** because missing LICENSE or broken setup causes instant abandonment regardless of other docs
2. **Week 2 next** because once installed, users need onboarding to see value (tutorial + examples)
3. **Week 3 follows** because reference docs only matter after users have basic success
4. **Week 4 last** because polish and consistency checks require all content to exist first

**Dependencies identified:**
- Phase 4 depends on Phases 1-3 (can't test consistency until docs written)
- Phase 2 depends on Phase 1 (examples need consolidated doc structure)
- Phase 3 can partially overlap Phase 2 (independent tasks like ARCHITECTURE.md extraction)

**How this avoids pitfalls:**
- Addresses all 5 critical pitfalls in Phases 1-2 (within 2 weeks)
- Provides incremental milestones (each week is releasable to beta users)
- Frontloads high-risk items (path hell, data format, working examples)
- Saves polish for end when all content exists

**Grouping rationale:**
- Phase 1 = "Can users install?" (blockers)
- Phase 2 = "Can users succeed?" (learning)
- Phase 3 = "Can users master?" (reference)
- Phase 4 = "Can we release?" (quality)

### Research Flags

**NO phases need `/gsd:research-phase` during planning.** This is not a greenfield software project. All patterns are well-documented:

- **Phase 1:** Standard GitHub release checklist (LICENSE, README structure) — SKIP RESEARCH
- **Phase 2:** Standard MATLAB tutorial patterns (FieldTrip, EEGLAB as references) — SKIP RESEARCH
- **Phase 3:** Standard reference documentation (extract from existing CLAUDE.md) — SKIP RESEARCH
- **Phase 4:** Standard QA process (testing, screenshots, consistency) — SKIP RESEARCH

**Why no research needed:**
- STACK.md shows established MATLAB documentation patterns (Markdown + .m + help comments)
- FEATURES.md based on mature scientific software conventions (training data through Jan 2025)
- ARCHITECTURE.md describes information architecture patterns (not software architecture research)
- PITFALLS.md derived from observing epicTreeGUI's current state (not hypothetical)

**Proceed directly to roadmap creation.** Use this summary as input for phase structure.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Based on training data through Jan 2025, no external verification. Markdown + .m scripts is stable pattern. |
| Features | HIGH | Table stakes well-established in scientific software (LICENSE, README, examples, help). Differentiators from mature tools (FieldTrip, EEGLAB). |
| Architecture | HIGH | Information architecture patterns apply across documentation domains. EpicTreeGUI-specific recommendations from analyzing existing docs. |
| Pitfalls | HIGH | Derived from epicTreeGUI's actual current state (30+ docs, hardcoded paths, no LICENSE). Prevention strategies tailored to observed issues. |

**Overall confidence:** MEDIUM-HIGH

**Rationale for confidence level:**
- HIGH for Features and Pitfalls: Based on concrete analysis of epicTreeGUI's current documentation state and established scientific software patterns
- MEDIUM-HIGH for Stack: Well-established patterns but no 2026-specific verification (GitHub/MATLAB may have changed since training)
- HIGH for Architecture: Information architecture principles are stable, epicTreeGUI-specific structure from existing docs

### Gaps to Address

**During Phase 1 (Week 1):**
- **Verify toolbox dependencies:** Run `matlab.codetools.requiredFilesAndProducts()` on all source files to confirm "no toolboxes required" claim is accurate
- **Determine minimum MATLAB version:** README says "R2019b or later" but should test on actual R2020b (claimed minimum) to verify compatibility
- **Decide on example data strategy:** Bundle small dataset (<10 MB) vs provide generator script vs host externally (Zenodo)

**During Phase 2 (Week 2):**
- **Test path setup on Windows/Mac/Linux:** Current docs assume Unix paths, verify Windows compatibility
- **Identify most common workflows:** Interview lab members or analyze test scripts to determine which 3-5 examples to prioritize

**During Phase 3 (Week 3):**
- **Extract migration guide content:** Review old_epochtree/ code to document API differences for existing users
- **Collect actual error messages:** Run tool with bad inputs to document real troubleshooting scenarios (not hypothetical)

**During Phase 4 (Week 4):**
- **Screenshot capture:** Decide on GUI state to screenshot (which tree structure, which data loaded)
- **MATLAB version testing:** If possible, test examples on R2020b, R2022a, R2024a to verify cross-version compatibility

**No research blocks identified.** All gaps are execution details resolvable during implementation.

## Sources

### Primary (HIGH confidence)
- **epicTreeGUI repository analysis** (README.md, CLAUDE.md, UserGuide.md, 30+ doc files, src/ structure) — Current state assessment
- **MATLAB documentation standards** (training data through Jan 2025) — Function header patterns, help system, publish() workflow
- **Scientific software best practices** (Software Carpentry, rOpenSci guidelines) — Research tool documentation conventions

### Secondary (MEDIUM confidence)
- **GitHub community standards** (README structure, LICENSE files, CITATION.cff) — Open source project patterns
- **Neuroinformatics tool conventions** (FieldTrip, EEGLAB, SPM examples from training data) — Domain-specific documentation patterns
- **Existing Rieke Lab projects** (LICENSE patterns inferred from epicTreeGUI subdirectories) — Lab conventions

### Tertiary (LOW confidence)
- **MATLAB publish() workflow for GitHub Pages** (training data, no 2026 verification) — May have changed since training cutoff
- **CITATION.cff adoption in MATLAB community** (emerging standard, adoption varies) — Recommended but not critical
- **Live Scripts (.mlx) pros/cons** (based on experience patterns, not exhaustive comparison) — Prefer .m for version control

### Verification Needed
- Current MATLAB documentation best practices in 2026 (training data is Jan 2025)
- GitHub Pages + MATLAB integration current capabilities
- Toolbox detection methods (`license('test')` vs `matlab.codetools.requiredFilesAndProducts()`)

**No verification blockers.** Can proceed with documentation work using established patterns. Any 2026-specific updates are polish, not foundational changes.

---

**Research completed:** 2026-02-06
**Ready for roadmap:** Yes
**Synthesis confidence:** HIGH (research files comprehensive, epicTreeGUI-specific, actionable)
