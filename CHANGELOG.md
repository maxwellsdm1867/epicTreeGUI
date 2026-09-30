# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Rieke OS [0.1.3] - 2026-09-30

This desktop candidate uses the explicit unsigned testing channel. It is separate
from the MATLAB library version below and from signed production distribution.

### Added
- Self-contained Apple Silicon desktop packaging with private Python and MySQL runtimes, folder selection, controlled installation, and testing-channel updates.
- Persistent native tag membership and autocomplete dictionaries, with Unicode prefix indexes, maintained usage counts, and exact author attribution.
- Transactional annotation history, incremental current-state recovery, and verified index migration and reuse.

### Improved
- Small annotation batches acknowledge durable saves promptly; cell tags inherit by cell UUID without copying annotations into every epoch.
- Large-project browsing, selection, metadata storage, cache validation, and protocol-scoped curation preserve exact scientific identities.
- Portable project handling, folder-boundary checks, draft preservation, and desktop service lifecycle validation.

At 100,000 synthetic epochs, tag autocomplete measured 21–26 ms. Initial native
index preparation took about two minutes; the paired two-save/filter API sequence
measured 192 ms. See the [reproducible benchmark report](docs/dev/scale-audit-2026-09-29/native-tag-sequence-results.md)
for scope, first-use measurements, and limitations.

## [1.0.0] - 2026-02-28

### Added
- epicTreeTools hierarchical tree system for organizing neurophysiology epochs
- epicTreeGUI browser interface with 40/60 split tree and viewer panels
- 22+ splitter functions for dynamic tree reorganization by experimental parameters
- getSelectedData data extraction function respecting user selections
- .ugm (User-Generated Metadata) persistence system for selection state
- Selection state management with isSelected flags and propagation logic
- install.m script for automated MATLAB path setup
- Comprehensive test suite with 60+ test cases covering core functionality
- Documentation for tree navigation, selection patterns, and Python integration

### Changed
- Pure MATLAB replacement of legacy Java-based epoch tree system
- Simplified architecture with epoch.isSelected as source of truth (no centralized mask)
- Three-file architecture: H5/MAT (raw data), UGM (selection state), workspace (active tree)

## [Unreleased]

Future enhancements will be listed here.
