set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
# Host triplet overlay. Mirrors vcpkg's built-in x64-windows but pins the toolset
# to v143 (MSVC 14.44) so host build-time tools are not compiled with the preview
# v145 toolset (VS 2026), which miscompiles abseil/openal-soft. See
# x64-windows-static-release.cmake for details.
set(VCPKG_PLATFORM_TOOLSET v143)
