#!/usr/bin/env python3
"""Install the Void currency addon into an existing ox_inventory resource."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import stat
import sys
import tempfile


START = b"-- BEGIN VOID SURVIVAL CURRENCY PATCH"
END = b"-- END VOID SURVIVAL CURRENCY PATCH"
BLOCK = b"\n".join((
    START,
    b"client_script 'void_currency.lua'",
    b"server_script 'void_currency.lua'",
    b"void_currency '1.0.0'",
    END,
))
BACKUP_NAME = "fxmanifest.lua.before-void-currency"


class InstallError(Exception):
    """A validation or recoverable installation failure."""


def _regular_file(root: Path, relative: str, *, optional: bool = False) -> Path:
    path = root
    for part in Path(relative).parts:
        path /= part
        if path.is_symlink():
            raise InstallError(f"Rifiutato collegamento simbolico: {path}")
    if path.exists() and not path.is_file():
        raise InstallError(f"Non è un file: {path}")
    if not optional and not path.is_file():
        raise InstallError(f"File richiesto assente: {path}")
    return path


def _atomic_write(path: Path, data: bytes, mode: int) -> None:
    descriptor, name = tempfile.mkstemp(prefix=".void-currency-", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            os.chmod(temporary, mode)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _exclusive_backup(path: Path, data: bytes, mode: int) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        path.unlink(missing_ok=True)
        raise


def _marked_manifest(data: bytes) -> bool:
    normalized = data.replace(b"\r\n", b"\n")
    if START in normalized or END in normalized:
        if normalized.count(START) != 1 or normalized.count(END) != 1:
            raise InstallError("Blocco Void incompleto o duplicato nel manifest; nessuna modifica eseguita.")
        start = normalized.index(START)
        end = normalized.index(END) + len(END)
        if normalized[start:end] != BLOCK:
            raise InstallError("Blocco Void diverso da quello previsto; revisione manuale necessaria.")
        return True
    if b"void_currency.lua" in normalized or re.search(rb"\bvoid_currency\b", normalized):
        raise InstallError("Il manifest contiene già dichiarazioni Void non gestite; revisione manuale necessaria.")
    return False


def install(resource_directory: Path, source: Path | None = None) -> str:
    root = Path(resource_directory).expanduser().resolve(strict=True)
    if not root.is_dir():
        raise InstallError(f"La risorsa non è una directory: {root}")
    manifest = _regular_file(root, "fxmanifest.lua")
    _regular_file(root, "modules/items/shared.lua")
    _regular_file(root, "modules/inventory/server.lua")
    addon = _regular_file(root, "void_currency.lua", optional=True)
    backup = _regular_file(root, BACKUP_NAME, optional=True)

    source = Path(source) if source is not None else Path(__file__).resolve().with_name("void_currency.lua")
    if source.is_symlink() or not source.is_file():
        raise InstallError(f"Addon sorgente assente o non regolare: {source}")
    payload = source.read_bytes()
    if not payload:
        raise InstallError("L'addon sorgente è vuoto.")

    original = manifest.read_bytes()
    if not original.strip() or b"\x00" in original:
        raise InstallError("Manifest vuoto o non testuale; nessuna modifica eseguita.")
    marked = _marked_manifest(original)
    old_addon = addon.read_bytes() if addon.exists() else None
    if old_addon is not None and old_addon != payload:
        raise InstallError("void_currency.lua esiste già con contenuto diverso: non viene sovrascritto.")
    if not marked and backup.exists():
        raise InstallError(f"Backup già presente: {backup}. Non viene sovrascritto; verifica l'installazione precedente.")

    if marked and old_addon is not None:
        return "Patch Void già installata; nessun file modificato."

    newline = b"\r\n" if b"\r\n" in original else b"\n"
    block = BLOCK.replace(b"\n", newline)
    separator = newline if original.endswith((b"\n", b"\r")) else newline + newline
    updated = original if marked else original + separator + block + newline
    manifest_mode = stat.S_IMODE(manifest.stat().st_mode) & 0o777
    backup_created = False
    try:
        if not marked:
            _exclusive_backup(backup, original, manifest_mode)
            backup_created = True
        if old_addon is None:
            _atomic_write(addon, payload, 0o644)
        if not marked:
            if manifest.read_bytes() != original:
                raise InstallError("Il manifest è cambiato durante l'installazione; riprova dopo la revisione.")
            _atomic_write(manifest, updated, manifest_mode)
    except BaseException as error:
        failures = []
        try:
            current = manifest.read_bytes()
            if current == updated and current != original:
                _atomic_write(manifest, original, manifest_mode)
            elif current != original:
                failures.append("manifest modificato da un'altra operazione: preservato")
        except Exception as rollback_error:
            failures.append(f"ripristino manifest: {rollback_error}")
        try:
            if old_addon is None and addon.exists():
                if addon.read_bytes() == payload:
                    addon.unlink()
                else:
                    failures.append("addon modificato da un'altra operazione: preservato")
        except Exception as rollback_error:
            failures.append(f"rimozione addon: {rollback_error}")
        if backup_created and not failures:
            try:
                backup.unlink()
            except Exception as rollback_error:
                failures.append(f"rimozione backup: {rollback_error}")
        if failures:
            raise InstallError(f"Installazione interrotta ({error}). Ripristino da verificare: {'; '.join(failures)}. Backup: {backup}") from error
        if isinstance(error, (KeyboardInterrupt, SystemExit)):
            raise
        raise InstallError(f"Installazione annullata e file originali ripristinati: {error}") from error

    if marked:
        return "Addon Void ripristinato; manifest già configurato."
    return f"Patch Void installata. Backup del manifest: {backup}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Installa la patch Void in una risorsa ox_inventory esistente.")
    parser.add_argument("ox_inventory", type=Path, help="Percorso della directory ox_inventory")
    arguments = parser.parse_args()
    try:
        print(install(arguments.ox_inventory))
        return 0
    except (InstallError, OSError) as error:
        print(f"Errore: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
