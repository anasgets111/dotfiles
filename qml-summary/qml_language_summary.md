# QML Language Summary

---

## Table of Contents

- [Key Points](#key-points)
- [1. File Structure](#1-file-structure)
- [2. Imports](#2-imports)
- [3. Objects](#3-objects)
- [4. Properties](#4-properties)
- [5. Property Access](#5-property-access)
- [6. Functions & JavaScript](#6-functions--javascript)
- [7. Signals](#7-signals)
- [8. Creating Types](#8-creating-types)
- [9. Reactive Bindings](#9-reactive-bindings)
- [10. Lazy Loading & Components](#10-lazy-loading--components)
- [11. Item Size and Position (Quickshell)](#11-item-size-and-position-quickshell)
- [Example QML Snippet](#example-qml-snippet)

---

## Key Points

- QML is declarative, reactive, and JavaScript-enabled.
- Use uppercase for types/objects, lowercase for properties/ids.
- Imports and object structure are crucial.
- Property bindings and signal handlers are central to reactivity.
- Functions and lambdas can be used for logic and callbacks.
- Each file can define a new type, which can be imported or used inline.

---

## 1. File Structure

- QML files are structured as a tree of objects.
- Each file typically starts with one or more `import` statements.
- The root object defines the main component.

## 2. Imports

- Import QML modules, directories, or JavaScript files:
  ```
  import QtQuick
  import QtQuick.Controls as Controls
  import "myjs.js" as MyJs
  ```
- Module and namespace names must start with an uppercase letter.
- Types in neighboring files (with uppercase names) are implicitly imported.

## 3. Objects

- Objects are instances of types (e.g., `Item`, `Rectangle`, `Button`).
- Object names must start with an uppercase letter.
  ```
  Item {
    // ...
  }
  ```

## 4. Properties

- Properties are key-value pairs or bindings.
- Syntax:
  ```
  property <type> <name>: <value>
  readonly property string label: "Hello"
  ```
- Bindings can be expressions or multi-line JavaScript blocks.
- All property bindings are **reactive** (auto-update on dependency change).

### Special Properties

- `id`: Assigns a unique lowercase identifier for referencing the object in the file.
- `default`: Marks a property as the default, allowing child objects to be assigned without naming the property.
  Example:
  ```
  default property alias content: children
  ```

## 5. Property Access

- Access properties of:
  - The current object: `propertyName` or `this.propertyName`
  - The root object: direct reference
  - Other objects: via their `id` (e.g., `button.text`)
  - Parent object: `parent.propertyName`

## 6. Functions & JavaScript

- QML supports inline JavaScript for logic, expressions, and functions.
- Define functions with JavaScript syntax:
  ```
  function name(param: type): returnType {
    // ...
    return value;
  }
  ```
- Functions are reactive if they depend on reactive properties.

### Lambdas

- Short-form functions:
  ```
  (x) => x * 2
  ```

## 7. Signals

- Declare custom signals:
  ```
  signal name(param: type)
  ```
- Connect signals:
  - Using handlers: `on<SignalName>: { ... }` (handler property is named with the first letter capitalized, e.g., `onClicked`)
  - Using `.connect`: `signal.connect(function)`
  - With `Connections` object for indirect handling.

### Property Change Signals

- Every property has a `<propertyName>Changed` signal.
- Handlers: `on<PropertyName>Changed: { ... }`

## 8. Creating Types

- Each uppercase-named QML file defines a reusable type.
- Inline components: `component Name: Type { ... }` (scoped to the file).
- Singletons: Add `pragma Singleton` at the top of the file.

## 9. Reactive Bindings

- Bindings update automatically when dependencies change.
- Manual bindings: `Qt.binding(() => { ... })`
- Remove bindings by assigning a new value directly.

## 10. Lazy Loading & Components

- Use `Component` and `LazyLoader` for deferred or repeated instantiation.

---

## 11. Item Size and Position (Quickshell)

- **Size Properties**: Every `Item` (and its subclasses) has two sets of size properties:
  - `width` / `height`: The actual size.
  - `implicitWidth` / `implicitHeight`: The desired or natural size.
- **Container Behavior**: Containers (layouts, wrappers) use the *implicit size* of their children to determine their own implicit size, and use their *actual size* to set the size of their children.
  - *Implicit size flows from children to parent; actual size flows from parent to children.*
- **Position Properties**: Items have `x` and `y` for position. These should not be set directly if the item is managed by a container.
- **Zero Size Warning**: Many QtQuick items have zero size by default. Always set at least the implicit size for custom containers to avoid invisible items.
- **Margins and Wrappers**: Use margin properties or wrapper components to add spacing around children. Quickshell provides `WrapperItem`, `WrapperRectangle`, and `WrapperMouseArea` for common margin use-cases.
- **Anchors**: Use `anchors` (e.g., `anchors.fill: parent`, `anchors.margins: ...`) to reduce boilerplate for positioning and sizing.
  Example:
  ```
  Rectangle { anchors.fill: parent; anchors.margins: 8 }
  ```
- **Avoid Binding Loops**: Do not use `childrenRect` to set a container's implicit size if the children are anchored to the parent—this creates a binding loop.
- **MarginWrapperManager**: Use this Quickshell component to automatically manage margin and sizing relationships between a container and its child.
- **Layouts**: Prefer `RowLayout`, `ColumnLayout`, and `GridLayout` (from `QtQuick.Layouts`) for arranging items. These provide spacing, pixel alignment, and flexibility. Avoid using `Row` and `Column` unless you intentionally want to break pixel alignment.

---

## Example QML Snippet

```
import QtQuick

Item {
  id: root
  property int count: 0

  Button {
    text: `Clicked ${root.count} times`
    onClicked: root.count += 1
  }

  Text {
    text: root.count > 0 ? "You've clicked!" : "Click the button"
  }
}
```

---
