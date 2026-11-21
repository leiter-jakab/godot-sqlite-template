import io
import stat
import sys
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

from tools import godot_addon_manager as manager


def tar_archive(files: dict[str, bytes]) -> bytes:
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode="w:gz") as archive:
        for path, content in files.items():
            item = tarfile.TarInfo(path)
            item.size = len(content)
            archive.addfile(item, io.BytesIO(content))
    return data.getvalue()


def zip_archive(files: dict[str, bytes]) -> bytes:
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w") as archive:
        for path, content in files.items():
            archive.writestr(path, content)
    return data.getvalue()


class GodotAddonManagerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.addons = self.root / "addons"

    def install(self, name: str, kind: str, data: bytes, force: bool = False) -> None:
        with mock.patch.object(manager, "urlopen", return_value=io.BytesIO(data)):
            manager.install_addon(name, "https://example.com/archive", kind, self.addons, force)

    def test_repository_archive_installs_only_requested_addon(self) -> None:
        data = tar_archive({
            "Gut-v1/addons/gut/plugin.cfg": b"plugin",
            "Gut-v1/addons/gut/LICENSE.md": b"license",
            "Gut-v1/addons/other/plugin.cfg": b"other",
            "Gut-v1/README.md": b"repository",
        })
        self.install("gut", "repository", data)
        self.assertEqual((self.addons / "gut" / "plugin.cfg").read_bytes(), b"plugin")
        self.assertEqual((self.addons / "gut" / "LICENSE.md").read_bytes(), b"license")
        self.assertFalse((self.addons / "other").exists())

    def test_release_archive_installs_addon_from_addons_directory(self) -> None:
        data = zip_archive({
            "addons/godot-sqlite/plugin.cfg": b"plugin",
            "addons/godot-sqlite/bin/library.dll": b"binary",
            "addons/other/plugin.cfg": b"other",
        })
        self.install("godot-sqlite", "release", data)
        self.assertEqual((self.addons / "godot-sqlite" / "bin" / "library.dll").read_bytes(), b"binary")
        self.assertFalse((self.addons / "other").exists())

    def test_release_archive_can_contain_addon_files_directly(self) -> None:
        self.install("example", "release", zip_archive({"plugin.cfg": b"plugin"}))
        self.assertEqual((self.addons / "example" / "plugin.cfg").read_bytes(), b"plugin")

    def test_existing_addon_requires_force_and_force_replaces_it(self) -> None:
        target = self.addons / "example"
        target.mkdir(parents=True)
        (target / "old").write_text("old", encoding="utf-8")
        data = zip_archive({"plugin.cfg": b"new"})
        with mock.patch.object(manager, "urlopen") as download:
            with self.assertRaises(FileExistsError):
                manager.install_addon("example", "https://example.com", "release", self.addons, False)
            download.assert_not_called()
        self.install("example", "release", data, force=True)
        self.assertFalse((target / "old").exists())
        self.assertEqual((target / "plugin.cfg").read_bytes(), b"new")

    def test_invalid_archive_does_not_replace_existing_addon(self) -> None:
        target = self.addons / "example"
        target.mkdir(parents=True)
        (target / "old").write_text("old", encoding="utf-8")
        data = zip_archive({"../escape": b"bad"})
        with self.assertRaisesRegex(ValueError, "Unsafe archive path"):
            self.install("example", "release", data, force=True)
        self.assertEqual((target / "old").read_text(encoding="utf-8"), "old")
        self.assertFalse((self.root / "escape").exists())

    def test_failed_install_and_restore_keep_backup(self) -> None:
        target = self.addons / "example"
        target.mkdir(parents=True)
        (target / "old").write_text("old", encoding="utf-8")
        original_rename = Path.rename

        def fail_install_and_restore(path: Path, destination: Path) -> Path:
            if path.name == "staged" or path.name.startswith(".addon-backup-"):
                raise OSError("simulated rename failure")
            return original_rename(path, destination)

        with mock.patch.object(Path, "rename", fail_install_and_restore):
            with self.assertRaisesRegex(OSError, "original addon remains at"):
                self.install("example", "release", zip_archive({"plugin.cfg": b"new"}), force=True)
        backups = list(self.addons.glob(".addon-backup-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "old").read_text(encoding="utf-8"), "old")

    def test_missing_repository_addon_is_an_error(self) -> None:
        data = tar_archive({"repo/addons/other/plugin.cfg": b"other"})
        with self.assertRaisesRegex(ValueError, "exactly one"):
            self.install("example", "repository", data)
        self.assertFalse((self.addons / "example").exists())

    def test_release_archive_rejects_symbolic_links(self) -> None:
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            link = zipfile.ZipInfo("addons/example/link")
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(link, "../../outside")
        with self.assertRaisesRegex(ValueError, "symbolic link"):
            self.install("example", "release", data.getvalue())
        self.assertFalse((self.addons / "example").exists())

    def test_config_uses_version_and_rejects_unsafe_names(self) -> None:
        config = self.root / "deps.toml"
        config.write_text(
            '[gut]\nversion = "9.7.1"\n'
            'src = "https://example.com/archive/refs/tags/v{version}.tar.gz"\n',
            encoding="utf-8",
        )
        self.assertEqual(
            manager.load_config(config),
            {"gut": ("https://example.com/archive/refs/tags/v9.7.1.tar.gz", "repository")},
        )
        config.write_text(
            '["../escape"]\nversion = "1"\n'
            'src = "https://example.com/archive/refs/tags/v{version}.tar.gz"\n',
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ValueError, "Invalid addon name"):
            manager.load_config(config)

    def test_cli_preflights_all_existing_addons_before_downloading(self) -> None:
        config = self.root / "deps.toml"
        config.write_text(
            '[first]\nversion = "1"\nsrc = "https://example.com/archive/refs/tags/{version}.zip"\n'
            '[second]\nversion = "1"\nsrc = "https://example.com/releases/download/{version}/addon.zip"\n',
            encoding="utf-8",
        )
        (self.addons / "second").mkdir(parents=True)
        args = ["manager", "--config", str(config), "--addons-dir", str(self.addons)]
        with mock.patch.object(sys, "argv", args), mock.patch.object(manager, "urlopen") as download:
            self.assertEqual(manager.main(), 1)
            download.assert_not_called()
        self.assertFalse((self.addons / "first").exists())

    def test_skip_existing_installs_only_missing_addons(self) -> None:
        existing = self.addons / "gut"
        existing.mkdir(parents=True)
        (existing / "plugin.cfg").write_text("local changes", encoding="utf-8")
        archive = zip_archive({"addons/godot-sqlite/plugin.cfg": b"sqlite"})
        args = ["manager", "--addons-dir", str(self.addons), "--skip-existing"]
        with mock.patch.object(sys, "argv", args), mock.patch.object(
            manager, "urlopen", return_value=io.BytesIO(archive)
        ) as download:
            self.assertEqual(manager.main(), 0)
            self.assertEqual(manager.main(), 0)
            download.assert_called_once()
        self.assertEqual((existing / "plugin.cfg").read_text(encoding="utf-8"), "local changes")
        self.assertEqual((self.addons / "godot-sqlite" / "plugin.cfg").read_bytes(), b"sqlite")

    def test_skip_existing_rejects_non_directory(self) -> None:
        self.addons.mkdir()
        (self.addons / "gut").write_text("not a directory", encoding="utf-8")
        args = ["manager", "--addons-dir", str(self.addons), "--skip-existing"]
        with mock.patch.object(sys, "argv", args), mock.patch.object(manager, "urlopen") as download:
            self.assertEqual(manager.main(), 1)
            download.assert_not_called()

    def test_cli_uses_project_toml_by_default(self) -> None:
        downloads = [
            io.BytesIO(tar_archive({"repo/addons/gut/plugin.cfg": b"gut"})),
            io.BytesIO(zip_archive({"addons/godot-sqlite/plugin.cfg": b"sqlite"})),
        ]
        args = ["manager", "--addons-dir", str(self.addons)]
        with mock.patch.object(sys, "argv", args), mock.patch.object(manager, "urlopen", side_effect=downloads):
            self.assertEqual(manager.main(), 0)
        self.assertEqual((self.addons / "gut" / "plugin.cfg").read_bytes(), b"gut")
        self.assertEqual((self.addons / "godot-sqlite" / "plugin.cfg").read_bytes(), b"sqlite")

    def test_cli_reports_invalid_toml_without_downloading(self) -> None:
        config = self.root / "deps.toml"
        config.write_text("[invalid\n", encoding="utf-8")
        args = ["manager", "--config", str(config), "--addons-dir", str(self.addons)]
        stderr = io.StringIO()
        with mock.patch.object(sys, "argv", args), mock.patch.object(sys, "stderr", stderr):
            with mock.patch.object(manager, "urlopen") as download:
                self.assertEqual(manager.main(), 1)
                download.assert_not_called()
        self.assertIn("Addon installation failed:", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
