# Delete Property — Design Spec

**Date:** 2026-06-24  
**Status:** Approved

## Overview

Add a context-sensitive trash button to the sidebar toolbar that lets the user delete the currently selected property, with a confirmation alert before committing the destructive action.

## Toolbar Layout

Two items in the top-right of `SidebarView`'s toolbar, in order:

1. **Trash button** (new) — `trash` system image. Enabled only when a property is selected (`selectedID != nil`). Disabled/grayed otherwise.
2. **"+" menu** (existing) — unchanged. Contains Add Property and Add User.

The trash button is placed to the left of the "+" menu so destructive and constructive actions are visually adjacent but distinct.

## Delete Property Flow

1. User selects a property in the sidebar (trash button becomes enabled).
2. User clicks the trash button.
3. An `.alert` appears:
   - **Title:** "Delete [Property Name]?"
   - **Message:** "This cannot be undone."
   - **Buttons:** destructive "Delete" + "Cancel"
4. On "Delete": `store.delete(id: selectedID)` is called.
5. `MainDashboardView`'s existing `onChange(of: store.properties)` auto-selects the next available property, or clears selection if none remain. No additional navigation logic needed.

## Store Change

Add one method to `PropertyStore`:

```swift
func delete(id: String) {
    properties.removeAll { $0.id == id }
    saveToDisk()
}
```

No changes to the `Property` model or JSON schema.

## Delete User

Deferred. Users are not yet a modeled concept in the app — only a placeholder "Add User" sheet exists. A delete action will be added when user management is built out. No placeholder button is added now to avoid a confusing disabled UI element.

## Files Affected

- `CozumelManager/Models/PropertyModel.swift` — add `delete(id:)` method
- `CozumelManager/Views/SidebarView.swift` — add trash `ToolbarItem` with alert state

## Out of Scope

- Deleting photos from disk when a property is deleted (can be addressed later)
- Undo/redo support
- User management or Delete User
