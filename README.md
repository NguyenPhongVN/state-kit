# StateContext Utilities

A lightweight utility for managing sequential state access with an index cursor.

## Overview

`StateContext` provides a simple way to:

- Store an ordered collection of states (`[Any]` by default)
- Iterate through indices using `nextIndex()`
- Reset the cursor with `reset()`

It's useful in scenarios like building reducers, state machines, form wizards, or any flow where you need to advance through a list of values while keeping track of the current position.

## Installation

Add the source files directly to your Xcode project or Swift package.

If using Swift Package Manager, include the files in your target. (This repository currently contains only source files and does not define a package manifest.)

## Usage

```swift
// Initialize with an array of states and an optional starting index
let context = StateContext(states: ["idle", "loading", "success", "failure"], index: 0)

// Access indices in sequence
let i0 = context.nextIndex() // 0
let i1 = context.nextIndex() // 1
let i2 = context.nextIndex() // 2

// Read or mutate states array as needed
print(context.states[i1]) // "loading"

// Reset the cursor back to the beginning
context.reset()           // index becomes 0 again
let iReset = context.nextIndex() // 0
