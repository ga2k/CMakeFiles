#pragma once
//
// core_pch.h — Precompiled header for Core (and any target that builds against it)
//
// Contains only standard-library and platform-neutral headers.
// Core library headers (Core/Core.h, Core/CoreData.h, Core/Util.h) are
// intentionally excluded: they exist at different physical paths depending on
// whether the consumer is the Core source build (Core/include/...) or a
// downstream consumer using the staged/installed headers
// (stage/usr/local/include/HoffSoft/...).  Including them in the PCH causes
// "redefinition" errors in .cpp files that also load Core module BMIs, because
// the BMIs embed source-location references to the source-tree path while the
// PCH would bake in the staged path.
//
// Standard-library headers are completely path-stable and are safe here.
//

#include <algorithm>
#include <any>
#include <array>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <list>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <queue>
#include <regex>
#include <set>
#include <sstream>
#include <string>
#include <type_traits>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>
