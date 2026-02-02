# Enhanced Array System Documentation

## Overview

This enhanced array system provides three powerful data structure primitives for CMake:

1. **record** - Named field-based structures (like C structs or Python namedtuples)
2. **array** - Named ordered collections of records or arrays
3. **collection** - Named key-value maps (like Python dicts or JSON objects)

All structures support:
- **Named objects**: Every record, array, and collection has a mandatory name
- **Path-based access**: Navigate nested structures with "path/to/item" syntax
- **Type safety**: Records, arrays of records, and arrays of arrays are distinct types
- **CMake compatibility**: Everything is still a string variable that can be copied and passed

## Quick Start

```cmake
# Create a named record
record(CREATE my_record "PersonData" 3)
record(SET my_record 0 "John")
record(SET my_record 1 "Doe")
record(SET my_record 2 "30")

# Create a named array
array(CREATE people "AllPeople" RECORDS)
array(APPEND people RECORD ${my_record})

# Create a collection
collection(CREATE my_data)
collection(SET my_data "people" ${people})

# Path-based access
collection(GET my_data EQUAL "people/PersonData" person)
record(GET person 0 first_name)  # Returns "John"
```

## Data Formats

### Record Format
```
{FS}NAME{FS}field1{FS}field2{FS}field3...
```
- First field after FS (File Separator, ASCII 28) is the name
- Subsequent fields are data
- Empty fields stored as "-" sentinel

### Array Format
```
{SEP}NAME{SEP}elem1{SEP}elem2{SEP}elem3...
```
- SEP is RS (Record Separator, ASCII 30) for array-of-records
- SEP is GS (Group Separator, ASCII 29) for array-of-arrays
- First element after separator is the array name
- Subsequent elements are data

### Collection Format
```
{US}key1{US}value1{US}key2{US}value2...
```
- US (Unit Separator, ASCII 31) delimits key-value pairs
- Values can be records, arrays, or other collections

## API Reference

### record() Operations

#### CREATE
```cmake
record(CREATE <recVar> <name> <numFields>)
```
Creates a new named record with N fields (all initialized to empty).

Example:
```cmake
record(CREATE pkg "YAML" 3)
# Creates: {FS}YAML{FS}-{FS}-{FS}-
```

#### GET NAME
```cmake
record(GET <recVar> NAME <outVar>)
```
Retrieves the record's name.

#### GET Fields
```cmake
record(GET <recVar> <fieldIndex> <outVar1> [<outVar2>...] [TOUPPER|TOLOWER])
```
Gets one or more consecutive fields starting at fieldIndex.
**Note**: fieldIndex 0 is the first data field (name is not counted).

Example:
```cmake
record(GET pkg 0 url)     # Get first field
record(GET pkg 0 url ver) # Get first two fields
record(GET pkg 0 url TOUPPER) # Get first field as uppercase
```

#### SET
```cmake
record(SET <recVar> <fieldIndex> <newValue> [FAIL|QUIET])
```
Sets a field value. Auto-extends if index out of range (unless FAIL specified).

Example:
```cmake
record(SET pkg 0 "https://github.com/yaml")
record(SET pkg 5 "value" FAIL)  # Error if index 5 doesn't exist
```

#### APPEND / PREPEND
```cmake
record(APPEND <recVar> <value1> [<value2>...])
record(PREPEND <recVar> <value1> [<value2>...])
```
Adds fields to end or beginning (after name).

#### POP_FRONT / POP_BACK
```cmake
record(POP_FRONT <recVar> <outVar1> [<outVar2>...] [TOUPPER|TOLOWER])
record(POP_BACK <recVar> <outVar1> [<outVar2>...] [TOUPPER|TOLOWER])
```
Removes and returns fields from beginning or end.

#### DUMP
```cmake
record(DUMP <recVar> [<outVarName>] [VERBOSE])
```
Displays record contents. If outVarName provided, stores output there instead of printing.

### array() Operations

#### CREATE
```cmake
array(CREATE <arrayVar> <name> RECORDS|ARRAYS)
```
Creates a new named array.

Example:
```cmake
array(CREATE pkgs "DatabasePackages" RECORDS)
```

#### GET NAME
```cmake
array(GET <arrayVar> NAME <outVar>)
```
Retrieves the array's name.

#### GET by Index
```cmake
array(GET <arrayVar> <index> <outVar1> [<outVar2>...])
```
Gets one or more consecutive elements starting at index.
**Note**: index 0 is the first element (name is not counted).

#### GET by Path
```cmake
array(GET <arrayVar> EQUAL <path> <outVar>)
```
Retrieves element by name path.

Example:
```cmake
array(GET all_pkgs EQUAL "DATABASE/SOCI" result)
```

#### GET by Regex
```cmake
array(GET <arrayVar> MATCHING <regex> <outVar>)
```
Retrieves first element whose name matches the regex.

Example:
```cmake
array(GET pkgs MATCHING "SQL.*" first_sql_pkg)
```

#### LENGTH
```cmake
array(LENGTH <arrayVar> <outVar>)
```
Returns number of elements (excluding the array's own name).

#### SET
```cmake
array(SET <arrayVar> <index> RECORD|ARRAY <value> [FAIL|QUIET])
```
Sets element at index. Type must match array's type.

#### APPEND / PREPEND
```cmake
array(APPEND <arrayVar> RECORD|ARRAY <value1> [<value2>...])
array(PREPEND <arrayVar> RECORD|ARRAY <value1> [<value2>...])
```
Adds elements to end or beginning.

Example:
```cmake
array(APPEND db_pkgs RECORD ${soci_record})
array(APPEND outer_array ARRAY ${inner_array})
```

#### FIND
```cmake
array(FIND <arrayVar> <path> <outVar>)
```
Finds element by path and returns its index (-1 if not found).

Example:
```cmake
array(FIND all_pkgs "STORAGE/YAML" idx)
if(idx GREATER_EQUAL 0)
    array(GET all_pkgs ${idx} yaml_pkg)
endif()
```

#### DUMP
```cmake
array(DUMP <arrayVar> [<outVarName>] [VERBOSE])
```
Displays array contents.

### collection() Operations

#### CREATE
```cmake
collection(CREATE <collectionVar>)
```
Creates a new empty collection.

#### SET
```cmake
collection(SET <collectionVar> <key> <value>)
```
Sets a key-value pair. Value can be record, array, or another collection.

Example:
```cmake
collection(SET deps "database" ${db_array})
collection(SET deps "version" ${version_record})
collection(SET deps "metadata" ${metadata_collection})
```

#### GET by Key
```cmake
collection(GET <collectionVar> <key> <outVar>)
```
Retrieves value for a key.

#### GET by Path
```cmake
collection(GET <collectionVar> EQUAL <path> <outVar>)
```
Retrieves nested value by path.

Example:
```cmake
collection(GET project EQUAL "deps/database/SOCI" soci_pkg)
```

#### REMOVE
```cmake
collection(REMOVE <collectionVar> <key>)
```
Removes a key-value pair.

#### KEYS
```cmake
collection(KEYS <collectionVar> <outVar>)
```
Returns a CMake list of all keys.

Example:
```cmake
collection(KEYS deps all_keys)
foreach(key IN LISTS all_keys)
    collection(GET deps ${key} value)
    message("${key}: ${value}")
endforeach()
```

#### LENGTH
```cmake
collection(LENGTH <collectionVar> <outVar>)
```
Returns number of key-value pairs.

#### DUMP
```cmake
collection(DUMP <collectionVar> [<outVarName>])
```
Displays collection contents.

## Use Cases

### 1. Package Management

```cmake
# Define package records
record(CREATE soci "SOCI" 4)
record(SET soci 0 "https://github.com/SOCI/soci")
record(SET soci 1 "v4.0.3")
record(SET soci 2 "SQL library")
record(SET soci 3 "Boost")

record(CREATE yaml "YAML" 4)
record(SET yaml 0 "https://github.com/jbeder/yaml-cpp")
record(SET yaml 1 "0.7.0")
record(SET yaml 2 "YAML parser")
record(SET yaml 3 "MIT")

# Organize into categories
array(CREATE db_pkgs "DATABASE" RECORDS)
array(APPEND db_pkgs RECORD ${soci})

array(CREATE storage_pkgs "STORAGE" RECORDS)
array(APPEND storage_pkgs RECORD ${yaml})

# Create master collection
collection(CREATE all_features)
collection(SET all_features "DATABASE" ${db_pkgs})
collection(SET all_features "STORAGE" ${storage_pkgs})

# Quick access
collection(GET all_features EQUAL "DATABASE/SOCI" my_pkg)
record(GET my_pkg 0 url)
record(GET my_pkg 1 version)

FetchContent_Declare(
    soci
    GIT_REPOSITORY ${url}
    GIT_TAG ${version}
)
```

### 2. Configuration Management

```cmake
# Server configurations
record(CREATE prod_db "Production" 3)
record(SET prod_db 0 "prod.db.company.com")
record(SET prod_db 1 "5432")
record(SET prod_db 2 "ssl")

record(CREATE dev_db "Development" 3)
record(SET dev_db 0 "localhost")
record(SET dev_db 1 "5432")
record(SET dev_db 2 "plain")

array(CREATE db_configs "DatabaseConfigs" RECORDS)
array(APPEND db_configs RECORD ${prod_db})
array(APPEND db_configs RECORD ${dev_db})

collection(CREATE env_config)
collection(SET env_config "databases" ${db_configs})

# Select config based on environment
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    collection(GET env_config EQUAL "databases/Production" active_db)
else()
    collection(GET env_config EQUAL "databases/Development" active_db)
endif()

record(GET active_db 0 db_host)
record(GET active_db 1 db_port)
```

### 3. Build Target Metadata

```cmake
# Store metadata about build targets
record(CREATE target_meta "MyLibrary" 5)
record(SET target_meta 0 "lib")               # Type
record(SET target_meta 1 "src/mylib")         # Source dir
record(SET target_meta 2 "C++17")             # Language standard
record(SET target_meta 3 "soci;yaml")         # Dependencies
record(SET target_meta 4 "PUBLIC")            # Visibility

array(CREATE all_targets "BuildTargets" RECORDS)
array(APPEND all_targets RECORD ${target_meta})

# Later: retrieve and configure
array(GET all_targets EQUAL "MyLibrary" meta)
record(GET meta 0 type)
record(GET meta 1 src_dir)
record(GET meta 2 std)
record(GET meta 3 deps)

if(type STREQUAL "lib")
    add_library(MyLibrary ${src_dir}/main.cpp)
    target_compile_features(MyLibrary PUBLIC cxx_std_17)
    # Parse and link dependencies...
endif()
```

## Best Practices

### 1. Naming Conventions
- Use descriptive, meaningful names for all objects
- Use UPPER_CASE for category names (e.g., "DATABASE_PACKAGES")
- Use CamelCase or hyphen-case for specific items (e.g., "YAML-Parser")

### 2. Structure Organization
- Use **records** for simple data structures (like C structs)
- Use **arrays** for ordered, homogeneous collections
- Use **collections** for heterogeneous groups accessed by name

### 3. Path-Based Access
- Prefer path-based access for deep hierarchies: `collection(GET ... EQUAL "a/b/c")`
- Cache frequently accessed paths in variables
- Use FIND to locate items when you don't know the exact index

### 4. Type Safety
- Be explicit with RECORD vs ARRAY in array operations
- Don't mix records and arrays in the same array
- Validate object types if working with dynamic data

### 5. Error Handling
- Use FAIL mode for SET operations when you expect the index to exist
- Check return values from GET operations (empty string = not found)
- Use FIND before GET when searching for items

## Migration from Old Code

If you have existing code using the old (anonymous) array system:

### Before (anonymous arrays):
```cmake
array(CREATE pkgs RECORDS)
record(CREATE pkg1 3)
record(SET pkg1 0 "value")
array(APPEND pkgs RECORD ${pkg1})
array(GET pkgs 0 result)
```

### After (named objects):
```cmake
array(CREATE pkgs "AllPackages" RECORDS)        # Added name
record(CREATE pkg1 "Package1" 3)                # Added name
record(SET pkg1 0 "value")                      # Index unchanged
array(APPEND pkgs RECORD ${pkg1})               # Same
array(GET pkgs 0 result)                        # Index 0 still first element
array(GET pkgs EQUAL "Package1" result)         # NEW: Get by name
```

**Key Changes:**
1. CREATE operations require a name parameter
2. Field/element indices are unchanged (name is separate)
3. New GET EQUAL syntax for path-based access
4. Arrays and records are now self-describing (contain their names)

## Performance Considerations

- **Memory**: Each separator character (FS/RS/GS/US) is 1 byte. Names add string length.
- **Speed**: Path resolution is O(n) in the number of elements at each level.
- **Depth**: Path resolution is recursive; very deep nesting may hit CMake limits.
- **Best for**: Structured configuration, metadata, and build system organization.
- **Not ideal for**: Large datasets that need frequent iteration (use CMake lists instead).

## Limitations

1. **No empty records**: Records must have at least one field (plus name)
2. **No control characters**: User data cannot contain FS/GS/RS/US characters
3. **Text only**: Binary data not supported
4. **String storage**: Everything is stored as strings (no native integers/booleans)
5. **No circular references**: Collections cannot contain themselves (would create infinite loops)

## Advanced Example: Complex Project Structure

See `test_enhanced.cmake` for a complete working example that demonstrates:
- Creating multiple nested records
- Building arrays of different types
- Organizing data with collections
- Path-based navigation
- Deep nesting (collection -> collection -> array -> record)
