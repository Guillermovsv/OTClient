set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_BUILD_TYPE release)
# Pin ports to the v143 toolset (MSVC 14.44). The preview v145 toolset (14.51/14.52,
# VS 2026) miscompiles some ports: abseil hits C1083 (empty output file) and
# openal-soft 1.25.1 hits C3889 std::ranges errors in alc.cpp. vcpkg builds each
# port in its own environment and otherwise defaults to the newest installed toolset,
# ignoring the preset's VCPKG_PLATFORM_TOOLSET cache variable.
set(VCPKG_PLATFORM_TOOLSET v143)
