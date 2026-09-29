# Epoch data exploration

Vocabulary for inspecting, organizing, and curating neurophysiology recordings. These terms distinguish recorded experimental structure from the ways a researcher explores it.

## Language

**Project**:
A research workspace spanning the recordings, experimental protocols, curated collections and analyses relevant to a scientific effort.
_Avoid_: A single protocol, a single recording

**Protocol coverage**:
The cells and recordings available for each user-defined protocol workspace within a project, including which cells participate in more than one workspace.
_Avoid_: A sum of protocol cell counts as the project's distinct cell count

**Query preset**:
A named, reusable set of criteria for finding relevant recordings or epochs as a project's data grows.
_Avoid_: A frozen dataset revision

**Review status**:
The recorded inspection or approval state of particular data, scoped to the version and scientific context that was reviewed.
_Avoid_: Whether an item is focused, whether it has any tag

**Cell across protocols**:
One identified recorded cell with data from multiple experimental protocols, allowing one protocol's observations to be inspected in the context of another.
_Avoid_: Matching cells solely by a repeated label such as Cell2

**Cell display label**:
Recording date plus original cell name/number, with a separate cell-type tag; include a session qualifier when labels collide. Stable cell UUIDs are available as details.
_Avoid_: Using a mutable cell-type classification as a database key

**Recorded duration**:
The sum of recording durations for distinct epochs in an explicit scope and timebase, counting an epoch once across its streams and excluding gaps.
_Avoid_: Session elapsed time, stimulation time, summing the same epoch once per device

**Epoch**:
A single recorded trial, with its timing, stimulus conditions, and responses.
_Avoid_: Cell, experiment, dataset

**Acquisition hierarchy**:
The experimental relationships recorded when data was collected: experiment, animal, preparation, cell, epoch group, epoch block, and epoch.
_Avoid_: Split tree

**Split tree**:
A researcher's ordered grouping of epochs by criteria such as cell type, recording date, protocol, or stimulus parameter. The same epochs can have multiple split trees.
_Avoid_: Acquisition hierarchy, database schema

**Epoch inclusion**:
A decision about whether an epoch participates in a particular analysis or curated collection.
_Avoid_: Display focus

**Display focus**:
The cell, group, or epoch currently being inspected. Focusing an item does not by itself decide its inclusion in analysis.
_Avoid_: Epoch inclusion

**Acquisition protocol**:
The procedure recorded by the acquisition system to generate trials, identified by its original protocol name and parameters.
_Avoid_: User-defined protocol workspace

**Protocol workspace**:
A user-defined organization of related recordings, saved queries, datasets and figures within a project, such as variable-mean noise current injection or current injection across frequency cutoffs.
_Avoid_: Assuming every linked measurement or figure is a separate protocol

**Linked figure**:
A visualization associated with a protocol workspace, cell, dataset or analysis, retaining the source/input context needed to interpret it.
_Avoid_: Treating a receptive-field figure as automatically defining a protocol
