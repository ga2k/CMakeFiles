# Example Usage of Enhanced array.cmake with Named Objects and Collections
# This demonstrates the new capabilities

include(cmake/array_enhanced.cmake)

# Mock msg() function for testing
function(msg level message)
    message("[${level}] ${message}")
endfunction()

message("=== RECORD Examples ===")

# Create a named record for a package
record(CREATE soci_pkg "SOCI" 4)
record(SET soci_pkg 0 "https://github.com/SOCI/soci")
record(SET soci_pkg 1 "v4.0.3")
record(SET soci_pkg 2 "SQL database library")
record(SET soci_pkg 3 "MIT")

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

message("\n=== ARRAY Examples ===")

# Create named array of records
array(CREATE database_packages "DATABASE_PACKAGES" RECORDS)

# Create more package records
record(CREATE sqlite_pkg "SQLITE_ORM" 4)
record(SET sqlite_pkg 0 "https://github.com/fnc12/sqlite_orm")
record(SET sqlite_pkg 1 "v1.8.2")
record(SET sqlite_pkg 2 "SQLite ORM for C++")
record(SET sqlite_pkg 3 "BSD-3")

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

message("\n=== PATH-BASED ACCESS Examples ===")

# Create nested structure: array of arrays of records
array(CREATE all_packages "ALL_PACKAGES" ARRAYS)

# Create storage packages array
array(CREATE storage_packages "STORAGE_PACKAGES" RECORDS)

record(CREATE yaml_pkg "YAML" 4)
record(SET yaml_pkg 0 "https://github.com/jbeder/yaml-cpp")
record(SET yaml_pkg 1 "yaml-cpp-0.7.0")
record(SET yaml_pkg 2 "YAML parser")
record(SET yaml_pkg 3 "MIT")

record(CREATE toml_pkg "TOML" 4)
record(SET toml_pkg 0 "https://github.com/ToruNiina/toml11")
record(SET toml_pkg 1 "v3.7.1")
record(SET toml_pkg 2 "TOML parser")
record(SET toml_pkg 3 "MIT")

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

# Create a collection
collection(CREATE feature_packages)

# Add arrays to collection
collection(SET feature_packages "DATABASE" ${database_packages})
collection(SET feature_packages "STORAGE" ${storage_packages})

# Get from collection
collection(GET feature_packages "DATABASE" db_array)
array(GET db_array NAME db_name)
message("Retrieved from collection: ${db_name}")

# Get collection keys
collection(KEYS feature_packages all_keys)
message("Collection keys: ${all_keys}")

# Get collection length
collection(LENGTH feature_packages num_features)
message("Number of feature categories: ${num_features}")

# Dump collection
collection(DUMP feature_packages)

# Path-based access through collection
message("\n--- Path-based GET through collection ---")
collection(GET feature_packages EQUAL "STORAGE/YAML" yaml_from_collection)
if(NOT "${yaml_from_collection}" STREQUAL "")
    record(GET yaml_from_collection NAME yaml_name)
    record(GET yaml_from_collection 1 yaml_version)
    message("Found via collection path: ${yaml_name} version ${yaml_version}")
endif()

message("\n=== NESTED COLLECTION Example ===")

# Create a deeply nested structure
collection(CREATE project_deps)

# Create sub-collections for different dependency types
collection(CREATE required_deps)
collection(SET required_deps "DATABASE" ${database_packages})
collection(SET required_deps "STORAGE" ${storage_packages})

collection(CREATE optional_deps)
array(CREATE networking_packages "NETWORKING" RECORDS)
record(CREATE curl_pkg "CURL" 3)
record(SET curl_pkg 0 "https://github.com/curl/curl")
record(SET curl_pkg 1 "curl-8_5_0")
record(SET curl_pkg 2 "HTTP client")
array(APPEND networking_packages RECORD ${curl_pkg})
collection(SET optional_deps "NETWORKING" ${networking_packages})

# Add sub-collections to main collection
collection(SET project_deps "REQUIRED" ${required_deps})
collection(SET project_deps "OPTIONAL" ${optional_deps})

# Deep path access
collection(GET project_deps EQUAL "REQUIRED/DATABASE/SOCI" soci_deep)
if(NOT "${soci_deep}" STREQUAL "")
    record(GET soci_deep NAME soci_deep_name)
    record(GET soci_deep 2 soci_description)
    message("\nDeep path access successful!")
    message("  Name: ${soci_deep_name}")
    message("  Description: ${soci_description}")
endif()

message("\n=== All Tests Complete ===")
