quickshell/qml-summary/pipewire_object_summary.md
# Pipewire QML Object Summary (Quickshell)

This document summarizes the `Pipewire` singleton object from the `Quickshell.Services.Pipewire` module, focusing on its properties and usage in QML.

---

## Importing Pipewire

To use the Pipewire object in QML, import the module:

```
import Quickshell.Services.Pipewire
```

The `Pipewire` object is a singleton and can be accessed directly as `Pipewire`.

---

## Key Properties

### Audio Devices

- **defaultAudioSink** (`PwNode`, readonly):  
  The current default audio output (sink) node, or `null` if none.  
  - Reflects the sink currently used by applications.
  - May briefly become `null` when the default changes.
  - To set the default, use `preferredDefaultAudioSink`.
  - *(See PwNode summary below)*

- **defaultAudioSource** (`PwNode`, readonly):  
  The current default audio input (source) node, or `null` if none.  
  - Reflects the source currently used by applications.
  - May briefly become `null` when the default changes.
  - To set the default, use `preferredDefaultAudioSource`.
  - *(See PwNode summary below)*

- **preferredDefaultAudioSink** (`PwNode`):  
  Set this to hint which sink should be the default.  
  - Pipewire will try to use this as the default output.
  - *(See PwNode summary below)*

- **preferredDefaultAudioSource** (`PwNode`):  
  Set this to hint which source should be the default.  
  - Pipewire will try to use this as the default input.
  - *(See PwNode summary below)*

### Nodes and Links

- **nodes** (`ObjectModel<PwNode>`, readonly):  
  All Pipewire nodes (devices and streams) present on the system.  
  - Filter with properties like `PwNode.isStream`, `PwNode.isSink`, or `PwNode.audio` for specific types.
  - *(ObjectModel is a container for QML objects; see PwNode summary below)*

- **links** (`ObjectModel<PwLink>`, readonly):  
  All links between Pipewire nodes.  
  - Multiple links may exist between the same nodes.
  - Use `linkGroups` for a deduplicated list.
  - *(See PwLink summary below)*

- **linkGroups** (`ObjectModel<PwLinkGroup>`, readonly):  
  Deduplicated list of link groups between nodes.  
  - Prefer this over `links` if you only need one entry per node pair.
  - *(See PwLinkGroup summary below)*

### State

- **ready** (`bool`, readonly):  
  True if Quickshell has completed its initial sync with the Pipewire server.  
  - When `true`, all nodes, links, and preferences are up-to-date.
  - You can use `Pipewire` before it is ready, but some data may be missing or incomplete.

---

## Usage Example

```qml
import Quickshell.Services.Pipewire

Item {
  // Display the name of the current default audio output
  Text {
    text: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.name : "No default sink"
  }

  // Change the preferred default audio output
  Button {
    text: "Set Preferred Output"
    onClicked: {
      // Example: set to the first available sink node
      for (let i = 0; i < Pipewire.nodes.count; ++i) {
        let node = Pipewire.nodes.get(i);
        if (node.isSink) {
          Pipewire.preferredDefaultAudioSink = node;
          break;
        }
      }
    }
  }
}
```

---

## Notes

- Use `Pipewire.ready` to check if the object is fully synchronized before relying on its data.
- When the default sink or source changes, the corresponding property may briefly become `null`.
- For tracking connections to a specific node, use `PwNodeLinkTracker` instead of filtering `links` or `linkGroups`.
- For detailed explanations of related types (such as PwNode, PwLink, etc.), see the "Related Types (Summary)" section below.

---

## Summary Table

| Property                      | Type                        | Description                                      |
|-------------------------------|-----------------------------|--------------------------------------------------|
| defaultAudioSink              | PwNode (readonly)           | Current default audio output node                 |
| defaultAudioSource            | PwNode (readonly)           | Current default audio input node                  |
| preferredDefaultAudioSink     | PwNode                      | Set preferred default output node                 |
| preferredDefaultAudioSource   | PwNode                      | Set preferred default input node                  |
| nodes                         | ObjectModel<PwNode>         | All Pipewire nodes                               |
| links                         | ObjectModel<PwLink>         | All links between nodes                           |
| linkGroups                    | ObjectModel<PwLinkGroup>    | Deduplicated link groups                          |
| ready                         | bool (readonly)             | True if Pipewire is fully synced                  |

---

## Related Types (Summary)

### PwNode
Represents a node in the Pipewire graph (device or stream).
- **audio**: `PwNodeAudio` (readonly) — Extra info if the node handles audio.
- **description**: Human-readable description.
- **id**: Pipewire object ID (useful for debugging).
- **isSink**: True if node accepts audio input.
- **isStream**: True if node is likely a program, false for hardware.
- **name/nickname**: Identifiers for the node.
- **properties**: Key-value property set (may include `application.name`, `media.title`, etc).
- **ready**: True if node is fully bound and ready.
- **type**: Reflects Pipewire’s media.class.

### PwNodeAudio
Extra properties for audio nodes.
- **channels**: List of `PwAudioChannel` (readonly).
- **muted**: Whether the node is muted (settable).
- **volume**: Average volume (settable).
- **volumes**: Per-channel volumes (settable).
> *Note: These properties are only valid if the node is bound.*

### PwAudioChannel
Enum for audio channel types (e.g., `FrontLeft`, `FrontRight`, `Mono`, `TopCenter`, etc).
- Use `toString(value)` for a human-readable name.
- Includes ranges for auxiliary and custom channels.

### PwNodeType
Singleton for filtering node types (audio, video, sink, source, stream) using bitwise comparisons.
- Use `toString(type)` for string representation.

### PwLink
Represents a single link (connection) between nodes (one per channel).
- **id**: Pipewire object ID.
- **source**: Source node.
- **target**: Target node.
- **state**: Current state (`PwLinkState`).
> *Note: Usually, you want `PwLinkGroup` instead of individual links.*

### PwLinkGroup
A group of connections between nodes (one per source-target pair).
- **source**: Source node.
- **target**: Target node.
- **state**: Current state (`PwLinkState`).

### PwLinkState
Enum for link states (e.g., `Active`, `Allocating`, `Error`, `Init`, `Negotiating`, `Paused`, `Unlinked`).
- Use `toString(value)` for string representation.

### PwNodeLinkTracker
Tracks all link connections to a given node.
- **linkGroups**: List of `PwLinkGroup` connected to the node.
- **node**: The node being tracked.

### PwObjectTracker
Binds every node in its `objects` list, making all properties available for use or modification.
- **objects**: List of objects to bind (may contain nulls).
> *Binding is required for full property access on Pipewire objects.*

---

This summary should help you use the Pipewire object effectively in Quickshell QML projects.