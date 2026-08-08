set(VCPKG_TARGET_ARCHITECTURE x86)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_BUILD_TYPE release)
# Pin ports to v143 (MSVC 14.44); the preview v145 toolset (VS 2026) miscompiles
# abseil/openal-soft. See x64-windows-static-release.cmake for details.
set(VCPKG_PLATFORM_TOOLSET v143)
