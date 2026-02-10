# HoffSoft CMake Object API (`cmake/object.cmake`)

This document describes the **public API** exposed by HoffSoft’s `object(...)` layer.

It provides a uniform “object handle” model on top of HoffSoft’s internal encodings (record/array/dict blobs), with:

- **Opaque auto-generated handles** (tokens like `HS_HNDL_123`).
- Object blobs stored in a **GLOBAL property store**.
- A consistent split between:
    - **`GET`** → returns **handles to objects only** (never scalars)
    - **`STRING`** → returns **scalar strings** (or `"NOTFOUND"`)
- Strong invariants:
    - **Records** hold **strings only**.
    - **Arrays** hold **records and/or arrays only** (never strings; never dicts).
    - Objects created with label `"<unnamed>"` **must be renamed** before any mutation (except `RENAME`).

---

## Quick summary (commands)

### Core introspection
- `object(KIND <handleVar> <outKindVar>)`
- `object(ASSERT_KIND <handleVar> <expectedKind>...)`
- `object(NAME <outStrVar> FROM <handleVar>)`

### Lifecycle / naming
- `object(CREATE <outHandleVar> KIND RECORD [LABEL <label>] [LENGTH <n>] [FIELDS "<f1;f2;...>"] [FIXED])`
- `object(CREATE <outHandleVar> KIND DICT   [LABEL <label>])`
- `object(CREATE <outHandleVar> KIND ARRAY  [LABEL <label>] TYPE RECORDS|ARRAYS)`
- `object(CREATE_VIEW <handleVar> FROM <outHandleVar> [ <outHandleVar> [ <outHandleVar> [ ... ]]] )`
- `object(RENAME <handleVar> <newLabel>)`

### Record operations (strings only)
- `object(SET <recHandleVar> INDEX <startIndex> <v1> <v2> ... )`
- `object(SET <recHandleVar> NAME EQUAL <fieldName> VALUE <v>)` *(named records only)*
- `object(FIELD_NAMES <recHandleVar> NAMES "<f1;f2;...>")`
- `object(STRING <outStrVar> FROM <recHandleVar> INDEX <n>)`
- `object(STRING <outStrVar> FROM <recHandleVar> NAME EQUAL <fieldName>)`

### Dict operations (may contain scalars and/or object blobs)
- `object(GET    <outHandleVar> FROM <dictHandleVar> NAME EQUAL <key>)`
- `object(GET    <outHandleVar> FROM <dictHandleVar> NAME MATCHING <regex>)`
- `object(STRING <outStrVar>    FROM <dictHandleVar> NAME EQUAL <key>)`
- `object(KEYS   <outListVar>   FROM <dictHandleVar>)`
- `object(SET    <dictHandleVar> NAME EQUAL <key> HANDLE <childHandleVar> [REPLACE])`
- `object(SET    <dictHandleVar> NAME EQUAL <key> STRING <value>         [REPLACE])`

### Array operations (object-only container: RECORD/ARRAY)
- `object(GET    <outHandleVar> FROM <arrayHandleVar> INDEX <n>)`
- `object(APPEND <arrayHandleVar> RECORD <recordHandleVar>)`
- `object(APPEND <arrayHandleVar> ARRAY  <arrayHandleVar>)`
- `object(REMOVE ARRAY FROM <arrayHandleVar> NAME EQUAL <childName> [REPLACE WITH <newHandleVar>] [STATUS <resultVar>])`

### Path traversal and matching (objects/scalars)
- `object(GET    <outHandleVar> FROM <rootHandleVar> PATH EQUAL "<A/B/C>")`
- `object(GET    <outHandleVar> FROM <rootHandleVar> PATH MATCHING "<globPath>")`
- `object(STRING <outStrVar>    FROM <rootHandleVar> PATH EQUAL "<A/B/C>")`
- `object(STRING <outStrVar>    FROM <rootHandleVar> PATH MATCHING "<globPath>")`
- `object(MATCHES <outHandleVar> FROM <rootHandleVar> PATH MATCHING "<globPath>")` *(returns dict of path → value/blob)*

### Iteration helpers
- `object(ITER_HANDLES <outListVar> FROM <handleVar> CHILDREN)`
- `foreachobject(FROM <handleVar> CHILDREN CALL <fn>)`

---

## Concepts & invariants

### Handles vs labels
- A **handle** is an opaque token (string) returned by `object(CREATE ...)`.
- A **label** (aka “name”) is the human-facing name stored *inside* the object blob:
    - Set at creation time via `LABEL ...`
    - Changed via `object(RENAME ...)`
- `NAME`/`PATH` operations operate on **labels**, not handle tokens.

### Not-found conventions (important for migration)
- **Handle-returning operations** (`GET`, iterators):
    - return `""` when not found
    - so you can write: `if(NOT child) ...`
- **String-returning operations** (`STRING`):
    - return literal string `"NOTFOUND"` when not found

### “Unnamed” mutation gate
If an object’s label is `"<unnamed>"`:
- Allowed mutating operation: **`RENAME` only**
- Any other mutator (`SET`, `APPEND`, `FIELD_NAMES`, dict `SET`, etc.) must fail.

Rationale: it prevents creating anonymous structures that later break name-based navigation.

---

## Detailed command reference

## `object(CREATE ...)`

### `KIND RECORD`

**Semantics**
- If **neither** `LENGTH` nor `FIELDS` is given: creates an **indexed record** of length `0`.
- If `LENGTH n` is given:
    - record is **indexed** (keys `"0".."n-1"`)
    - if `FIXED` is also given, writes beyond bounds are **FATAL_ERROR**
- If `FIELDS` is given:
    - record is **named** (keys are those field names)
    - record is automatically **fixed-length**
    - **index-based operations are forbidden** after naming (use `NAME EQUAL`)

**Contents**
- Records hold **strings only**.

---

### `KIND DICT`

**Semantics**
- Creates an empty dictionary.
- Dict values may be:
    - object blobs (retrieved via `GET`)
    - scalar strings (retrieved via `STRING`)

---

### `KIND ARRAY`

**Semantics**
- Arrays are **object-only** containers.
- `TYPE RECORDS` means it can contain **records only**.
- `TYPE ARRAYS` means it can contain **arrays only** (nested arrays).

---

## `object(RENAME ...)`

**Semantics**
- Renames *any* object’s label.
- `"<unnamed>"` is not allowed as a new label.
- Must be called before any other mutation if the current label is `"<unnamed>"`.

---

## `object(NAME ...)`


Returns the object’s label as a string (or `"<unnamed>"`).

---

## `object(KIND ...)`

FATAL_ERROR if kind doesn’t match any expected kind.

---

## `object(SET ...)` (mutator)

### Record: bulk indexed set

**Rules**
- Only for **indexed records**.
- Indexed records can grow unless fixed.
- If record is fixed and you write out of bounds → **FATAL_ERROR**.
- “Gaps” created by extending are treated as **unwritten** and read back as `"NOTFOUND"` until set.

---

### Record: named field set

**Rules**
- Only for **named records**.
- Field must exist; otherwise **FATAL_ERROR**.

---

### Dict: set an object value

### Dict: set a scalar string value

**Overwrite policy**
- If `<key>` already exists:
    - without `REPLACE` → **FATAL_ERROR**
    - with `REPLACE` → overwrite is allowed

**Rules**
- Inserting an object whose label is `"<unnamed>"` is forbidden (rename it first).

---

## `object(FIELD_NAMES ...)` (record mutator)

**Semantics**
- Converts an indexed record (`"0".."n-1"`) into a named record.
- The number of names must exactly match the record’s length.
- After this, the record becomes **named & fixed**, and INDEX addressing is no longer allowed.

---

## `object(STRING ...)`

### Record

Returns:
- field value, or
- `"NOTFOUND"` if missing/out of bounds/unwritten.

### Dict

Returns:
- scalar value, or `"NOTFOUND"` if missing.

If the key holds an object blob, `STRING` must **FATAL_ERROR** (use `GET`).

### Path scalar lookup

Returns:
- scalar value, or `"NOTFOUND"` if not found.

If the resolved value is an object blob, `STRING` must **FATAL_ERROR** (use `GET`).

---

## `object(GET ...)`

### Dict

Returns:
- `""` if not found
- otherwise a new handle to the child object

If the dict value is scalar, `GET` must **FATAL_ERROR**.

### Array

Returns:
- `""` if out of range
- otherwise a handle to the element

Arrays are hardened to allow **only** `{RECORD|ARRAY}` element kinds.

### Path object lookup

Returns:
- `""` if not found
- otherwise a handle to the matched object

If the resolved value is scalar, `GET` must **FATAL_ERROR**.

---

## `object(MATCHES ...)` (PATH MATCHING)

Returns a **DICT handle** where:
- key = matched path string (`"A/B/C"`)
- value = matched value (either scalar string or object blob)

You can then use:
- `object(STRING ... FROM hits NAME EQUAL "A/B/C")` for scalars
- `object(GET ... FROM hits NAME EQUAL "A/B/C")` for objects

---

## `object(KEYS ...)`

Returns a CMake list of keys (dict storage order).

---

## `object(APPEND ...)` (array mutator)

**Rules**
- Array must not be `"<unnamed>"` (rename first).
- Child must not be `"<unnamed>"` (rename first).
- Enforces the array’s `TYPE`:
    - `RECORDS` arrays accept only records
    - `ARRAYS` arrays accept only arrays
- Duplicate child labels at the same array level → **FATAL_ERROR**

---

## `object(REMOVE ...)` (array mutator)

**Syntax**
```cmake
object(REMOVE ARRAY FROM <arrayHandleVar> NAME EQUAL <childName> [REPLACE WITH <newHandleVar>] [STATUS <resultVar>])
```

**Semantics**
- Searches the array for an element whose label/name matches `<childName>`
- If found:
    - **Without `REPLACE WITH`**: removes the element from the array
    - **With `REPLACE WITH`**: replaces the element with the new object
- Returns status via `STATUS` variable (optional):
    - `"REMOVED"` - element was found and removed
    - `"REPLACED"` - element was found and replaced
    - `"NOT_FOUND"` - no element with matching name was found

**Rules**
- Array must not be `"<unnamed>"` (rename first)
- When replacing:
    - Replacement object must not be `"<unnamed>"` (rename first)
    - Replacement object kind must match array type (RECORD for ARRAY_RECORDS, ARRAY for ARRAY_ARRAYS)
    - If replacement has a different label than the removed element, the new label must not already exist in the array (no duplicates)
- When the same label is used for replacement, it's allowed (update in place)

**Example: Simple removal**
```cmake
object(CREATE myArray KIND ARRAY LABEL "items" TYPE RECORDS)
object(CREATE rec1 KIND RECORD LABEL "item1")
object(CREATE rec2 KIND RECORD LABEL "item2")
object(APPEND myArray RECORD rec1)
object(APPEND myArray RECORD rec2)

# Remove item1
object(REMOVE ARRAY FROM myArray NAME EQUAL "item1" STATUS result)
# result = "REMOVED"
```

**Example: Replace element**
```cmake
object(CREATE myArray KIND ARRAY LABEL "items" TYPE RECORDS)
object(CREATE rec1 KIND RECORD LABEL "old-item")
object(APPEND myArray RECORD rec1)

object(CREATE rec2 KIND RECORD LABEL "new-item")
object(REMOVE ARRAY FROM myArray NAME EQUAL "old-item" REPLACE WITH rec2 STATUS result)
# result = "REPLACED"
# Array now contains rec2 instead of rec1
```

**Future extensions**
- `REMOVE RECORD` is currently not implemented but could support removing fields from named records

---

## Iteration helpers

### `object(ITER_HANDLES ...)`

Returns a list of **child handle tokens**.

- For DICT: returns handles for **object-valued** entries only (scalar entries are skipped)
- For ARRAY: returns handles for all elements

### `foreachobject(...)` (callback style)

Where `<fn>` is a callable CMake command that accepts one argument: the child handle token.

Example:
```cmake
foreachobject(FROM myDict CALL object(STRING ...

---

## Glob rules for `PATH MATCHING`

`<globPath>` is split by `/` into segments:

- `*`  matches **exactly one** segment
- `**` matches **zero or more** segments
- literals match exactly

Examples:
- `A/*/C` matches `A/B/C` only
- `A/**/C` matches `A/C`, `A/B/C`, `A/B/D/C`, ...

---

## Migration tips

- Replace `record(CREATE ...)` + `record(SET ...)` bulk writes with:
  - `object(CREATE h KIND RECORD LABEL "...")`
  - `object(SET h INDEX 0 ...values...)`
- Replace dict lookups:
  - old: `dict(GET d "Key" out)`  
  - new (object child): `object(GET h FROM d NAME EQUAL "Key")`
  - new (scalar): `object(STRING s FROM d NAME EQUAL "Key")`
