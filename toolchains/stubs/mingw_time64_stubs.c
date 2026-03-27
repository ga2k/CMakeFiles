/*
 * mingw_time64_stubs.c
 *
 * GCC 15's libstdc++ references clock_gettime64 and nanosleep64 (POSIX
 * Y2038-safe variants) which are absent from this MinGW-w64 sysroot.
 * On x86-64 time_t is already 64-bit, so these are ABI-identical to the
 * Windows API equivalents. Implemented directly against the Win32 API to
 * avoid any MinGW header macro redirection issues.
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

/* Avoid pulling in MinGW <time.h> which may redirect these very symbols */
typedef int      clockid_t;
typedef long long time64_t;

struct timespec64 {
    time64_t tv_sec;
    long     tv_nsec;
};

#define CLOCK_REALTIME  0
#define CLOCK_MONOTONIC 1

int __cdecl clock_gettime64(clockid_t clk, struct timespec64 *tp) {
    LARGE_INTEGER freq, cnt;
    FILETIME ft;
    ULARGE_INTEGER u;

    if (!tp) return -1;

    switch (clk) {
        case CLOCK_REALTIME:
            GetSystemTimePreciseAsFileTime(&ft);
            u.LowPart  = ft.dwLowDateTime;
            u.HighPart = ft.dwHighDateTime;
            u.QuadPart -= 116444736000000000ULL; /* 100ns ticks from 1601 to 1970 */
            tp->tv_sec  = (time64_t)(u.QuadPart / 10000000ULL);
            tp->tv_nsec = (long)((u.QuadPart % 10000000ULL) * 100);
            return 0;

        case CLOCK_MONOTONIC:
            if (!QueryPerformanceFrequency(&freq)) return -1;
            QueryPerformanceCounter(&cnt);
            tp->tv_sec  = (time64_t)(cnt.QuadPart / freq.QuadPart);
            tp->tv_nsec = (long)((cnt.QuadPart % freq.QuadPart) * 1000000000LL
                                 / freq.QuadPart);
            return 0;

        default:
            return -1;
    }
}

int __cdecl nanosleep64(const struct timespec64 *req, struct timespec64 *rem) {
    DWORD ms;
    if (!req) return -1;
    ms = (DWORD)(req->tv_sec * 1000ULL + (DWORD)(req->tv_nsec / 1000000));
    if (ms > 0) Sleep(ms);
    if (rem) { rem->tv_sec = 0; rem->tv_nsec = 0; }
    return 0;
}