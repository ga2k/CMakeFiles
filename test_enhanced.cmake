# Example Usage of Enhanced array.cmake with Named Objects and Collections
# This demonstrates the new capabilities

include(cmake/array.cmake)

# Mock msg() function for testing
function(msg level message)
    message("[${level}] ${message}")
endfunction()

message("=== RECORD Examples ===")

# Create a named record for a package using BULK SET (fast!)
record(CREATE soci_pkg "SOCI" 4)
record(SET soci_pkg 0 "https://github.com/SOCI/soci" "v4.0.3" "SQL database library" "MIT")

# Get the record name
record(GET soci_pkg NAME pkg_name)
message("Package name: ${pkg_name}")

# Get fields
record(GET soci_pkg 0 url)
record(GET soci_pkg 1 version)
message("  URL: ${url}")
message("  Version: ${version}")

# Dump the record
record(DUMP soci_pkg)

message("\n=== Bulk SET Performance Test ===")

# Method 1: Individual SETs (slower)
record(CREATE test1 "SlowMethod" 5)
record(SET test1 0 "field0")
record(SET test1 1 "field1")
record(SET test1 2 "field2")
record(SET test1 3 "field3")
record(SET test1 4 "field4")
message("Individual SETs: 5 conversions")

# Method 2: Bulk SET (faster)
record(CREATE test2 "FastMethod" 5)
record(SET test2 0 "field0" "field1" "field2" "field3" "field4")
message("Bulk SET: 1 conversion - 5x faster!")

# Verify they're identical
record(GET test1 0 v1_0 v1_1 v1_2)
record(GET test2 0 v2_0 v2_1 v2_2)
if("${v1_0}${v1_1}${v1_2}" STREQUAL "${v2_0}${v2_1}${v2_2}")
    message("✓ Both methods produce identical results")
endif()

message("\n=== ARRAY Examples ===")

# Create named array of records
array(CREATE database_packages "DATABASE_PACKAGES" RECORDS)

# Create more package records using bulk SET
record(CREATE sqlite_pkg "SQLITE_ORM" 4)
record(SET sqlite_pkg 0 "https://github.com/fnc12/sqlite_orm" "v1.8.2" "SQLite ORM for C++" "BSD-3")

# Append records to array
array(APPEND database_packages RECORD ${soci_pkg})
array(APPEND database_packages RECORD ${sqlite_pkg})

# Get array name
array(GET database_packages NAME arr_name)
message("Array name: ${arr_name}")

# Get array length
array(LENGTH database_packages num_pkgs)
message("Number of packages: ${num_pkgs}")

# Get by index
array(GET database_packages 0 first_pkg)
record(GET first_pkg NAME first_name)
message("First package: ${first_name}")

# Dump array
array(DUMP database_packages)
message("\n=== NAME-based SET Example ===")

# Create and populate array
array(CREATE test_array "TestArray" RECORDS)
record(CREATE rec1 "First" 2)
record(SET rec1 0 "value1" "data1")
record(CREATE rec2 "Second" 2)
record(SET rec2 0 "value2" "data2")
array(APPEND test_array RECORD ${rec1})
array(APPEND test_array RECORD ${rec2})

message("Before NAME-based SET:")
array(DUMP test_array)

# Update by name instead of index
record(CREATE updated "Second" 2)
record(SET updated 0 "UPDATED_VALUE" "UPDATED_DATA")
array(SET test_array NAME "Second" RECORD ${updated})

message("\nAfter NAME-based SET:")
array(DUMP test_array)

# Verify the update
array(GET test_array EQUAL "Second" check)
record(GET check 0 val)
if("${val}" STREQUAL "UPDATED_VALUE")
    message("✓ NAME-based SET successful!")
endif()

message("\n=== PATH-BASED ACCESS Examples ===")

# Create nested structure: array of arrays of records
array(CREATE all_packages "ALL_PACKAGES" ARRAYS)

# Create storage packages array
array(CREATE storage_packages "STORAGE_PACKAGES" RECORDS)

record(CREATE yaml_pkg "YAML" 4)
record(SET yaml_pkg 0 "https://github.com/jbeder/yaml-cpp" "yaml-cpp-0.7.0" "YAML parser" "MIT")

record(CREATE toml_pkg "TOML" 4)
record(SET toml_pkg 0 "https://github.com/ToruNiina/toml11" "v3.7.1" "TOML parser" "MIT")

array(APPEND storage_packages RECORD ${yaml_pkg})
array(APPEND storage_packages RECORD ${toml_pkg})

# Add both arrays to outer array
array(APPEND all_packages ARRAY ${database_packages})
array(APPEND all_packages ARRAY ${storage_packages})

message("\n--- Nested structure created ---")
array(DUMP all_packages)

# Find by path
message("\n--- Path-based GET ---")
array(GET all_packages EQUAL "STORAGE_PACKAGES/TOML" toml_found)
if(NOT "${toml_found}" STREQUAL "")
    record(GET toml_found NAME found_name)
    record(GET toml_found 0 found_url)
    message("Found via path: ${found_name} at ${found_url}")
else()
    message("Not found!")
endif()

# Find index by path
array(FIND all_packages "DATABASE_PACKAGES/SOCI" soci_idx)
message("SOCI found at index: ${soci_idx}")

message("\n=== COLLECTION Examples ===")

# Create a dict
dict(CREATE feature_packages)

# Add arrays to dict
dict(SET feature_packages "DATABASE" ${database_packages})
dict(SET feature_packages "STORAGE" ${storage_packages})

# Get from dict
dict(GET feature_packages "DATABASE" db_array)
array(GET db_array NAME db_name)
message("Retrieved from dict: ${db_name}")

# Get dict keys
dict(KEYS feature_packages all_keys)
message("Collection keys: ${all_keys}")

# Get dict length
dict(LENGTH feature_packages num_features)
message("Number of feature categories: ${num_features}")

# Dump dict
dict(DUMP feature_packages)

# Path-based access through dict
message("\n--- Path-based GET through dict ---")
dict(GET feature_packages EQUAL "STORAGE/YAML" yaml_from_collection)
if(NOT "${yaml_from_collection}" STREQUAL "")
    record(GET yaml_from_collection NAME yaml_name)
    record(GET yaml_from_collection 1 yaml_version)
    message("Found via dict path: ${yaml_name} version ${yaml_version}")
endif()

message("\n=== NESTED COLLECTION Example ===")

# Create a deeply nested structure
dict(CREATE project_deps)

# Create sub-collections for different dependency types
dict(CREATE required_deps)
dict(SET required_deps "DATABASE" ${database_packages})
dict(SET required_deps "STORAGE" ${storage_packages})

dict(CREATE optional_deps)
array(CREATE networking_packages "NETWORKING" RECORDS)
record(CREATE curl_pkg "CURL" 3)
record(SET curl_pkg 0 "https://github.com/curl/curl" "curl-8_5_0" "HTTP client")
array(APPEND networking_packages RECORD ${curl_pkg})
dict(SET optional_deps "NETWORKING" ${networking_packages})

# Add sub-collections to main dict
dict(SET project_deps "REQUIRED" ${required_deps})
dict(SET project_deps "OPTIONAL" ${optional_deps})

# Deep path access
dict(GET project_deps EQUAL "REQUIRED/DATABASE/SOCI" soci_deep)
if(NOT "${soci_deep}" STREQUAL "")
    record(GET soci_deep NAME soci_deep_name)
    record(GET soci_deep 2 soci_description)
    message("\nDeep path access successful!")
    message("  Name: ${soci_deep_name}")
    message("  Description: ${soci_description}")
endif()

message("\n=== All Tests Complete ===")
