file(READ "${INPUT_FILE}" HEX_CONTENTS HEX)
string(REGEX REPLACE "(..)" "0x\\1, " ARRAY_CONTENTS "${HEX_CONTENTS}")
file(WRITE "${OUTPUT_FILE}" "extern const char app_config_yaml[] = { ${ARRAY_CONTENTS} 0x00 };\n")
file(APPEND "${OUTPUT_FILE}" "extern const unsigned int app_config_yaml_len = sizeof(app_config_yaml) - 1;\n")./