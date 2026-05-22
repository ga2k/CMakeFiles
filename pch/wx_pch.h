#pragma once
//
// wx_pch.h — Precompiled header for Gfx / HealthCanvas GUI targets (wx portion)
//
// Contains only wxWidgets headers and STL headers — no project-specific paths.
//
// This file is built ONCE at the stable stage path and shared across all
// consumers (Gfx module BMIs + HealthCanvas compilations).  All includes must use
// angle-bracket paths so the PCH binary is valid regardless of which project's
// source tree is active.
//
// "Gfx/gfx_export.h" and "Gfx/wx.h" are intentionally NOT included here:
// they use source-relative paths which resolve to different absolute paths
// in Gfx builds vs HealthCanvas builds, causing Clang PCH path validation failures.
//
// Rules:
//   - Do NOT define WX_PRECOMP — that activates wx's own PCH mechanism and conflicts.
//   - Do NOT include headers that contain C++ module import statements.
//   - Do NOT include project headers (Core, Gfx) — they are path-unstable.
//

// Standard library — path-stable across all consumers
#include <algorithm>
#include <any>
#include <array>
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

// wxWidgets — the dominant source of source-location bloat.
// Direct angle-bracket includes (equivalent to Gfx/wx.h contents).
#include <wx/wx.h>

#include <wx/activityindicator.h>
#include <wx/app.h>
#include <wx/artprov.h>
#include <wx/bitmap.h>
#include <wx/bmpbuttn.h>
#include <wx/busyinfo.h>
#include <wx/button.h>
#include <wx/checkbox.h>
#include <wx/choice.h>
#include <wx/clipbrd.h>
#include <wx/cmdline.h>
#include <wx/colordlg.h>
#include <wx/combo.h>
#include <wx/combobox.h>
#include <wx/confbase.h>
#include <wx/datectrl.h>
#include <wx/dateevt.h>
#include <wx/datetime.h>
#include <wx/datetimectrl.h>
#include <wx/dcsvg.h>
#include <wx/docview.h>
#include <wx/event.h>
#include <wx/filefn.h>
#include <wx/filesys.h>
#include <wx/fontdata.h>
#include <wx/fontdlg.h>
#include <wx/fs_inet.h>
#include <wx/gauge.h>
#include <wx/gbsizer.h>
#include <wx/generic/stattextg.h>
#include <wx/grid.h>
#include <wx/image.h>
#include <wx/infobar.h>
#include <wx/intl.h>
#include <wx/list.h>
#include <wx/listbase.h>
#include <wx/msgdlg.h>
#include <wx/notebook.h>
#include <wx/panel.h>
#include <wx/popupwin.h>
#include <wx/printdlg.h>
#include <wx/radiobox.h>
#include <wx/radiobut.h>
#include <wx/renderer.h>
#include <wx/richmsgdlg.h>
#include <wx/rtti.h>
#include <wx/scrolbar.h>
#include <wx/sizer.h>
#include <wx/slider.h>
#include <wx/spinbutt.h>
#include <wx/spinctrl.h>
#include <wx/splitter.h>
#include <wx/srchctrl.h>
#include <wx/statline.h>
#include <wx/stattext.h>
#include <wx/stdpaths.h>
#include <wx/textctrl.h>
#include <wx/tglbtn.h>
#include <wx/timer.h>
#include <wx/treectrl.h>
#include <wx/utils.h>
#include <wx/valgen.h>
#include <wx/wizard.h>

// Additional wx headers that appear frequently in module global fragments
#include <wx/aui/aui.h>
#include <wx/aui/auibar.h>
#include <wx/aui/auibook.h>
#include <wx/webview.h>
