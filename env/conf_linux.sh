case "$arch" in
	x86_64 | amd64) JUST_TARGET=x86_64-unknown-linux-musl ;;
	*) echo "justw: Linux Godot bootstrap supports x86_64 only; unsupported architecture: $arch" >&2; exit 1 ;;
esac

JUST_ARCHIVE_EXT=tar.gz
JUST_EXECUTABLE=just
GODOT_RELATIVE_PATH="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_DOWNLOAD_URL=${GODOT_BASE_URL}_linux.x86_64.zip
