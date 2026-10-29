import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / 'ox_patch/apply-ox-patch.py'
spec = importlib.util.spec_from_file_location('void_installer', SCRIPT)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.resource = self.base / 'ox_inventory'
        self.resource.mkdir()
        self.manifest = self.resource / 'fxmanifest.lua'
        self.original = b"fx_version 'cerulean'\r\ngame 'gta5'\r\n-- custom line retained\r\nshared_script 'my_config.lua'\r\n"
        self.manifest.write_bytes(self.original)
        for name in ['modules/items/shared.lua', 'modules/inventory/server.lua']:
            path = self.resource / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('return {}\n')
        self.source = self.base / 'void_currency.lua'
        self.source.write_text('-- tested addon fixture\nreturn true\n')
        self.addon = self.resource / 'void_currency.lua'
        self.backup = self.resource / installer.BACKUP_NAME

    def snapshot(self):
        return {str(p.relative_to(self.resource)): p.read_bytes()
                for p in self.resource.rglob('*') if p.is_file()}

    def run_install(self):
        return installer.install(self.resource, self.source)

    def test_install_preserves_custom_manifest_crlf_and_makes_exact_backup(self):
        self.run_install()
        actual = self.manifest.read_bytes()
        self.assertTrue(actual.startswith(self.original))
        self.assertEqual(self.backup.read_bytes(), self.original)
        self.assertEqual(self.addon.read_bytes(), self.source.read_bytes())
        self.assertEqual(actual.count(installer.START), 1)
        self.assertIn(b"void_currency '1.0.0'\r\n", actual)
        self.assertIn(b"client_script 'void_currency.lua'\r\n", actual)
        self.assertIn(b"server_script 'void_currency.lua'\r\n", actual)
        self.assertNotIn(b'\n', actual.replace(b'\r\n', b''))

    def test_second_run_is_idempotent_without_touching_files_or_backup(self):
        self.run_install()
        first = self.snapshot()
        times = {p: p.stat().st_mtime_ns for p in self.resource.rglob('*') if p.is_file()}
        self.assertIn('già installata', self.run_install())
        self.assertEqual(self.snapshot(), first)
        self.assertEqual(times, {p: p.stat().st_mtime_ns for p in self.resource.rglob('*') if p.is_file()})

    def test_unknown_preexisting_addon_is_not_overwritten(self):
        self.addon.write_text('-- somebody else\n')
        before = self.snapshot()
        with self.assertRaisesRegex(installer.InstallError, 'contenuto diverso'):
            self.run_install()
        self.assertEqual(self.snapshot(), before)

    def test_existing_backup_is_never_overwritten_for_unmarked_install(self):
        self.backup.write_bytes(b'user backup')
        before = self.snapshot()
        with self.assertRaisesRegex(installer.InstallError, 'Backup già presente'):
            self.run_install()
        self.assertEqual(self.snapshot(), before)

    def test_missing_required_module_causes_no_mutations(self):
        (self.resource / 'modules/items/shared.lua').unlink()
        before = self.snapshot()
        with self.assertRaisesRegex(installer.InstallError, 'File richiesto assente'):
            self.run_install()
        self.assertEqual(self.snapshot(), before)

    def test_managed_but_missing_addon_can_be_repaired_without_replacing_backup(self):
        self.run_install()
        old_manifest, old_backup = self.manifest.read_bytes(), self.backup.read_bytes()
        self.addon.unlink()
        self.assertIn('ripristinato', self.run_install())
        self.assertEqual(self.manifest.read_bytes(), old_manifest)
        self.assertEqual(self.backup.read_bytes(), old_backup)
        self.assertEqual(self.addon.read_bytes(), self.source.read_bytes())

    def test_incomplete_marker_and_unknown_declarations_are_refused(self):
        for extra in [installer.START, b"client_script 'void_currency.lua'", b"void_currency '0.9.0'"]:
            with self.subTest(extra=extra):
                self.manifest.write_bytes(self.original + extra + b'\n')
                before = self.snapshot()
                with self.assertRaises(installer.InstallError):
                    self.run_install()
                self.assertEqual(self.snapshot(), before)

    def test_metadata_tab_and_call_syntax_are_refused_without_changes(self):
        for declaration in [b"void_currency\t'0.9.0'", b"void_currency('0.9.0')"]:
            with self.subTest(declaration=declaration):
                self.manifest.write_bytes(self.original + declaration + b'\n')
                before = self.snapshot()
                with self.assertRaisesRegex(installer.InstallError, 'dichiarazioni Void non gestite'):
                    self.run_install()
                self.assertEqual(self.snapshot(), before)

    def test_failure_before_manifest_replace_restores_all_original_files(self):
        before = self.snapshot()
        real_write = installer._atomic_write
        def fail_manifest(path, *args):
            if path == self.manifest:
                raise OSError('injected manifest write failure')
            return real_write(path, *args)
        with patch.object(installer, '_atomic_write', side_effect=fail_manifest):
            with self.assertRaisesRegex(installer.InstallError, 'originali ripristinati'):
                self.run_install()
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(list(self.resource.glob('.void-currency-*')), [])

    def test_failure_after_manifest_replace_also_restores_originals(self):
        before = self.snapshot()
        real_write = installer._atomic_write
        failed = False
        def fail_once_after_replace(path, *args):
            nonlocal failed
            real_write(path, *args)
            if path == self.manifest and not failed:
                failed = True
                raise OSError('injected failure after replace')
        with patch.object(installer, '_atomic_write', side_effect=fail_once_after_replace):
            with self.assertRaisesRegex(installer.InstallError, 'originali ripristinati'):
                self.run_install()
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(list(self.resource.glob('.void-currency-*')), [])

    def test_same_existing_addon_is_preserved_during_first_install(self):
        self.addon.write_bytes(self.source.read_bytes())
        old_time = self.addon.stat().st_mtime_ns
        self.run_install()
        self.assertEqual(self.addon.stat().st_mtime_ns, old_time)
        self.assertEqual(self.backup.read_bytes(), self.original)

    def test_symlink_module_and_target_file_are_refused(self):
        outside = self.base / 'outside.lua'
        outside.write_text('-- untouched\n')
        try:
            self.addon.symlink_to(outside)
        except OSError:
            self.skipTest('symlink not supported')
        with self.assertRaisesRegex(installer.InstallError, 'collegamento simbolico'):
            self.run_install()
        self.assertEqual(outside.read_text(), '-- untouched\n')
        self.assertFalse(self.backup.exists())
        self.addon.unlink()
        module = self.resource / 'modules/items/shared.lua'
        module.unlink()
        module.symlink_to(outside)
        with self.assertRaisesRegex(installer.InstallError, 'collegamento simbolico'):
            self.run_install()
        self.assertFalse(self.addon.exists())
        self.assertFalse(self.backup.exists())

    def test_newline_missing_at_end_is_preserved_as_prefix(self):
        self.original = b"fx_version 'cerulean'\ngame 'gta5'\n-- final comment"
        self.manifest.write_bytes(self.original)
        self.run_install()
        self.assertTrue(self.manifest.read_bytes().startswith(self.original + b'\n\n'))
        self.assertEqual(self.backup.read_bytes(), self.original)


if __name__ == '__main__':
    unittest.main(verbosity=2)
