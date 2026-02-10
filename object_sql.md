# HoffSoft CMake Object API - SQL Edition (`cmake/object_sql.cmake`)

This document describes the **SQL-like syntax** for HoffSoft's object layer.

It provides the same uniform "object handle" model with a familiar SQL-inspired interface:

- **Opaque auto-generated handles** (tokens like `HS_HNDL_123`)
- Object blobs stored in a **GLOBAL property store**
- SQL-style commands: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `CREATE TABLE`
- Strong invariants:
    - **Records** (tables/rows) hold **strings only**
    - **Arrays** (collections) hold **records and/or arrays only**
    - Objects created without a name **must be named** before mutation

---

## Quick Summary (SQL-Style Commands)

### Schema Definition Language (DDL)
- `CREATE TABLE <handleVar> [AS <name>] [COLUMNS (<col1>, <col2>, ...)] [FIXED]`
- `CREATE COLLECTION <handleVar> [AS <name>] OF RECORDS|ARRAYS`
- `CREATE DICTIONARY <handleVar> [AS <name>]`
- `ALTER TABLE <handleVar> RENAME TO <newName>`
- `ALTER TABLE <handleVar> ADD COLUMNS (<col1>, <col2>, ...)`

### Data Manipulation Language (DML)
- `SELECT * FROM <handleVar> INTO <outHandleVar>`
- `SELECT <column> FROM <handleVar> WHERE NAME = <value> INTO <outStrVar>`
- `SELECT VALUE FROM <handleVar> WHERE KEY = <key> INTO <outStrVar>`
- `INSERT INTO <handleVar> VALUES (<v1>, <v2>, ...) [AT INDEX <n>]`
- `INSERT INTO <handleVar> (<col>) VALUES (<value>)`
- `INSERT INTO <handleVar> (KEY <key>) VALUES OBJECT <childHandleVar> [REPLACE]`
- `INSERT INTO <handleVar> (KEY <key>) VALUES STRING <value> [REPLACE]`
- `UPDATE <handleVar> SET <column> = <value> WHERE NAME = <fieldName>`
- `DELETE FROM <handleVar> WHERE NAME = <childName> [REPLACE WITH <newHandleVar>] [STATUS <resultVar>]`

### Query Operations
- `SELECT * FROM <handleVar> WHERE PATH = "<A/B/C>" INTO <outHandleVar>`
- `SELECT * FROM <handleVar> WHERE PATH LIKE "<glob>" INTO <outHandleVar>`
- `SELECT VALUE FROM <handleVar> WHERE PATH = "<A/B/C>" INTO <outStrVar>`
- `SELECT MATCHES FROM <handleVar> WHERE PATH LIKE "<glob>" INTO <outHandleVar>`

### Metadata & Inspection
- `DESCRIBE <handleVar> [INTO <outKindVar>]`
- `SHOW COLUMNS FROM <handleVar> INTO <outListVar>`
- `SHOW KEYS FROM <handleVar> INTO <outListVar>`
- `SHOW NAME FROM <handleVar> INTO <outStrVar>`

### Iteration
- `SELECT HANDLES FROM <handleVar> INTO <outListVar>`
- `FOREACH ROW IN <handleVar> CALL <function>`

---

## Concepts & Invariants

### Handles vs Names
- A **handle** is an opaque token (string) returned by `CREATE` statements
- A **name** (label) is the human-facing identifier stored inside the object
- Query operations use **names**, not handle tokens

### Not-Found Conventions
- **Handle-returning queries** (`SELECT * ... INTO`):
    - return `""` when not found
    - test with: `if(NOT result) ...`
- **Value-returning queries** (`SELECT VALUE ... INTO`):
    - return literal string `"NOTFOUND"` when not found

### Unnamed Objects
Objects without a name cannot be mutated (except via `ALTER ... RENAME TO`).

---

## Detailed Command Reference

## Schema Definition Language (DDL)

### `CREATE TABLE`

Creates a new record (row/table).

**Syntax:**
```cmake
CREATE TABLE myRec [AS <name>] [COLUMNS (<col1>, <col2>, ...)] [FIXED]
```

**Variants:**
- **No COLUMNS**: Creates indexed table (columns "0", "1", "2", ...)
- **With COLUMNS**: Creates named table with specified column names
- **FIXED**: Prevents adding new columns/rows beyond initial size

**Examples:**
```cmake
# Indexed table
CREATE TABLE employee AS "John"

# Named columns
CREATE TABLE employee AS "John" COLUMNS (name, age, department)

# Fixed-size table
CREATE TABLE coords COLUMNS (x, y, z) FIXED
```

---

### `CREATE COLLECTION`

Creates an array container for records or nested arrays.

**Syntax:**
```cmake
CREATE COLLECTION myArr [AS <name>] OF RECORDS|ARRAYS
```

**Rules:**
- `OF RECORDS`: Can only contain record objects
- `OF ARRAYS`: Can only contain array objects (nested collections)

**Examples:**
```cmake
CREATE COLLECTION employees AS "staff" OF RECORDS
CREATE COLLECTION matrix AS "grid" OF ARRAYS
```

---

### `CREATE DICTIONARY`

Creates a key-value dictionary.

**Syntax:**
```cmake
CREATE DICTIONARY myDict [AS <name>]
```

**Examples:**
```cmake
CREATE DICTIONARY config AS "settings"
```

---

### `ALTER TABLE ... RENAME TO`

Renames any object.

**Syntax:**
```cmake
ALTER TABLE <handleVar> RENAME TO <newName>
```

**Examples:**
```cmake
CREATE TABLE emp
ALTER TABLE emp RENAME TO "employee"
```

---

### `ALTER TABLE ... ADD COLUMNS`

Converts an indexed table to named columns.

**Syntax:**
```cmake
ALTER TABLE <handleVar> ADD COLUMNS (<col1>, <col2>, ...)
```

**Rules:**
- Number of columns must match table size
- After this, table becomes fixed-size and named
- Index-based access is no longer allowed

**Examples:**
```cmake
CREATE TABLE rec
INSERT INTO rec VALUES ("John", "30", "Engineering") AT INDEX 0
ALTER TABLE rec ADD COLUMNS (name, age, department)
```

---

## Data Manipulation Language (DML)

### `SELECT * FROM ... INTO` (Object Retrieval)

Retrieves a child object handle.

**Syntax:**
```cmake
# From dictionary by key
SELECT * FROM <dictHandleVar> WHERE KEY = <key> INTO <outHandleVar>

# From collection by index
SELECT * FROM <collectionHandleVar> WHERE INDEX = <n> INTO <outHandleVar>

# By path
SELECT * FROM <rootHandleVar> WHERE PATH = "<A/B/C>" INTO <outHandleVar>
SELECT * FROM <rootHandleVar> WHERE PATH LIKE "<glob>" INTO <outHandleVar>
```

**Returns:**
- `""` if not found
- A new handle to the child object otherwise

**Fails if:**
- The value at the location is a scalar string (use `SELECT VALUE` instead)

**Examples:**
```cmake
SELECT * FROM myDict WHERE KEY = "settings" INTO settingsObj
SELECT * FROM myCollection WHERE INDEX = 0 INTO firstItem
SELECT * FROM root WHERE PATH = "config/database" INTO dbConfig
```

---

### `SELECT VALUE FROM ... INTO` (Scalar Retrieval)

Retrieves a scalar string value.

**Syntax:**
```cmake
# From table by column name
SELECT <column> FROM <tableHandleVar> WHERE NAME = <fieldName> INTO <outStrVar>

# From table by index
SELECT COLUMN <n> FROM <tableHandleVar> INTO <outStrVar>

# From dictionary by key
SELECT VALUE FROM <dictHandleVar> WHERE KEY = <key> INTO <outStrVar>

# By path
SELECT VALUE FROM <rootHandleVar> WHERE PATH = "<path>" INTO <outStrVar>
```

**Returns:**
- Field/column value, or
- `"NOTFOUND"` if missing/out of bounds

**Fails if:**
- The value is an object (use `SELECT *` instead)

**Examples:**
```cmake
SELECT name FROM employee WHERE NAME = "name" INTO empName
SELECT COLUMN 0 FROM employee INTO firstCol
SELECT VALUE FROM config WHERE KEY = "timeout" INTO timeoutVal
SELECT VALUE FROM root WHERE PATH = "app/version" INTO version
```

---

### `SELECT MATCHES FROM ... WHERE PATH LIKE`

Retrieves all matches for a glob pattern.

**Syntax:**
```cmake
SELECT MATCHES FROM <rootHandleVar> WHERE PATH LIKE "<globPath>" INTO <outHandleVar>
```

**Returns:**
- A **dictionary handle** where:
    - key = matched path string (`"A/B/C"`)
    - value = matched value (scalar or object)

**Examples:**
```cmake
SELECT MATCHES FROM config WHERE PATH LIKE "database/*" INTO dbSettings
SELECT VALUE FROM dbSettings WHERE KEY = "database/host" INTO host
```

---

### `INSERT INTO ... VALUES`

Inserts data into objects.

**Syntax:**
```cmake
# Bulk insert into table at index
INSERT INTO <tableHandleVar> VALUES (<v1>, <v2>, ...) [AT INDEX <n>]

# Insert into named column
INSERT INTO <tableHandleVar> (<column>) VALUES (<value>)

# Insert object into dictionary
INSERT INTO <dictHandleVar> (KEY <key>) VALUES OBJECT <childHandleVar> [REPLACE]

# Insert scalar into dictionary
INSERT INTO <dictHandleVar> (KEY <key>) VALUES STRING <value> [REPLACE]

# Append to collection
INSERT INTO <collectionHandleVar> VALUES RECORD <recordHandleVar>
INSERT INTO <collectionHandleVar> VALUES ARRAY <arrayHandleVar>
```

**Rules:**
- Tables: values must be strings
- Collections: enforce type constraints (RECORDS vs ARRAYS)
- Dictionary: `REPLACE` allows overwriting existing keys
- Inserting unnamed objects is forbidden

**Examples:**
```cmake
INSERT INTO employee VALUES ("John", "30", "Eng") AT INDEX 0
INSERT INTO employee (name) VALUES ("Jane")
INSERT INTO config (KEY "timeout") VALUES STRING "5000" REPLACE
INSERT INTO employees VALUES RECORD newEmp
```

---

### `UPDATE ... SET ... WHERE`

Updates existing values in a table.

**Syntax:**
```cmake
UPDATE <tableHandleVar> SET <column> = <value> WHERE NAME = <fieldName>
```

**Rules:**
- Only for named tables
- Field must exist

**Examples:**
```cmake
UPDATE employee SET age = "31" WHERE NAME = "age"
```

---

### `DELETE FROM ... WHERE`

Removes elements from collections.

**Syntax:**
```cmake
DELETE FROM <collectionHandleVar> WHERE NAME = <childName> 
    [REPLACE WITH <newHandleVar>] 
    [STATUS <resultVar>]
```

**Returns via STATUS:**
- `"REMOVED"` - element was removed
- `"REPLACED"` - element was replaced
- `"NOT_FOUND"` - no matching element

**Rules:**
- Collection must be named
- With `REPLACE WITH`: replacement must match collection type
- Replacement object must be named
- No duplicate names allowed

**Examples:**
```cmake
DELETE FROM employees WHERE NAME = "old-employee" STATUS result
DELETE FROM employees WHERE NAME = "temp" REPLACE WITH newEmp STATUS result
```

---

## Metadata & Inspection

### `DESCRIBE`

Returns the kind/type of an object.

**Syntax:**
```cmake
DESCRIBE <handleVar> [INTO <outKindVar>]
```

**Returns:**
- `"RECORD"`, `"ARRAY_RECORDS"`, `"ARRAY_ARRAYS"`, or `"DICT"`

**Examples:**
```cmake
DESCRIBE myObj INTO objKind
if(objKind STREQUAL "RECORD")
    # Handle record
endif()
```

---

### `SHOW COLUMNS FROM`

Returns column/field names from a named table.

**Syntax:**
```cmake
SHOW COLUMNS FROM <tableHandleVar> INTO <outListVar>
```

**Examples:**
```cmake
SHOW COLUMNS FROM employee INTO columns
# columns = "name;age;department"
```

---

### `SHOW KEYS FROM`

Returns all keys from a dictionary.

**Syntax:**
```cmake
SHOW KEYS FROM <dictHandleVar> INTO <outListVar>
```

**Examples:**
```cmake
SHOW KEYS FROM config INTO allKeys
foreach(key IN LISTS allKeys)
    # Process each key
endforeach()
```

---

### `SHOW NAME FROM`

Returns the object's name/label.

**Syntax:**
```cmake
SHOW NAME FROM <handleVar> INTO <outStrVar>
```

**Examples:**
```cmake
SHOW NAME FROM employee INTO empName
```

---

## Iteration

### `SELECT HANDLES FROM`

Returns a list of child object handles.

**Syntax:**
```cmake
SELECT HANDLES FROM <handleVar> INTO <outListVar>
```

**Rules:**
- For dictionaries: returns handles for object-valued entries only (scalars skipped)
- For collections: returns all element handles

**Examples:**
```cmake
SELECT HANDLES FROM myDict INTO childHandles
foreach(child IN LISTS childHandles)
    DESCRIBE ${child} INTO childKind
endforeach()
```

---

### `FOREACH ROW IN ... CALL`

Iterates over children with a callback.

**Syntax:**
```cmake
FOREACH ROW IN <handleVar> CALL <function>
```

**Examples:**
```cmake
function(process_employee emp)
    SELECT name FROM ${emp} WHERE NAME = "name" INTO name
    message("Employee: ${name}")
endfunction()

FOREACH ROW IN employees CALL process_employee
```

---

## Path Query Syntax

### Glob Patterns

Path queries use `/`-separated segments with wildcards:

- `*` - matches exactly one segment
- `**` - matches zero or more segments
- literals match exactly

**Examples:**
```cmake
# Match single level
SELECT * FROM root WHERE PATH LIKE "config/*/enabled" INTO result

# Match any depth
SELECT MATCHES FROM root WHERE PATH LIKE "users/**/email" INTO emails

# Exact match
SELECT VALUE FROM root WHERE PATH = "app/version" INTO ver
```

---

## Migration from Original API

### Command Mapping

| Original | SQL Equivalent |
|----------|---------------|
| `object(CREATE h KIND RECORD LABEL "x")` | `CREATE TABLE h AS "x"` |
| `object(CREATE h KIND DICT LABEL "x")` | `CREATE DICTIONARY h AS "x"` |
| `object(CREATE h KIND ARRAY LABEL "x" TYPE RECORDS)` | `CREATE COLLECTION h AS "x" OF RECORDS` |
| `object(RENAME h "newname")` | `ALTER TABLE h RENAME TO "newname"` |
| `object(SET h INDEX 0 "a" "b")` | `INSERT INTO h VALUES ("a", "b") AT INDEX 0` |
| `object(SET h NAME EQUAL "col" VALUE "v")` | `UPDATE h SET col = "v" WHERE NAME = "col"` |
| `object(GET out FROM dict NAME EQUAL "k")` | `SELECT * FROM dict WHERE KEY = "k" INTO out` |
| `object(STRING out FROM dict NAME EQUAL "k")` | `SELECT VALUE FROM dict WHERE KEY = "k" INTO out` |
| `object(FIELD_NAMES rec NAMES "a;b;c")` | `ALTER TABLE rec ADD COLUMNS (a, b, c)` |
| `object(APPEND arr RECORD rec)` | `INSERT INTO arr VALUES RECORD rec` |
| `object(REMOVE ARRAY FROM arr NAME EQUAL "x")` | `DELETE FROM arr WHERE NAME = "x"` |
| `object(KIND h out)` | `DESCRIBE h INTO out` |
| `object(KEYS dict out)` | `SHOW KEYS FROM dict INTO out` |
| `object(NAME out FROM h)` | `SHOW NAME FROM h INTO out` |

---

## SQL-Style Examples

### Creating and Populating a Table

```cmake
# Create employee record
CREATE TABLE employee AS "john_doe" COLUMNS (name, age, department, salary)

# Insert values
INSERT INTO employee (name) VALUES ("John Doe")
INSERT INTO employee (age) VALUES ("35")
UPDATE employee SET department = "Engineering" WHERE NAME = "department"
UPDATE employee SET salary = "95000" WHERE NAME = "salary"

# Query values
SELECT name FROM employee WHERE NAME = "name" INTO empName
SELECT age FROM employee WHERE NAME = "age" INTO empAge

message("Employee: ${empName}, Age: ${empAge}")
```

---

### Building a Configuration Dictionary

```cmake
# Create config dictionary
CREATE DICTIONARY config AS "app_config"

# Add scalar values
INSERT INTO config (KEY "version") VALUES STRING "1.0.0"
INSERT INTO config (KEY "timeout") VALUES STRING "5000"

# Add nested object
CREATE DICTIONARY dbConfig AS "database"
INSERT INTO dbConfig (KEY "host") VALUES STRING "localhost"
INSERT INTO dbConfig (KEY "port") VALUES STRING "5432"

INSERT INTO config (KEY "database") VALUES OBJECT dbConfig

# Query nested value
SELECT VALUE FROM config WHERE PATH = "database/host" INTO dbHost
message("Database host: ${dbHost}")
```

---

### Managing Collections

```cmake
# Create employee collection
CREATE COLLECTION employees AS "company_staff" OF RECORDS

# Add employees
CREATE TABLE emp1 AS "alice" COLUMNS (name, role)
INSERT INTO emp1 (name) VALUES ("Alice")
INSERT INTO emp1 (role) VALUES ("Developer")
INSERT INTO employees VALUES RECORD emp1

CREATE TABLE emp2 AS "bob" COLUMNS (name, role)
INSERT INTO emp2 (name) VALUES ("Bob")
INSERT INTO emp2 (role) VALUES ("Manager")
INSERT INTO employees VALUES RECORD emp2

# Iterate
FOREACH ROW IN employees CALL print_employee_info

# Remove
DELETE FROM employees WHERE NAME = "alice" STATUS result
if(result STREQUAL "REMOVED")
    message("Alice removed from staff")
endif()
```

---

### Complex Queries

```cmake
# Find all database-related settings
SELECT MATCHES FROM config WHERE PATH LIKE "database/**" INTO dbMatches

# Get all keys
SHOW KEYS FROM dbMatches INTO matchedPaths
foreach(path IN LISTS matchedPaths)
    SELECT VALUE FROM dbMatches WHERE KEY = "${path}" INTO value
    message("${path} = ${value}")
endforeach()
```

---

## Implementation Notes

The SQL-style API is implemented as a wrapper layer over the original `object(...)` API. All the same invariants and storage mechanisms apply:

- Handles are still opaque tokens
- Objects stored in GLOBAL properties
- Same blob encodings (record/array/dict)
- Same mutation rules for unnamed objects

The SQL syntax provides a more familiar and expressive interface while maintaining full compatibility with the underlying system.
