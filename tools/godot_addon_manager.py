#!/usr/bin/env python3
"""Install the addons pinned in godot-addons.toml."""

from __future__ import annotations

import argparse
import re
import shutil
import stat
import sys
import tarfile
import tempfile
import tomllib
import uuid
import zipfile
from pathlib import Path, PurePosixPath
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]


def load_config(path: Path) -> dict[str, tuple[str, str]]:
    with path.open("rb") as file:
        config = tomllib.load(file)
    if not isinstance(config, dict) or not config:
        raise ValueError("The addon configuration must be a non-empty mapping.")

    addons = {}
    for name, entry in config.items():
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", name):
            raise ValueError(f"Invalid addon name: {name!r}")
        if not isinstance(entry, dict):
            raise ValueError(f"{name}: expected a mapping with version and src.")
        version, source = entry.get("version"), entry.get("src")
        if not isinstance(version, str) or not version:
            raise ValueError(f"{name}: version must be a non-empty quoted string.")
        if not isinstance(source, str) or source.count("{version}") != 1:
            raise ValueError(f"{name}: src must contain exactly one {{version}} placeholder.")
        url = source.replace("{version}", version)
        if "{" in url or "}" in url:
            raise ValueError(f"{name}: src contains an unknown placeholder.")
        parsed = urlparse(url)
        if parsed.scheme != "https" or not parsed.netloc:
            raise ValueError(f"{name}: src must be an HTTPS URL.")
        if "/archive/refs/tags/" in parsed.path:
            kind = "repository"
        elif "/releases/download/" in parsed.path:
            kind = "release"
        else:
            raise ValueError(f"{name}: unsupported source URL: {url}")
        addons[name] = (url, kind)
    return addons


def safe_parts(name: str) -> tuple[str, ...]:
    path = PurePosixPath(name)
    if (
        not name
        or "\\" in name
        or path.is_absolute()
        or not path.parts
        or any(part in (".", "..") or ":" in part for part in path.parts)
    ):
        raise ValueError(f"Unsafe archive path: {name!r}")
    return path.parts


def archive_prefix(paths: list[tuple[str, ...]], name: str, kind: str) -> tuple[str, ...]:
    if kind == "repository":
        prefixes = {parts[:3] for parts in paths if len(parts) >= 3 and parts[1:3] == ("addons", name)}
        if len(prefixes) != 1:
            raise ValueError(f"Repository archive must contain exactly one addons/{name} directory.")
        return prefixes.pop()
    for prefix in (("addons", name), (name,)):
        if any(parts[:len(prefix)] == prefix for parts in paths):
            return prefix
    if any(parts[0] == "addons" for parts in paths):
        raise ValueError(f"Release archive does not contain addons/{name}.")
    return ()


def unpack_archive(archive_path: Path, destination: Path, name: str, kind: str) -> None:
    if zipfile.is_zipfile(archive_path):
        with zipfile.ZipFile(archive_path) as archive:
            entries = [(safe_parts(item.filename), item) for item in archive.infolist()]
            prefix = archive_prefix([parts for parts, _ in entries], name, kind)
            count = 0
            for parts, item in entries:
                if parts[:len(prefix)] != prefix or len(parts) == len(prefix):
                    continue
                relative = parts[len(prefix):]
                target = destination.joinpath(*relative)
                mode = item.external_attr >> 16
                if stat.S_ISLNK(mode):
                    raise ValueError(f"Archive contains a symbolic link: {item.filename}")
                if item.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with archive.open(item) as source, target.open("xb") as output:
                        shutil.copyfileobj(source, output)
                    count += 1
    elif tarfile.is_tarfile(archive_path):
        with tarfile.open(archive_path, "r:*") as archive:
            entries = [(safe_parts(item.name), item) for item in archive.getmembers()]
            prefix = archive_prefix([parts for parts, _ in entries], name, kind)
            count = 0
            for parts, item in entries:
                if parts[:len(prefix)] != prefix or len(parts) == len(prefix):
                    continue
                target = destination.joinpath(*parts[len(prefix):])
                if item.isdir():
                    target.mkdir(parents=True, exist_ok=True)
                elif item.isfile():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    source = archive.extractfile(item)
                    if source is None:
                        raise ValueError(f"Cannot read archive file: {item.name}")
                    with source, target.open("xb") as output:
                        shutil.copyfileobj(source, output)
                    count += 1
                else:
                    raise ValueError(f"Unsupported archive entry: {item.name}")
    else:
        raise ValueError(f"{name}: downloaded file is not a ZIP or tar archive.")
    if not count:
        raise ValueError(f"{name}: archive contains no addon files.")


def install_addon(name: str, url: str, kind: str, addons_dir: Path, force: bool) -> None:
    target = addons_dir / name
    if target.exists() or target.is_symlink():
        if not force:
            raise FileExistsError(f"{target} already exists; use --force to replace it.")
        if not target.is_dir() or target.is_symlink():
            raise ValueError(f"{target} is not a regular directory.")
    addons_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".addon-manager-", dir=addons_dir) as temporary:
        temporary_path = Path(temporary)
        archive_path = temporary_path / "download"
        stage = temporary_path / "staged"
        stage.mkdir()
        print(f"Downloading {name} from {url}", flush=True)
        request = Request(url, headers={"User-Agent": "godot-addon-manager"})
        with urlopen(request, timeout=120) as response, archive_path.open("wb") as file:
            shutil.copyfileobj(response, file)
        unpack_archive(archive_path, stage, name, kind)
        backup = addons_dir / f".addon-backup-{uuid.uuid4().hex}"
        replacing = target.exists() or target.is_symlink()
        if replacing:
            if not force:
                raise FileExistsError(f"{target} already exists; use --force to replace it.")
            if not target.is_dir() or target.is_symlink():
                raise ValueError(f"{target} is not a regular directory.")
            target.rename(backup)
        try:
            stage.rename(target)
        except OSError as error:
            if replacing:
                try:
                    backup.rename(target)
                except OSError as restore_error:
                    raise OSError(
                        f"Installation failed ({error}); original addon remains at {backup} "
                        f"because restoration failed: {restore_error}"
                    ) from restore_error
            raise
        if replacing:
            shutil.rmtree(backup)
        print(f"Installed {name} in {target}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=ROOT / "godot-addons.toml")
    parser.add_argument("--addons-dir", type=Path, default=ROOT / "addons")
    existing_mode = parser.add_mutually_exclusive_group()
    existing_mode.add_argument("--force", action="store_true", help="Replace existing addon directories.")
    existing_mode.add_argument("--skip-existing", action="store_true", help="Skip existing addon directories.")
    args = parser.parse_args()
    try:
        addons = load_config(args.config)
        if not args.force and not args.skip_existing:
            existing = [
                name for name in addons
                if (args.addons_dir / name).exists() or (args.addons_dir / name).is_symlink()
            ]
            if existing:
                raise FileExistsError(
                    f"Addon directories already exist: {', '.join(existing)}; use --force to replace them."
                )
        for name, (url, kind) in addons.items():
            target = args.addons_dir / name
            if args.skip_existing and (target.exists() or target.is_symlink()):
                if not target.is_dir() or target.is_symlink():
                    raise ValueError(f"{target} is not a regular directory.")
                print(f"Skipping {name}: {target} already exists (version not verified).")
                continue
            install_addon(name, url, kind, args.addons_dir, args.force)
    except (OSError, ValueError, tarfile.TarError, zipfile.BadZipFile) as error:
        print(f"Addon installation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
