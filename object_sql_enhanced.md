# HoffSoft CMake SQL Object API (`cmake/object_sql.cmake`)

This document describes the **SQL-like API** for HoffSoft's object management system.

It provides a familiar SQL syntax for managing structured data in CMake, with:

- **SQL-style commands** (CREATE, SELECT, INSERT, UPDATE, DELETE, etc.)
- **Opaque auto-generated handles** (tokens like `HS_HNDL_123`)
- Object blobs stored in a **GLOBAL property store**
- **TABLE** abstraction that manages collections of rows internally
- Strong typing and validation

---

## Core Concepts

### Object Types

- **TABLE**: A collection of rows (records) with defined columns. Behind the scenes, this is a COLLECTION of RECORDS, but the API presents it as a unified table structure.
- **COLLECTION**: A container holding multiple TABLEs or other COLLECTIONs (for nested structures).
- **DICTIONARY**: Key-value store that can hold scalar strings or object handles.
- **VIEW**: Read-only composite object created from multiple source objects.

### Handles vs Labels

- A **handle** is an opaque token (string) returned by `CREATE(...)`.
- A **label** (aka "name") is the human-facing name stored inside the object.
- All objects created without an explicit label start as `"<unnamed>"` and must be renamed before mutation.

### Not-Found Conventions

- **Handle-returning operations** (SELECT returning objects):
  - Return `""` when not found
  - Test with: `if(NOT resultHandle) ...`
- **String-returning operations** (SELECT VALUE):
  - Return literal string `"NOTFOUND"` when not found
  - Test with: `if(resultVar STREQUAL "NOTFOUND") ...`

---

## Quick Command Reference

### Schema Definition (DDL)

```cmake
CREATE(TABLE tableHandle LABEL "users" COLUMNS "id;name;email;status")
CREATE(TABLE tableHandle LABEL "users" COLUMNS "id;name;email;status" FIXED)
CREATE(COLLECTION collHandle LABEL "datasets" TYPE TABLES)
CREATE(COLLECTION collHandle LABEL "nested" TYPE COLLECTIONS)
CREATE(DICTIONARY dictHandle LABEL "config")
CREATE(VIEW viewHandle LABEL "combined" FROM handle1 handle2 handle3)
```

### Data Manipulation (DML)

```cmake
INSERT(INTO tableHandle VALUES "1" "Alice" "alice@example.com" "active")
INSERT(INTO tableHandle ROW recHandle)

UPDATE(tableHandle SET COLUMN "status" = "inactive" WHERE ROWID = 5)
UPDATE(tableHandle SET COLUMN "status" = "inactive" WHERE COLUMN "name" = "Alice")
UPDATE(tableHandle SET INDEX 2 = "new_value" WHERE ROWID = 5)

DELETE(FROM tableHandle WHERE ROWID = 5)
DELETE(FROM tableHandle WHERE COLUMN "status" = "inactive")
```

### Queries (DQL)

```cmake
# Select single value
SELECT(VALUE FROM tableHandle WHERE ROWID = 1 AND COLUMN = "name" INTO nameVar)
SELECT(VALUE FROM tableHandle WHERE ROWID = 1 AND INDEX = 2 INTO valueVar)

# Pattern matching - returns string if one match, DICT handle if multiple matches
SELECT(VALUE FROM tableHandle WHERE VALUE LIKE "https.*" INTO gitRepo)

# Select row (returns TABLE handle with single row)
SELECT(ROW FROM tableHandle WHERE ROWID = 5 INTO rowHandle)

# Select column (returns TABLE handle with single column, all rows)
SELECT(COLUMN FROM tableHandle WHERE COLUMN = "name" INTO columnHandle)

# Complex WHERE clause - returns TABLE handle with matching rows
SELECT(* FROM tableHandle WHERE COLUMN "status" = "active" INTO resultHandle)
SELECT(* FROM tableHandle WHERE COLUMN "status" = "active" AND COLUMN "role" = "admin" INTO resultHandle)
SELECT(* FROM tableHandle WHERE COLUMN "url" LIKE "https://git.*" INTO resultHandle)

# Count operations
SELECT(COUNT FROM tableHandle INTO countVar)
# Returns: row count for TABLE, element count for COLLECTION, key count for DICTIONARY, 1 for scalar string
```

### Schema Operations

```cmake
DESCRIBE(tableHandle INTO schemaInfo)
# Returns: "COLUMNS: id;name;email;status | ROWS: 42 | FIXED: YES/NO"

ALTER(TABLE tableHandle RENAME TO "new_name")
ALTER(TABLE tableHandle ADD COLUMN "created_date")  # Appends to existing columns
```

### Dictionary Operations

```cmake
# Set values
SET(dictHandle KEY "database_url" VALUE "postgres://...")
SET(dictHandle KEY "table" HANDLE tableHandle REPLACE)

# Get values
SELECT(VALUE FROM dictHandle WHERE KEY = "database_url" INTO urlVar)
SELECT(HANDLE FROM dictHandle WHERE KEY = "table" INTO tblHandle)

# Pattern matching keys
SELECT(KEYS FROM dictHandle WHERE KEY LIKE "db_.*" INTO keyListVar)

# All keys
SELECT(KEYS FROM dictHandle INTO allKeysVar)
```

### Collection Operations

```cmake
# Add to collection
INSERT(INTO collHandle TABLE tableHandle)
INSERT(INTO collHandle COLLECTION nestedCollHandle)

# Remove from collection
DELETE(FROM collHandle WHERE NAME = "old_table")
DELETE(FROM collHandle WHERE NAME = "old_table" REPLACE WITH newTableHandle)

# Get from collection
SELECT(HANDLE FROM collHandle WHERE NAME = "users" INTO userTableHandle)
SELECT(HANDLE FROM collHandle WHERE INDEX = 0 INTO firstHandle)
```

### Metadata & Introspection

```cmake
TYPEOF(handleVar INTO typeVar)
# Returns: "TABLE", "COLLECTION", "DICTIONARY", "VIEW", or "STRING" (if not a handle)

ASSERT(handleVar IS TABLE)
ASSERT(handleVar IS TABLE COLLECTION DICTIONARY)  # Any of these types

LABEL(OF handleVar INTO labelVar)
# Returns the object's label/name

DUMP(handleVar INTO stringVar)
# Returns pretty-printed representation of entire object
```

### Iteration

```cmake
FOREACH(ROW IN tableHandle CALL myFunction)
# Calls myFunction(rowHandle) for each row

FOREACH(HANDLE IN collHandle CALL myFunction)
# Calls myFunction(elementHandle) for each element

FOREACH(KEY IN dictHandle CALL myFunction)
# Calls myFunction(key, valueOrHandle) for each entry
```

---

## Detailed Command Reference

## CREATE

### CREATE TABLE

**Syntax:**
```cmake
CREATE(TABLE outHandleVar LABEL "tableName" COLUMNS "col1;col2;col3" [FIXED])
```

**Semantics:**
- Creates a new table with the specified columns
- Initial ROWID starts at 1
- If `FIXED` is specified, the column count cannot be changed later
- Columns can be accessed by name (COLUMN "name") or by index (INDEX 0)
- Behind the scenes: Creates a COLLECTION containing RECORD objects (rows)

**Examples:**
```cmake
CREATE(TABLE users LABEL "users" COLUMNS "id;name;email")
CREATE(TABLE config LABEL "config" COLUMNS "key;value" FIXED)
```

---

### CREATE COLLECTION

**Syntax:**
```cmake
CREATE(COLLECTION outHandleVar LABEL "collName" TYPE TABLES|COLLECTIONS)
```

**Semantics:**
- Creates an empty collection
- `TYPE TABLES`: Can only contain TABLE handles
- `TYPE COLLECTIONS`: Can only contain COLLECTION handles (for nested hierarchies)
- Type enforcement prevents mixing different object types

**Examples:**
```cmake
CREATE(COLLECTION datasets LABEL "all_datasets" TYPE TABLES)
CREATE(COLLECTION hierarchy LABEL "nested_structure" TYPE COLLECTIONS)
```

---

### CREATE DICTIONARY

**Syntax:**
```cmake
CREATE(DICTIONARY outHandleVar LABEL "dictName")
```

**Semantics:**
- Creates an empty key-value dictionary
- Keys are always strings
- Values can be:
  - Scalar strings (retrieved with `SELECT VALUE`)
  - Object handles (retrieved with `SELECT HANDLE`)

**Examples:**
```cmake
CREATE(DICTIONARY config LABEL "app_config")
CREATE(DICTIONARY registry LABEL "table_registry")
```

---

### CREATE VIEW

**Syntax:**
```cmake
CREATE(VIEW outHandleVar LABEL "viewName" FROM handle1 [handle2 [handle3 ...]])
```

**Semantics:**
- Creates a read-only composite view from multiple source objects
- View presents unified interface to underlying sources
- Cannot be mutated (INSERT, UPDATE, DELETE forbidden)
- Changes to source objects are visible through the view

**Examples:**
```cmake
CREATE(VIEW allUsers LABEL "all_users" FROM usersTable adminTable guestTable)
```

---

## INSERT

### INSERT INTO TABLE

**Syntax:**
```cmake
INSERT(INTO tableHandle VALUES "val1" "val2" "val3" ...)
INSERT(INTO tableHandle ROW recordHandle)
```

**Semantics:**
- Adds a new row to the table
- VALUES form: Values must match column count exactly
- ROW form: Record must have same schema as table
- Auto-assigns next ROWID (incremental)
- Table must not be `"<unnamed>"` (rename first)

**Examples:**
```cmake
INSERT(INTO users VALUES "101" "Bob" "bob@example.com")
INSERT(INTO users VALUES "102" "Carol" "carol@example.com")
```

**Returns:**
- Nothing (modifies table in place)

---

### INSERT INTO COLLECTION

**Syntax:**
```cmake
INSERT(INTO collHandle TABLE tableHandle)
INSERT(INTO collHandle COLLECTION nestedCollHandle)
```

**Semantics:**
- Adds object to collection
- Type must match collection's TYPE declaration
- Object being inserted must not be `"<unnamed>"` (rename first)
- Duplicate names at same level → FATAL_ERROR

**Examples:**
```cmake
INSERT(INTO datasets TABLE users)
INSERT(INTO datasets TABLE products)
```

---

## SELECT

### SELECT VALUE (single cell)

**Syntax:**
```cmake
SELECT(VALUE FROM tableHandle WHERE ROWID = <n> AND COLUMN = "colName" INTO outVar)
SELECT(VALUE FROM tableHandle WHERE ROWID = <n> AND INDEX = <i> INTO outVar)
```

**Semantics:**
- Returns a single cell value from the table
- COLUMN: Access by column name
- INDEX: Access by column position (0-based)
- Returns `"NOTFOUND"` if row doesn't exist or column doesn't exist

**Examples:**
```cmake
SELECT(VALUE FROM users WHERE ROWID = 1 AND COLUMN = "name" INTO userName)
SELECT(VALUE FROM users WHERE ROWID = 5 AND INDEX = 2 INTO emailValue)

if(userName STREQUAL "NOTFOUND")
    message("User not found")
endif()
```

---

### SELECT VALUE (pattern search)

**Syntax:**
```cmake
SELECT(VALUE FROM tableHandle WHERE VALUE LIKE "pattern" INTO outVar)
```

**Semantics:**
- Searches all cells in all rows for values matching the pattern
- Pattern is a CMake regex
- **Single match**: Returns the matched string value
- **Multiple matches**: Returns a DICTIONARY handle with:
  - KEY = "ROWID:<rowid>:COLUMN:<colname>" or "ROWID:<rowid>:INDEX:<idx>"
  - VALUE = the matched string
- **No matches**: Returns `"NOTFOUND"`

**Examples:**
```cmake
# Find git repository URL
SELECT(VALUE FROM config WHERE VALUE LIKE "https://git.*" INTO gitRepo)

# If multiple matches:
if(NOT gitRepo STREQUAL "NOTFOUND")
    TYPEOF(gitRepo INTO repoType)
    if(repoType STREQUAL "DICTIONARY")
        # Multiple matches found
        SELECT(KEYS FROM gitRepo INTO matchKeys)
        foreach(key IN LISTS matchKeys)
            SELECT(VALUE FROM gitRepo WHERE KEY = "${key}" INTO matchedValue)
            message("Found: ${key} = ${matchedValue}")
        endforeach()
    else()
        # Single match
        message("Found: ${gitRepo}")
    endif()
endif()
```

---

### SELECT ROW

**Syntax:**
```cmake
SELECT(ROW FROM tableHandle WHERE ROWID = <n> INTO outHandleVar)
```

**Semantics:**
- Returns a TABLE handle containing a single row (copy of the specified row)
- The returned table has same schema as source
- Returns `""` if ROWID doesn't exist

**Examples:**
```cmake
SELECT(ROW FROM users WHERE ROWID = 5 INTO userRow)
if(userRow)
    SELECT(VALUE FROM userRow WHERE ROWID = 1 AND COLUMN = "name" INTO name)
    message("User name: ${name}")
endif()
```

---

### SELECT COLUMN

**Syntax:**
```cmake
SELECT(COLUMN FROM tableHandle WHERE COLUMN = "colName" INTO outHandleVar)
SELECT(COLUMN FROM tableHandle WHERE INDEX = <i> INTO outHandleVar)
```

**Semantics:**
- Returns a TABLE handle containing a single column from all rows
- The returned table has one column with the same name as source
- Returns `""` if column doesn't exist

**Examples:**
```cmake
SELECT(COLUMN FROM users WHERE COLUMN = "email" INTO emailColumn)
SELECT(COLUMN FROM users WHERE INDEX = 2 INTO thirdColumn)
```

---

### SELECT * (complex WHERE)

**Syntax:**
```cmake
SELECT(* FROM tableHandle WHERE COLUMN "colName" = "value" INTO outHandleVar)
SELECT(* FROM tableHandle WHERE COLUMN "colName" LIKE "pattern" INTO outHandleVar)
SELECT(* FROM tableHandle WHERE COLUMN "col1" = "val1" AND COLUMN "col2" = "val2" INTO outHandleVar)
SELECT(* FROM tableHandle WHERE COLUMN "col1" = "val1" AND COLUMN "col2" LIKE "pattern" INTO outHandleVar)
```

**Semantics:**
- Returns a TABLE handle containing all rows that match the WHERE clause
- WHERE clause can have multiple conditions joined with AND
- Each condition can use `=` (exact match) or `LIKE` (regex pattern)
- Returned table has same schema as source
- Returns `""` if no rows match

**Examples:**
```cmake
# Find all active users
SELECT(* FROM users WHERE COLUMN "status" = "active" INTO activeUsers)

# Find all git URLs
SELECT(* FROM repos WHERE COLUMN "url" LIKE "https://git.*" INTO gitRepos)

# Complex condition
SELECT(* FROM users 
    WHERE COLUMN "status" = "active" 
    AND COLUMN "role" = "admin" 
    INTO adminUsers)
```

---

### SELECT COUNT

**Syntax:**
```cmake
SELECT(COUNT FROM handleVar INTO outCountVar)
```

**Semantics:**
- Returns the count of elements/rows/keys depending on object type
- **TABLE**: Returns row count
- **COLLECTION**: Returns element count
- **DICTIONARY**: Returns key count
- **VIEW**: Returns combined count from all sources
- **Scalar string** (not a handle): Returns `1`

**Examples:**
```cmake
SELECT(COUNT FROM users INTO userCount)
message("Total users: ${userCount}")

# Check if result is scalar or handle
SELECT(VALUE FROM config WHERE VALUE LIKE "https.*" INTO result)
SELECT(COUNT FROM result INTO resultCount)
if(resultCount EQUAL 1)
    # Single match (scalar string)
    message("Found URL: ${result}")
else()
    # Multiple matches (dictionary)
    message("Found ${resultCount} matching URLs")
endif()
```

---

### SELECT FROM DICTIONARY

**Syntax:**
```cmake
SELECT(VALUE FROM dictHandle WHERE KEY = "keyName" INTO outVar)
SELECT(HANDLE FROM dictHandle WHERE KEY = "keyName" INTO outHandleVar)
SELECT(KEYS FROM dictHandle WHERE KEY LIKE "pattern" INTO outListVar)
SELECT(KEYS FROM dictHandle INTO outListVar)
```

**Semantics:**
- `VALUE`: Retrieves scalar string value, returns `"NOTFOUND"` if not found or if value is a handle
- `HANDLE`: Retrieves object handle, returns `""` if not found or if value is a scalar
- `KEYS ... LIKE`: Returns list of keys matching pattern
- `KEYS` (no WHERE): Returns all keys

**Examples:**
```cmake
SELECT(VALUE FROM config WHERE KEY = "database_url" INTO dbUrl)
SELECT(HANDLE FROM registry WHERE KEY = "users_table" INTO usersHandle)
SELECT(KEYS FROM config WHERE KEY LIKE "db_.*" INTO dbKeys)
SELECT(KEYS FROM config INTO allKeys)
```

---

### SELECT FROM COLLECTION

**Syntax:**
```cmake
SELECT(HANDLE FROM collHandle WHERE NAME = "objectName" INTO outHandleVar)
SELECT(HANDLE FROM collHandle WHERE INDEX = <n> INTO outHandleVar)
```

**Semantics:**
- NAME: Searches for element by label/name
- INDEX: Gets element by position (0-based)
- Returns `""` if not found

**Examples:**
```cmake
SELECT(HANDLE FROM datasets WHERE NAME = "users" INTO usersTable)
SELECT(HANDLE FROM datasets WHERE INDEX = 0 INTO firstTable)
```

---

## UPDATE

### UPDATE TABLE

**Syntax:**
```cmake
UPDATE(tableHandle SET COLUMN "colName" = "newValue" WHERE ROWID = <n>)
UPDATE(tableHandle SET INDEX <i> = "newValue" WHERE ROWID = <n>)
UPDATE(tableHandle SET COLUMN "colName" = "newValue" WHERE COLUMN "searchCol" = "searchValue")
UPDATE(tableHandle SET INDEX <i> = "newValue" WHERE COLUMN "searchCol" LIKE "pattern")
```

**Semantics:**
- Updates cell(s) in the table
- WHERE ROWID: Updates specific row
- WHERE COLUMN: Updates all rows where condition matches
- Table must not be `"<unnamed>"`
- Column/index must exist (for FIXED tables)

**Examples:**
```cmake
# Update specific row
UPDATE(users SET COLUMN "status" = "inactive" WHERE ROWID = 5)

# Update all matching rows
UPDATE(users SET COLUMN "status" = "archived" WHERE COLUMN "last_login" LIKE "2020-.*")
```

---

## DELETE

### DELETE FROM TABLE

**Syntax:**
```cmake
DELETE(FROM tableHandle WHERE ROWID = <n>)
DELETE(FROM tableHandle WHERE COLUMN "colName" = "value")
DELETE(FROM tableHandle WHERE COLUMN "colName" LIKE "pattern")
```

**Semantics:**
- Removes row(s) from table
- WHERE ROWID: Deletes specific row
- WHERE COLUMN: Deletes all matching rows
- ROWIDs are NOT reassigned after deletion (gaps may exist)
- Returns deleted row count in optional STATUS variable

**Examples:**
```cmake
DELETE(FROM users WHERE ROWID = 5)
DELETE(FROM users WHERE COLUMN "status" = "inactive")
```

---

### DELETE FROM COLLECTION

**Syntax:**
```cmake
DELETE(FROM collHandle WHERE NAME = "objectName" [STATUS outStatusVar])
DELETE(FROM collHandle WHERE NAME = "objectName" REPLACE WITH newHandle [STATUS outStatusVar])
```

**Semantics:**
- Removes element from collection by name
- REPLACE WITH: Swaps out old element with new one
- STATUS returns: "REMOVED", "REPLACED", or "NOT_FOUND"
- Collection must not be `"<unnamed>"`
- Replacement object must not be `"<unnamed>"`

**Examples:**
```cmake
DELETE(FROM datasets WHERE NAME = "old_users" STATUS result)
DELETE(FROM datasets WHERE NAME = "users" REPLACE WITH newUsersTable STATUS result)
```

---

## SET (Dictionary)

**Syntax:**
```cmake
SET(dictHandle KEY "keyName" VALUE "scalarValue" [REPLACE])
SET(dictHandle KEY "keyName" HANDLE objectHandle [REPLACE])
```

**Semantics:**
- Sets key-value pair in dictionary
- Without REPLACE: Error if key exists
- With REPLACE: Overwrites existing value
- Object being stored must not be `"<unnamed>"`

**Examples:**
```cmake
SET(config KEY "app_name" VALUE "MyApp")
SET(config KEY "app_name" VALUE "MyApp v2" REPLACE)
SET(registry KEY "users" HANDLE usersTable)
```

---

## ALTER TABLE

**Syntax:**
```cmake
ALTER(TABLE tableHandle RENAME TO "newName")
ALTER(TABLE tableHandle ADD COLUMN "newColumnName")
```

**Semantics:**
- RENAME TO: Changes table's label
- ADD COLUMN: Appends new column to schema (not allowed on FIXED tables)
- New column cells in existing rows will be empty (return `"NOTFOUND"`)

**Examples:**
```cmake
ALTER(TABLE users RENAME TO "app_users")
ALTER(TABLE users ADD COLUMN "created_date")
```

---

## DESCRIBE

**Syntax:**
```cmake
DESCRIBE(tableHandle INTO outStringVar)
```

**Semantics:**
- Returns human-readable schema information
- Format: "COLUMNS: col1;col2;col3 | ROWS: <count> | FIXED: YES/NO"

**Examples:**
```cmake
DESCRIBE(users INTO schema)
message("${schema}")
# Output: "COLUMNS: id;name;email;status | ROWS: 42 | FIXED: NO"
```

---

## TYPEOF

**Syntax:**
```cmake
TYPEOF(handleVar INTO outTypeVar)
```

**Semantics:**
- Returns object type: "TABLE", "COLLECTION", "DICTIONARY", "VIEW"
- If handleVar is not a valid handle, returns "STRING"

**Examples:**
```cmake
TYPEOF(users INTO type)
if(type STREQUAL "TABLE")
    message("It's a table!")
endif()
```

---

## ASSERT

**Syntax:**
```cmake
ASSERT(handleVar IS expectedType [expectedType2 ...])
```

**Semantics:**
- Validates that handle is one of the expected types
- FATAL_ERROR if type doesn't match

**Examples:**
```cmake
ASSERT(users IS TABLE)
ASSERT(result IS TABLE DICTIONARY)  # Either type is acceptable
```

---

## LABEL

**Syntax:**
```cmake
LABEL(OF handleVar INTO outLabelVar)
```

**Semantics:**
- Returns the object's label/name
- Returns `"<unnamed>"` if object has no label

**Examples:**
```cmake
LABEL(OF users INTO name)
message("Table name: ${name}")
```

---

## DUMP

**Syntax:**
```cmake
DUMP(handleVar INTO outStringVar)
```

**Semantics:**
- Returns pretty-printed representation of entire object
- Recursively dumps nested structures
- Useful for debugging

**Examples:**
```cmake
DUMP(users INTO debug)
message("${debug}")
```

---

## FOREACH

**Syntax:**
```cmake
FOREACH(ROW IN tableHandle CALL functionName)
FOREACH(HANDLE IN collHandle CALL functionName)
FOREACH(KEY IN dictHandle CALL functionName)
```

**Semantics:**
- Iterates over elements and calls function for each
- ROW: Function receives (rowHandle) - each row as a single-row table
- HANDLE: Function receives (elementHandle)
- KEY: Function receives (key, valueOrHandle)

**Examples:**
```cmake
function(print_user rowHandle)
    SELECT(VALUE FROM rowHandle WHERE ROWID = 1 AND COLUMN = "name" INTO name)
    message("User: ${name}")
endfunction()

FOREACH(ROW IN users CALL print_user)
```

---

## Path Traversal (Future Extension)

**Note:** Path traversal from the original API may be added in future versions:

```cmake
SELECT(VALUE FROM rootHandle PATH "/config/database/url" INTO dbUrl)
SELECT(HANDLE FROM rootHandle PATH "/datasets/*" INTO matches)
```

This would allow hierarchical navigation through nested DICTIONARY and COLLECTION structures.

---

## Migration from Old API

### Old API → New SQL API

| Old Command | New SQL Command |
|-------------|-----------------|
| `object(CREATE h KIND RECORD LABEL "x")` | `CREATE(TABLE h LABEL "x" COLUMNS "col1;col2")` |
| `object(CREATE h KIND ARRAY LABEL "x" TYPE RECORDS)` | `CREATE(COLLECTION h LABEL "x" TYPE TABLES)` |
| `object(CREATE h KIND DICT LABEL "x")` | `CREATE(DICTIONARY h LABEL "x")` |
| `object(SET rec INDEX 0 "val")` | `UPDATE(tbl SET INDEX 0 = "val" WHERE ROWID = 1)` |
| `object(STRING s FROM rec INDEX 0)` | `SELECT(VALUE FROM tbl WHERE ROWID = 1 AND INDEX = 0 INTO s)` |
| `object(APPEND arr RECORD rec)` | `INSERT(INTO coll TABLE tbl)` |
| `object(GET h FROM dict NAME EQUAL "k")` | `SELECT(HANDLE FROM dict WHERE KEY = "k" INTO h)` |
| `object(RENAME h "newName")` | `ALTER(TABLE h RENAME TO "newName")` |

### Key Differences

1. **TABLE replaces RECORD** but has richer semantics (multi-row support)
2. **All tables have ROWID** (auto-incrementing)
3. **No more positional records** without columns - all tables have schema
4. **WHERE clauses** replace path navigation for most operations
5. **Complete break** from old API - no backward compatibility

---

## Design Principles

1. **SQL Familiarity**: Use SQL keywords and patterns where possible
2. **CMake Native**: Still uses CMake syntax (parentheses, not semicolons)
3. **Type Safety**: Strong typing with runtime validation
4. **Explicit Intent**: Commands clearly express what operation is happening
5. **Handle-Based**: All objects accessed through opaque handles
6. **No Unnamed Mutations**: Objects must be labeled before modification

---

## Implementation Notes

- All handles are stored in GLOBAL properties (survives function scope)
- TABLE internally = COLLECTION of RECORDs with ROWID management
- ROWID gaps allowed after DELETE (not reassigned)
- Pattern matching uses CMake regex syntax
- WHERE clauses evaluated left-to-right (short-circuit AND)

---

## Examples

### Complete Workflow

```cmake
# Create a table
CREATE(TABLE users LABEL "users" COLUMNS "id;name;email;status")

# Insert data
INSERT(INTO users VALUES "1" "Alice" "alice@example.com" "active")
INSERT(INTO users VALUES "2" "Bob" "bob@example.com" "active")
INSERT(INTO users VALUES "3" "Carol" "carol@example.com" "inactive")

# Query single value
SELECT(VALUE FROM users WHERE ROWID = 1 AND COLUMN = "name" INTO name)
message("User 1: ${name}")

# Find pattern
SELECT(VALUE FROM users WHERE VALUE LIKE ".*@example.com" INTO emails)
TYPEOF(emails INTO emailType)
if(emailType STREQUAL "DICTIONARY")
    SELECT(COUNT FROM emails INTO emailCount)
    message("Found ${emailCount} email addresses")
endif()

# Find active users
SELECT(* FROM users WHERE COLUMN "status" = "active" INTO activeUsers)
SELECT(COUNT FROM activeUsers INTO activeCount)
message("Active users: ${activeCount}")

# Update
UPDATE(users SET COLUMN "status" = "archived" WHERE COLUMN "name" = "Carol")

# Delete
DELETE(FROM users WHERE ROWID = 2)

# Iterate
function(print_user_row rowHandle)
    SELECT(VALUE FROM rowHandle WHERE ROWID = 1 AND COLUMN = "name" INTO name)
    SELECT(VALUE FROM rowHandle WHERE ROWID = 1 AND COLUMN = "email" INTO email)
    message("${name} <${email}>")
endfunction()

FOREACH(ROW IN users CALL print_user_row)
```

### Working with Collections

```cmake
# Create tables
CREATE(TABLE users LABEL "users" COLUMNS "id;name")
CREATE(TABLE products LABEL "products" COLUMNS "sku;name;price")

# Create collection
CREATE(COLLECTION db LABEL "database" TYPE TABLES)

# Add tables to collection
INSERT(INTO db TABLE users)
INSERT(INTO db TABLE products)

# Retrieve table from collection
SELECT(HANDLE FROM db WHERE NAME = "users" INTO usersHandle)

# Work with retrieved table
INSERT(INTO usersHandle VALUES "1" "Alice")
```

### Configuration Dictionary

```cmake
# Create config
CREATE(DICTIONARY config LABEL "app_config")

# Set values
SET(config KEY "app_name" VALUE "MyApp")
SET(config KEY "version" VALUE "1.0.0")
SET(config KEY "database_url" VALUE "postgres://localhost/mydb")

# Create table and store in config
CREATE(TABLE schema LABEL "db_schema" COLUMNS "table;columns")
SET(config KEY "schema" HANDLE schema)

# Retrieve
SELECT(VALUE FROM config WHERE KEY = "app_name" INTO appName)
SELECT(HANDLE FROM config WHERE KEY = "schema" INTO schemaHandle)

# Find all database-related keys
SELECT(KEYS FROM config WHERE KEY LIKE "database.*" INTO dbKeys)
foreach(key IN LISTS dbKeys)
    SELECT(VALUE FROM config WHERE KEY = "${key}" INTO value)
    message("${key} = ${value}")
endforeach()
```

---

## Error Handling

All commands follow strict error handling:

- **FATAL_ERROR** on:
  - Type mismatches
  - Operations on `"<unnamed>"` objects (except RENAME)
  - Invalid ROWID/column references on FIXED tables
  - Duplicate names in collections
  - Missing required parameters

- **Graceful returns** on:
  - Not found: Return `""` for handles, `"NOTFOUND"` for values
  - Empty results: Return `""` for empty result sets

---

## Future Extensions

Possible additions:

1. **JOIN operations**: Combine tables based on common columns
2. **GROUP BY / AGGREGATE**: Count, sum, average across groups
3. **ORDER BY**: Sort result sets
4. **LIMIT / OFFSET**: Pagination
5. **Transactions**: BEGIN, COMMIT, ROLLBACK
6. **Indexes**: CREATE INDEX for faster lookups
7. **Constraints**: PRIMARY KEY, FOREIGN KEY, UNIQUE, NOT NULL
8. **Views with queries**: CREATE VIEW AS SELECT ...

