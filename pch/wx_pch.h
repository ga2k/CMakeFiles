#pragma once
//
// wx_pch.h — Precompiled header for Gfx / MyCare GUI targets (wx portion)
//
// Contains only pure wxWidgets headers — no Core, no Gfx/Widgets.h.
//
// Core library headers are excluded for the same reason documented in
// core_pch.h: they exist at different physical paths in Core-source builds vs
// staged/installed builds, and including them causes "redefinition" errors in
// .cpp files that also load Core module BMIs.  Gfx/Widgets.h is also excluded
// because it transitively includes Core/Core.h.
//
// This file targets the dominant source of compile-time overhead and BMI
// source-location bloat: the wxWidgets headers and the Windows SDK they pull
// in on Windows.  CMake currently does not inject PCH into C++ module
// interface units (.ixx), so the benefit is limited to regular .cpp
// implementation files (plugins, app source).
//
// Rules:
//   - Do NOT define WX_PRECOMP — that activates wx's own PCH mechanism and conflicts.
//   - Do NOT include headers that contain C++ module import statements.
//   - Do NOT include Core headers here; they belong in core_pch.h but cannot
//     safely be added there (see that file's comment for the reason).
//

// Gfx export macros — macro-only, no includes, completely path-neutral.
#include "Gfx/gfx_export.h"

// wxWidgets — the dominant source of source-location bloat.
// Gfx/wx.h is <wx/wx.h> plus ~40 individual wx headers.
// All paths here are angle-bracket or from Gfx/include, which is consistent
// across all consumers.
#include "Gfx/wx.h"

// Additional wx headers that appear frequently in module global fragments
// but are not pulled in by Gfx/wx.h:
#include <wx/aui/aui.h>
#include <wx/aui/auibar.h>
#include <wx/aui/auibook.h>
#include <wx/webview.h>
