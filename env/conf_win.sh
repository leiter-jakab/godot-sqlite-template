case "$arch" in
	x86_64 | amd64) JUST_TARGET=x86_64-pc-windows-msvc ;;
	aarch64 | arm64) JUST_TARGET=aarch64-pc-windows-msvc ;;
	*) echo "justw: unsupported Windows architecture: $arch" >&2; exit 1 ;;
esac

JUST_ARCHIVE_EXT=zip
JUST_EXECUTABLE=just.exe
GODOT_RELATIVE_PATH="Godot_v${GODOT_VERSION}_win64_console.exe"
GODOT_DOWNLOAD_URL=${GODOT_BASE_URL}_win64.exe.zip
