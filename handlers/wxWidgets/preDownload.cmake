function(wxWidgets_preDownload pkgname url tag srcDir)
    message(NOTICE "Configuring wxWidgets build options for source build")

    # Common wxWidgets build options
    set(wxBUILD_SHARED ON CACHE BOOL "" FORCE)
    set(wxBUILD_SAMPLES OFF CACHE BOOL "" FORCE)
    set(wxBUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(wxBUILD_DEMOS OFF CACHE BOOL "" FORCE)
    set(wxBUILD_INSTALL ON CACHE BOOL "" FORCE)

    if (LINUX)
        # The user's process.cmake suggests they are using Qt toolkit on Linux
        set(wxBUILD_TOOLKIT "qt" CACHE STRING "" FORCE)
    elseif (APPLE)
        set(wxBUILD_TOOLKIT "osx_cocoa" CACHE STRING "" FORCE)
    elseif (WIN32)
        set(wxBUILD_TOOLKIT "msw" CACHE STRING "" FORCE)
    endif ()

    # Ensure it doesn't try to use system-installed wxWidgets when we are building from source
    set(wxWidgets_FOUND FALSE CACHE BOOL "" FORCE)
endfunction()

wxWidgets_preDownload(${this_pkgname} ${this_url} ${this_tag} "${EXTERNALS_DIR}/${this_pkgname}")
set(HANDLED OFF)
