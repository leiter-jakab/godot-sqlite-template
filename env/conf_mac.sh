case "$arch" in
	x86_64) JUST_TARGET=x86_64-apple-darwin ;;
	arm64 | aarch64) JUST_TARGET=aarch64-apple-darwin ;;
	*) echo "justw: unsupported macOS architecture: $arch" >&2; exit 1 ;;
esac

JUST_ARCHIVE_EXT=tar.gz
JUST_EXECUTABLE=just
GODOT_RELATIVE_PATH="Godot.app/Contents/MacOS/Godot"
GODOT_DOWNLOAD_URL=${GODOT_BASE_URL}_macos.universal.zip
