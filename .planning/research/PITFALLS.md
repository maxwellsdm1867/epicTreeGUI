# Domain Pitfalls: MATLAB Research Tool Documentation and Release

**Domain:** MATLAB neurophysiology research tools - Public GitHub release
**Researched:** 2026-02-06
**Project:** epicTreeGUI v1.0

---

## Critical Pitfalls

Mistakes that cause immediate abandonment or prevent users from getting started.

### Pitfall 1: Path Hell - Unclear Setup Instructions

**What goes wrong:** Users clone the repo, try to run code, get "Undefined function or variable" errors. They don't know which directories to add to path, or whether to use `addpath()` or `addpath(genpath())`. They give up within 5 minutes.

**Why it happens:**
- MATLAB's path system is not obvious to researchers unfamiliar with MATLAB packaging
- Authors know their setup by heart and forget to document it
- Assumption that "just run addpath" is sufficient
- No clear distinction between "add this directory only" vs "add with subdirectories"

**Consequences:**
- Tool appears broken before user even sees the GUI
- Negative first impression prevents deeper exploration
- GitHub issue: "Nothing works, all errors"

**Prevention:**
1. **Provide a setup script** (`setup.m` or `install.m`) that users run once
2. **Document exact path commands** with verification step
3. **Show how to confirm it worked** (`which epicTreeTools`)
4. **Troubleshoot proactively** - common path errors documented

**Detection (warning signs):**
- Your README says "add to path" without showing HOW
- No setup.m or install script provided
- You assume users know difference between addpath() and addpath(genpath())
- No "verify installation" step

**Which requirement addresses this:**
- User Guide (installation section)
- README (getting started with explicit setup)
- Example scripts (must document prerequisites)

---

### Pitfall 2: The Invisible Data Format

**What goes wrong:** User has their own .mat files. They try to load them. Tool crashes with cryptic struct field errors. Documentation says "load data.mat" but doesn't explain what structure data.mat must have.

**Why it happens:**
- Authors only test with their own pipeline's output
- Data format is "obvious" to lab members who generated it
- Assumption that struct field access like `data.experiments{1}.cells{1}` is self-documenting
- No example data provided for testing

**Consequences:**
- Users cannot try the tool without generating compatible data first
- "It doesn't work with my data" equals abandonment
- Cannot distinguish between "wrong data format" and "broken tool"
- Users give up before seeing value

**Prevention:**
1. **Provide example data** - Small sample (< 10 MB) included in repo
2. **Document format explicitly** - Show expected struct hierarchy
3. **Validation function** - Let users check their data
4. **Conversion guidance** - Show how to adapt other formats

**Detection (warning signs):**
- Documentation says "load your data" without describing format
- No example data files provided
- Data format only in technical specs, not user guide
- No way to validate whether data is correctly formatted

**Which requirement addresses this:**
- Example scripts (working with bundled data)
- User Guide (data format section with examples)
- Tutorial (shows data loading step-by-step)

**epicTreeGUI specific:** Currently has DATA_FORMAT_SPECIFICATION.md (good!) but needs small example dataset bundled.

---

### Pitfall 3: The "It Worked on My Machine" Demo

**What goes wrong:** README shows beautiful example like `gui = epicTreeGUI('data.mat')` but this requires:
- Specific file path that doesn't exist on user's machine
- H5 configuration already set (not shown)
- Implicit dependencies or prior state

User tries exact command, gets error, feels misled.

**Why it happens:**
- Examples written after months of development with environment already configured
- Forgetting setup steps that happened long ago
- Copy-pasting from working session without isolating dependencies
- Testing examples in already-configured environment

**Consequences:**
- "Following the README doesn't work" - trust broken immediately
- Users don't know if error is their fault or tool's fault
- Frustration because "it should work according to docs"
- High support burden from basic setup issues

**Prevention:**
1. **Test examples in fresh MATLAB session** before release
2. **Make examples self-contained** - show ALL prerequisites
3. **Provide "copy and run" launcher** (START_HERE.m)
4. **Document implicit requirements** clearly

**Detection (warning signs):**
- Your examples use hardcoded paths specific to your machine
- Examples work for you but not in clean MATLAB session
- You have to "prepare environment" before running examples
- Examples reference files that don't exist in the repository

**Which requirement addresses this:**
- Example scripts (must be runnable)
- Tutorial (step-by-step from zero state)
- Test suite (include "does README example actually work")

**epicTreeGUI specific:** Has START_HERE.m (excellent!) but uses `/Users/maxwellsdm/Documents/epicTreeTest/` paths. Needs bundled example data.

---

### Pitfall 4: Silent Dependency on MATLAB Toolboxes

**What goes wrong:** Code uses functions from Signal Processing Toolbox, Statistics Toolbox, or other paid add-ons. README says "no toolboxes required" but tool crashes with "Undefined function" when user lacks that toolbox.

**Why it happens:**
- Developer has all toolboxes installed (university license)
- Toolbox functions look like base MATLAB functions (e.g., `xcorr`, `fitlm`)
- Not testing on minimal MATLAB installation
- Assumption that "everyone has these toolboxes"

**Consequences:**
- Tool claimed as "free" but actually requires expensive toolboxes
- Works for some users (with toolboxes) but not others
- Frustrating because error is mysterious
- Reduces potential user base unnecessarily

**Prevention:**
1. **Test on minimal MATLAB** - Base installation only
2. **Document honestly** - List required vs optional toolboxes
3. **Provide alternatives** - Pure MATLAB fallbacks where possible
4. **Check programmatically** - Use `license('test', 'toolbox_name')`

**Detection (warning signs):**
- You haven't tested without all toolboxes installed
- README doesn't mention toolbox requirements
- No graceful fallback for toolbox-specific functions
- Code calls functions without checking availability

**Which requirement addresses this:**
- README (requirements section - be explicit)
- User Guide (installation prerequisites)
- Test suite (dependency checker script)

**epicTreeGUI specific:** Appears to use pure MATLAB. Should verify with `matlab.codetools.requiredFilesAndProducts()` before claiming "no toolboxes required".

---

### Pitfall 5: The Stale README Problem

**What goes wrong:** README describes old version. Says "use simple mode" but code now requires pre-built trees. Example code throws errors because API changed. Users follow docs, hit errors, lose confidence.

**Why it happens:**
- Code evolves faster than documentation
- No review process catches doc/code divergence
- No automated testing of documentation examples
- "I'll update the docs later" becomes never

**Consequences:**
- Users cannot trust documentation
- Official docs contradict actual behavior
- Increased support burden ("but the docs say...")
- Professional credibility damaged

**Prevention:**
1. **Test documentation examples** as part of test suite
2. **Version documentation** explicitly (v1.0 docs for v1.0 code)
3. **Mark deprecated features** clearly
4. **Pre-release audit** - Run all examples in fresh session

**Detection (warning signs):**
- Examples in README don't work when copied exactly
- Documentation references features that don't exist
- No automated testing of documentation
- Multiple places list "current version" with different numbers

**Which requirement addresses this:**
- Test suite (include README example tests)
- README (version clearly stated at top)
- All documentation (pre-release consistency check)

**epicTreeGUI specific:** Multiple versions of documentation (README.md, README_NEW.md, QUICK_START.md, RUN_ME_FIRST.md). Need consolidation and testing.

---

## Moderate Pitfalls

Mistakes that cause frustration or reduce adoption but don't immediately block usage.

### Pitfall 6: Function Discoverability Gap

**What goes wrong:** Tool has 20+ useful functions but users only discover the 3 mentioned in README. Rich functionality exists but is invisible. Users reinvent functionality that already exists.

**Why it happens:**
- Documentation focuses on basic workflow only
- Function reference buried in technical docs
- No "gallery" of what's possible
- Assumption that users will explore code on their own

**Consequences:**
- Underutilization of tool capabilities
- Users think tool is limited
- Missed opportunity for adoption ("I need X" but X exists undocumented)
- Lower user satisfaction

**Prevention:**
1. **Function index in README** - Quick reference table
2. **Examples gallery** - Show various workflows
3. **Organize by use case** - Not just alphabetically
4. **Quick reference card** - Common tasks at a glance

**Detection (warning signs):**
- README only shows one workflow
- No function listing or index
- Users ask "can it do X?" for features that exist
- Examples directory empty or minimal

**Which requirement addresses this:**
- README (feature overview section)
- User Guide (comprehensive function reference)
- Example scripts (demonstrating various capabilities)
- Tutorial (covering different use cases)

**epicTreeGUI specific:** Has 20+ splitters, navigation methods, analysis functions. Currently buried in 2100+ line TRD. Need user-facing function gallery.

---

### Pitfall 7: No Error Message Translation

**What goes wrong:** User makes common mistake, gets MATLAB's cryptic error like "Index exceeds the number of array elements (0)". User has no idea what they did wrong or how to fix it.

**Why it happens:**
- Relying on MATLAB's default errors without context
- Not anticipating common mistakes
- No input validation with helpful messages
- Assumption that error line numbers are sufficient guidance

**Consequences:**
- Users get stuck on fixable problems
- Support burden increases (same questions repeatedly)
- Tool appears buggy rather than helping user
- Users abandon rather than ask for help

**Prevention:**
1. **Add input validation** with context-rich error messages
2. **Document common errors** in troubleshooting section
3. **Provide diagnostic functions** to check tool state
4. **Test by making mistakes** - see what users will experience

**Detection (warning signs):**
- No input validation in public functions
- Error messages just say what failed, not why or how to fix
- No "Troubleshooting" section in documentation
- You haven't tried making mistakes to see what errors users see

**Which requirement addresses this:**
- User Guide (troubleshooting section)
- README (common errors subsection)
- Code improvements (better validation) - out of scope for docs but document current errors

---

### Pitfall 8: Missing Migration Guide from Legacy System

**What goes wrong:** Users familiar with old Java-based epochTreeGUI try to use new tool. API is different, patterns have changed, old code doesn't work. No guidance on how to adapt.

**Why it happens:**
- Focus on new users, forget existing users
- Assumption that "pure MATLAB is obviously better" is enough
- No explicit comparison showing differences
- Old system treated as "deprecated and forgotten"

**Consequences:**
- Existing users resist adoption
- Lab members stick with broken old system
- Migration friction reduces adoption in existing user base
- Lost opportunity to leverage familiarity

**Prevention:**
1. **Explicit migration guide** - Side-by-side comparison
2. **Document compatibility** for analysis functions
3. **Explain why changes** were made (benefits)
4. **Provide conversion utilities** if practical

**Detection (warning signs):**
- No mention of relationship to legacy system
- No comparison or migration guide
- Assumption that "better" means users will figure it out
- Old system removed without transition documentation

**Which requirement addresses this:**
- User Guide (migration section)
- README (relationship to legacy system noted)

**epicTreeGUI specific:** Has `old_epochtree/` for reference. Extract migration guidance BEFORE removing. Document what changed and why.

---

### Pitfall 9: Inconsistent Documentation Across Files

**What goes wrong:** README says one thing, User Guide says something different, CLAUDE.md describes yet another pattern. Function comments contradict documentation. User doesn't know which source to trust.

**Why it happens:**
- Documentation written at different times
- Multiple authors with different understanding
- Code evolved but not all docs updated
- No review process for consistency

**Consequences:**
- Users confused about correct approach
- Loss of trust in documentation
- Each doc source has errors, so comprehensive reading doesn't help
- Support burden from conflicting instructions

**Prevention:**
1. **Single source of truth** for key patterns
2. **Cross-reference between docs** clearly
3. **Pre-release consistency check** across all files
4. **Clear documentation hierarchy** (which to trust if conflict)

**Detection (warning signs):**
- You have 5+ markdown files with overlapping content
- Different docs show different examples for same task
- No clear "start here" for new users
- Documentation written at different times never reconciled

**Which requirement addresses this:**
- All documentation (consistency review pass)
- User Guide (primary authoritative source)
- README (simplified but consistent with User Guide)

**epicTreeGUI specific:** Currently has 30+ markdown files at root! CRITICAL: Need to consolidate user-facing vs internal docs, establish hierarchy, remove redundant files.

---

## Minor Pitfalls

Mistakes that cause annoyance but don't seriously impact adoption.

### Pitfall 10: Missing LICENSE File

**What goes wrong:** Potential users (especially in commercial settings or large institutions) cannot determine if they're allowed to use the tool. Legal departments block adoption.

**Why it happens:**
- "I'll add a license later" (then forget)
- Confusion about which license to choose
- Assumption that "public repo = free to use"
- Not understanding licensing implications

**Consequences:**
- Cannot be used in some institutional or commercial contexts
- Ambiguous legal status
- Reduced citations (some journals require clear licensing)
- Appears unprofessional

**Prevention:**
1. **Add LICENSE file** before making repository public (MIT is common for research)
2. **Reference in README** (License section)
3. **Document third-party code** if including others' work

**Detection (warning signs):**
- No LICENSE file in repository root
- README doesn't mention licensing
- Including code from other projects without attribution

**Which requirement addresses this:**
- LICENSE file requirement
- README (license section)

**epicTreeGUI specific:** NO LICENSE file in root. LICENSE files exist in subdirectories (old_epochtree/, new_retinanalysis/) but not for epicTreeGUI itself. MUST ADD before release.

---

### Pitfall 11: Outdated MATLAB Version Requirements

**What goes wrong:** README says "R2020b required" but actually works fine on R2019b. Or worse: says "R2019b" but uses features from R2021a. Users have wrong expectations.

**Why it happens:**
- Requirement based on developer's MATLAB version
- No testing on earlier/later versions
- Features added that require newer MATLAB, requirement not updated
- Conservative estimate without verification

**Consequences:**
- Unnecessarily excludes users with older MATLAB
- Or crashes for users with older MATLAB if requirement too low
- Support questions about version compatibility

**Prevention:**
1. **Test on minimum version** before stating requirement
2. **Check for specific features** rather than guessing version
3. **Document tested versions** explicitly

**Detection (warning signs):**
- Version requirement is "whatever version I have"
- No testing on other MATLAB versions
- Using version-specific features without checking

**Which requirement addresses this:**
- README (requirements section - tested versions)
- User Guide (installation prerequisites)

**epicTreeGUI specific:** README says "R2019b or later" but uses modern MATLAB features. Should verify actual minimum version by testing.

---

### Pitfall 12: No Attribution or Citation Information

**What goes wrong:** Researchers use tool, publish paper, don't know how to cite it. You get zero credit despite your work enabling their research.

**Why it happens:**
- "GitHub star is enough credit" assumption
- No CITATION.cff or citation instructions
- Forgetting that academics need citation formats
- Not prioritizing visibility of your contribution

**Consequences:**
- Reduced academic credit for tool development
- Tool impact invisible (papers use it but don't cite it)
- Missed opportunity to build reputation in field

**Prevention:**
1. **Provide citation format** in README (text + BibTeX)
2. **Add CITATION.cff** (GitHub-recognized format)
3. **Include citation in tool** (display on startup)

**Detection (warning signs):**
- No citation information in README
- No CITATION.cff file
- No instructions for academic attribution

**Which requirement addresses this:**
- README (citation section)
- CITATION.cff file (optional but useful)

**epicTreeGUI specific:** Currently no citation information. Should add before public release to ensure academic credit.

---

### Pitfall 13: Example Data Too Large or Missing

**What goes wrong:** README says "download example data" but:
- Link is broken
- File is 500 MB (too large for quick test)
- No example data at all

Users cannot try tool without generating their own data first.

**Why it happens:**
- Can't include large files in GitHub repo
- No infrastructure for hosting example data
- "Users will have their own data" assumption
- Example data contains sensitive/unpublished information

**Consequences:**
- High barrier to entry for trying tool
- Users give up before seeing value
- Cannot verify installation worked

**Prevention:**
1. **Provide minimal example** (< 10 MB) in repo
2. **Use Git LFS** for larger examples if needed
3. **Provide generator script** if cannot share real data
4. **Host large examples externally** (Zenodo, FigShare)

**Detection (warning signs):**
- No example data in repository
- Examples reference data not provided
- "Contact author for example data" in README

**Which requirement addresses this:**
- Example scripts (need data to run)
- Tutorial (needs example data for hands-on)

**epicTreeGUI specific:** References `/Users/maxwellsdm/Documents/epicTreeTest/` in docs. Need to create and bundle small example dataset (< 10 MB).

---

### Pitfall 14: No Visual Documentation

**What goes wrong:** README is all text and code. User has no idea what the GUI looks like or what output to expect. Cannot evaluate if tool meets their needs before investing time.

**Why it happens:**
- Text is easier than screenshots
- "Code speaks for itself" mentality
- Screenshots need updating when GUI changes
- Not considering that people evaluate tools visually

**Consequences:**
- Cannot assess tool fit without running it
- Unclear what "hierarchical browser" means
- Reduced visual appeal = lower interest
- Missed opportunity to showcase value

**Prevention:**
1. **Add screenshots to README** - Show the GUI
2. **Show example outputs** - What analysis produces
3. **Create visual quick start** - Step-by-step with images
4. **Keep images lightweight** (< 200 KB, compressed PNG)

**Detection (warning signs):**
- README has no images
- No visual examples of what tool produces
- User must run tool to see what it looks like

**Which requirement addresses this:**
- README (screenshots of GUI and outputs)
- Tutorial (step-by-step with visual guides)

**epicTreeGUI specific:** Has complex GUI with tree browser and data viewer. Screenshots would SIGNIFICANTLY improve README appeal and understanding.

---

## Phase-Specific Warnings

| Phase/Requirement | Likely Pitfall | Mitigation |
|-------------------|---------------|------------|
| **User Guide** | Assumes MATLAB path knowledge | Explicit setup with verification |
| **User Guide** | Data format assumed obvious | Document struct format with examples |
| **User Guide** | Migration from old system ignored | Add migration guide section |
| **Examples** | Hardcoded absolute paths | Use relative paths or bundled data |
| **Examples** | Examples fail in fresh session | Test in clean MATLAB before release |
| **Tutorial** | "Works on my machine" syndrome | Include ALL prerequisites explicitly |
| **Tutorial** | Jumps to advanced too quickly | Start with absolute basics |
| **README** | No visual appeal | Add GUI screenshots and output examples |
| **README** | Stale examples | Test all code before release |
| **README** | Missing critical sections | Checklist: Install, Quick Start, Features, License, Citation |
| **LICENSE** | No clear legal status | MIT license to root before public |
| **LICENSE** | Third-party attribution missing | Document licenses of included code |
| **Cleanup** | 30+ docs at root confusing | Consolidate or clearly label internal vs user |
| **Consistency** | Docs contradict each other | Consistency review pass across all files |

---

## Pre-Release Documentation Audit Checklist

Run through before tagging v1.0:

### Installation & Setup
- [ ] Path setup instructions clear with exact commands
- [ ] setup.m or install.m script provided
- [ ] Dependency requirements documented (MATLAB version, toolboxes)
- [ ] Example data available (< 15 MB) or download script
- [ ] Verification step (how to check installation worked)

### Examples & Code
- [ ] All README examples tested in fresh MATLAB session
- [ ] Examples use bundled data or show path adaptation
- [ ] Example scripts run without errors
- [ ] Function signatures in docs match actual code
- [ ] No hardcoded absolute paths (grep for /Users/, /home/, C:\\)

### Documentation Consistency
- [ ] README, User Guide, Tutorial tell same workflow
- [ ] Function help text matches User Guide descriptions
- [ ] No references to deprecated features
- [ ] Version numbers consistent across all docs
- [ ] Documentation hierarchy clear (which to trust if conflict)

### Discoverability
- [ ] Function index in README or User Guide
- [ ] Common tasks documented with examples
- [ ] Troubleshooting section with actual common errors
- [ ] Error messages explained (what they mean, how to fix)

### Legal & Attribution
- [ ] LICENSE file in repository root
- [ ] Citation format provided (text + BibTeX)
- [ ] Third-party code attributed
- [ ] License referenced in README

### Visual Appeal
- [ ] Screenshots of GUI included
- [ ] Example outputs shown
- [ ] Visual structure clear (not wall of text)
- [ ] Images compressed (< 200 KB each)

### Migration & Compatibility
- [ ] Relationship to legacy system documented (if applicable)
- [ ] Migration guide if replacing existing tool
- [ ] MATLAB version requirement tested, not assumed
- [ ] Toolbox requirements honest and tested

### Quality Checks
- [ ] No broken links in documentation
- [ ] No hardcoded personal file paths
- [ ] Troubleshooting covers actual errors users will see
- [ ] "Quick Start" actually works in < 5 minutes
- [ ] Documentation files consolidated (< 5 at root)

---

## Repository Organization Pitfalls

*(Already documented by codebase research agent - cross-reference)*

**Critical organizational issues for epicTreeGUI:**
1. **Documentation explosion** - 30+ markdown files at root
2. **Legacy code bloat** - old_epochtree/ and new_retinanalysis/ directories
3. **Test files scattered** - test_*.m and debug_*.m at root
4. **Mixed language confusion** - Python files mixed with MATLAB

These must be addressed alongside documentation pitfalls for successful release.

---

## Sources

**Based on:**
- Analysis of epicTreeGUI current documentation state (README.md, UserGuide.md, CLAUDE.md, repository structure)
- Common MATLAB research tool patterns and pitfalls from training data
- Research software engineering best practices
- GitHub repository analysis conventions
- Academic software sustainability literature

**Confidence Level:** HIGH
- Pitfalls derived from observed epicTreeGUI documentation state
- Prevention strategies tailored to MATLAB research tool context
- Examples use actual epicTreeGUI function names and patterns
- Directly applicable to v1.0 release requirements
- Cross-referenced with repository organization research

**Verification approach:** Each pitfall includes:
1. Detection method (how to spot if you're making this mistake)
2. Prevention strategy (concrete, actionable steps)
3. Mapping to requirements (which phase addresses it)
4. epicTreeGUI-specific notes (current status and recommendations)

**Note:** This research complements the repository organization pitfalls document. Both must be addressed for successful public release.
