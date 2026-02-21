#!/usr/bin/env python3
"""Build and validate MemoFlow update config from split files.

Directory layout (default root: update_config):
  manifest.json
  donors.json (optional)
  announcements/{id}.json

`manifest.json` keeps global fields and index pointers:
  - schema_version
  - version_info
  - notice_enabled / notice / debug_announcement / debug_announcement_source
  - donors_file (optional, default: donors.json)
  - announcement_ids (list[int|string])
  - latest_announcement_id (int|string)
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
from copy import deepcopy
from typing import Any, Dict, List, Tuple


class ConfigError(Exception):
    pass


def _read_json(path: pathlib.Path) -> Dict[str, Any]:
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ConfigError(f"failed reading {path}: {exc}") from exc
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ConfigError(f"invalid json in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ConfigError(f"json object required in {path}")
    return data


def _read_json_list(path: pathlib.Path) -> List[Any]:
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ConfigError(f"failed reading {path}: {exc}") from exc
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ConfigError(f"invalid json in {path}: {exc}") from exc
    if not isinstance(data, list):
        raise ConfigError(f"json array required in {path}")
    return data


def _normalize_id(value: Any, *, where: str) -> str:
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        text = value.strip()
        if text.isdigit():
            return text
    raise ConfigError(f"invalid announcement id in {where}: {value!r}")


def _load_announcements(
    root: pathlib.Path,
    ids: List[str],
) -> Dict[str, Dict[str, Any]]:
    announcements: Dict[str, Dict[str, Any]] = {}
    ann_dir = root / "announcements"
    for ann_id in ids:
        path = ann_dir / f"{ann_id}.json"
        if not path.exists():
            raise ConfigError(f"missing announcement file: {path}")
        data = _read_json(path)
        file_id = _normalize_id(data.get("id"), where=str(path))
        if file_id != ann_id:
            raise ConfigError(
                f"announcement id mismatch in {path}: expected {ann_id}, got {file_id}"
            )
        announcements[ann_id] = data
    return announcements


def _build_release_note(entry: Dict[str, Any]) -> Dict[str, Any] | None:
    version = str(entry.get("version", "")).strip()
    date_label = str(entry.get("date", "")).strip()
    items = entry.get("items")
    if not isinstance(items, list):
        items = []
    normalized_items: List[Dict[str, Any]] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        category = str(item.get("category", "")).strip()
        contents = item.get("contents")
        if isinstance(contents, str):
            contents_list = [contents.strip()] if contents.strip() else []
        elif isinstance(contents, list):
            contents_list = [
                str(x).strip() for x in contents if str(x).strip()
            ]
        else:
            contents_list = []
        if not category and not contents_list:
            continue
        normalized_items.append(
            {
                "category": category,
                "contents": contents_list,
            }
        )
    if not version and not normalized_items:
        return None
    return {
        "version": version,
        "date": date_label,
        "items": normalized_items,
    }


def _apply_overrides(
    merged: Dict[str, Any],
    *,
    tag_version: str,
    android_url: str,
    ios_url: str,
    windows_url: str,
    android_version: str,
    ios_version: str,
    windows_version: str,
) -> None:
    version_info = merged.get("version_info")
    if not isinstance(version_info, dict):
        return

    def get_platform(name: str) -> Dict[str, Any] | None:
        value = version_info.get(name)
        if isinstance(value, dict):
            return value
        return None

    def set_nonempty(target: Dict[str, Any] | None, key: str, value: str) -> None:
        if target is None:
            return
        text = value.strip()
        if text:
            target[key] = text

    android = get_platform("android")
    ios = get_platform("ios")
    windows = get_platform("windows")

    set_nonempty(android, "url", android_url)
    set_nonempty(ios, "url", ios_url)
    set_nonempty(windows, "url", windows_url)

    set_nonempty(android, "latest_version", android_version)
    set_nonempty(ios, "latest_version", ios_version)
    set_nonempty(windows, "latest_version", windows_version)

    tag_text = tag_version.strip()
    if tag_text:
        if android is not None and android_url.strip() and not android_version.strip():
            android["latest_version"] = tag_text
        if windows is not None and windows_url.strip() and not windows_version.strip():
            windows["latest_version"] = tag_text
        if ios is not None and ios_url.strip() and not ios_version.strip():
            ios["latest_version"] = tag_text


def compile_update_config(root: pathlib.Path) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    manifest_path = root / "manifest.json"
    if not manifest_path.exists():
        raise ConfigError(f"manifest file not found: {manifest_path}")
    manifest = _read_json(manifest_path)

    announcement_ids_raw = manifest.get("announcement_ids")
    if not isinstance(announcement_ids_raw, list) or not announcement_ids_raw:
        raise ConfigError("manifest.announcement_ids must be a non-empty array")
    announcement_ids = [
        _normalize_id(value, where="manifest.announcement_ids")
        for value in announcement_ids_raw
    ]
    if len(set(announcement_ids)) != len(announcement_ids):
        raise ConfigError("manifest.announcement_ids contains duplicates")

    latest_raw = manifest.get("latest_announcement_id")
    latest_announcement_id = _normalize_id(latest_raw, where="manifest.latest_announcement_id")
    if latest_announcement_id not in announcement_ids:
        raise ConfigError(
            f"manifest.latest_announcement_id={latest_announcement_id} is not in announcement_ids"
        )

    announcements = _load_announcements(root, announcement_ids)

    donors_file = str(manifest.get("donors_file", "donors.json")).strip()
    donors: List[Any] = []
    if donors_file:
        donors_path = root / donors_file
        if donors_path.exists():
            donors = _read_json_list(donors_path)
        elif donors_file != "donors.json":
            raise ConfigError(f"manifest.donors_file not found: {donors_path}")

    active = announcements[latest_announcement_id]
    release_notes: List[Dict[str, Any]] = []
    for ann_id in announcement_ids:
        note = _build_release_note(announcements[ann_id])
        if note is not None:
            release_notes.append(note)

    merged = deepcopy(manifest)
    merged.pop("announcement_ids", None)
    merged.pop("latest_announcement_id", None)
    merged.pop("donors_file", None)
    merged.pop("announcement_tag_index", None)

    merged["announcement"] = {
        "id": latest_announcement_id,
        "title": str(active.get("title", "")).strip(),
        "show_when_up_to_date": bool(active.get("show_when_up_to_date", False)),
        "contents": active.get("contents", {}),
        "new_donor_ids": active.get("new_donor_ids", []),
    }
    merged["donors"] = donors
    merged["release_notes"] = release_notes

    summary = {
        "announcement_ids": announcement_ids,
        "latest_announcement_id": latest_announcement_id,
        "release_notes_count": len(release_notes),
        "donors_count": len(donors),
    }
    return merged, summary


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build MemoFlow update config")
    parser.add_argument("--root", default="update_config", help="config root directory")
    parser.add_argument("--output", default="dist/update/latest.json", help="output json path")
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="validate split files only; do not write output",
    )
    parser.add_argument("--tag-version", default="", help="release tag version (without leading v)")
    parser.add_argument("--android-url", default="", help="override android url")
    parser.add_argument("--ios-url", default="", help="override ios url")
    parser.add_argument("--windows-url", default="", help="override windows url")
    parser.add_argument("--android-version", default="", help="override android latest_version")
    parser.add_argument("--ios-version", default="", help="override ios latest_version")
    parser.add_argument("--windows-version", default="", help="override windows latest_version")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = pathlib.Path(args.root).resolve()
    try:
        merged, summary = compile_update_config(root)
        _apply_overrides(
            merged,
            tag_version=args.tag_version,
            android_url=args.android_url,
            ios_url=args.ios_url,
            windows_url=args.windows_url,
            android_version=args.android_version,
            ios_version=args.ios_version,
            windows_version=args.windows_version,
        )
    except ConfigError as exc:
        print(f"[update-config] error: {exc}", file=sys.stderr)
        return 1

    print(
        "[update-config] validated: "
        f"announcements={len(summary['announcement_ids'])}, "
        f"latest={summary['latest_announcement_id']}, "
        f"release_notes={summary['release_notes_count']}, "
        f"donors={summary['donors_count']}"
    )

    if args.validate_only:
        return 0

    output = pathlib.Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        output.write_text(
            json.dumps(merged, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    except OSError as exc:
        print(f"[update-config] write failed: {exc}", file=sys.stderr)
        return 1

    print(f"[update-config] built: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
