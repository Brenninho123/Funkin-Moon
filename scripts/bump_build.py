import argparse
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
PROJECT_HXP = ROOT_DIR / "project.hxp"
CONSTANTS_HX = ROOT_DIR / "source" / "funkin" / "util" / "Constants.hx"
BUILD_INFO_JSON = ROOT_DIR / "build-info.json"

BUILD_PATTERN = re.compile(r"(static\s+final\s+BUILD_NUMBER\s*:\s*Int\s*=\s*)(\d+)(\s*;)")
MOON_VERSION_PATTERN = re.compile(r"(static\s+final\s+MOON_VERSION\s*:\s*String\s*=\s*['\"])([^'\"]+)(['\"]\s*;)")
CONSTANTS_MOON_VERSION_PATTERN = re.compile(r"(return\s+#if\s+\(MOON_VERSION\)\s+MOON_VERSION\s+#else\s+['\"])([^'\"]+)(['\"]\s+#end\s*;)")
CONSTANTS_BUILD_NUMBER_PATTERN = re.compile(r"(return\s+#if\s+\(BUILD_NUMBER\)\s+BUILD_NUMBER\s+#else\s+['\"])(\d+)(['\"]\s+#end\s*;)")
SEMVER_PATTERN = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


class BumpError(Exception):
    pass


def read_file(path: Path) -> str:
    if not path.exists():
        raise BumpError(f"File not found: {path.resolve()}")
    return path.read_text(encoding="utf-8")


def parse_semver(version: str):
    match = SEMVER_PATTERN.match(version.strip())
    if not match:
        raise BumpError(f"MOON_VERSION is not valid semver: '{version}'")
    return tuple(int(part) for part in match.groups())


def format_semver(major: int, minor: int, patch: int) -> str:
    return f"{major}.{minor}.{patch}"


def bump_semver(version: str, level: str) -> str:
    major, minor, patch = parse_semver(version)

    if level == "major":
        major, minor, patch = major + 1, 0, 0
    elif level == "minor":
        minor, patch = minor + 1, 0
    elif level == "patch":
        patch += 1
    else:
        raise BumpError(f"Unknown bump level: {level}")

    return format_semver(major, minor, patch)


def backup_file(path: Path) -> Path:
    backup_path = path.with_suffix(path.suffix + ".bak")
    shutil.copy2(path, backup_path)
    return backup_path


def restore_backup(path: Path, backup_path: Path):
    if backup_path.exists():
        shutil.copy2(backup_path, path)


def discard_backup(backup_path: Path):
    if backup_path.exists():
        backup_path.unlink()


def read_project_state(path: Path):
    text = read_file(path)

    build_match = BUILD_PATTERN.search(text)
    if not build_match:
        raise BumpError("Could not find 'static final BUILD_NUMBER:Int = ...;' in project.hxp")

    moon_match = MOON_VERSION_PATTERN.search(text)
    if not moon_match:
        raise BumpError("Could not find 'static final MOON_VERSION:String = ...;' in project.hxp")

    return text, int(build_match.group(2)), moon_match.group(2)


def write_project(path: Path, text: str, new_build: int, new_version: str, dry_run: bool):
    build_match = BUILD_PATTERN.search(text)
    new_text = (
        text[:build_match.start()]
        + build_match.group(1)
        + str(new_build)
        + build_match.group(3)
        + text[build_match.end():]
    )

    moon_match = MOON_VERSION_PATTERN.search(new_text)
    new_text = (
        new_text[:moon_match.start()]
        + moon_match.group(1)
        + new_version
        + moon_match.group(3)
        + new_text[moon_match.end():]
    )

    if not dry_run:
        path.write_text(new_text, encoding="utf-8")

    return new_text


def write_constants(path: Path, moon_version: str, build_number: int, dry_run: bool):
    text = read_file(path)

    moon_match = CONSTANTS_MOON_VERSION_PATTERN.search(text)
    if not moon_match:
        raise BumpError("Could not find MOON_VERSION fallback in Constants.hx")

    new_text = (
        text[:moon_match.start()]
        + moon_match.group(1)
        + moon_version
        + moon_match.group(3)
        + text[moon_match.end():]
    )

    build_match = CONSTANTS_BUILD_NUMBER_PATTERN.search(new_text)
    if not build_match:
        raise BumpError("Could not find BUILD_NUMBER fallback in Constants.hx")

    new_text = (
        new_text[:build_match.start()]
        + build_match.group(1)
        + str(build_number)
        + build_match.group(3)
        + new_text[build_match.end():]
    )

    if not dry_run:
        path.write_text(new_text, encoding="utf-8")

    return new_text


def write_build_info(path: Path, moon_version: str, old_build: int, new_build: int, bump_level: str, dry_run: bool):
    entry = {
        "moonVersion": moon_version,
        "oldBuildNumber": old_build,
        "newBuildNumber": new_build,
        "bumpLevel": bump_level,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

    history = []
    if path.exists():
        try:
            history = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(history, list):
                history = []
        except (json.JSONDecodeError, OSError):
            history = []

    history.append(entry)

    if not dry_run:
        path.write_text(json.dumps(history, indent=2), encoding="utf-8")

    return entry


def parse_args():
    parser = argparse.ArgumentParser(description="Bump MOON_VERSION and BUILD_NUMBER for Funkin-Moon")
    parser.add_argument("--major", action="store_true")
    parser.add_argument("--minor", action="store_true")
    parser.add_argument("--patch", action="store_true")
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def resolve_bump_level(args) -> str:
    selected = [name for name, flag in (("major", args.major), ("minor", args.minor), ("patch", args.patch)) if flag]

    if len(selected) > 1:
        raise BumpError("Only one of --major, --minor, --patch can be used at a time")

    if args.build_only:
        return "build-only"

    return selected[0] if selected else "build-only"


def main():
    args = parse_args()

    try:
        bump_level = resolve_bump_level(args)
    except BumpError as error:
        print(f"[bump_build] ERROR: {error}")
        sys.exit(1)

    project_backup = None
    constants_backup = None

    try:
        project_text, old_build, moon_version = read_project_state(PROJECT_HXP)
        new_build = old_build + 1

        new_version = moon_version if bump_level == "build-only" else bump_semver(moon_version, bump_level)

        if not args.dry_run:
            project_backup = backup_file(PROJECT_HXP)
            constants_backup = backup_file(CONSTANTS_HX)

        write_project(PROJECT_HXP, project_text, new_build, new_version, args.dry_run)
        write_constants(CONSTANTS_HX, new_version, new_build, args.dry_run)
        write_build_info(BUILD_INFO_JSON, new_version, old_build, new_build, bump_level, args.dry_run)

        if not args.dry_run:
            discard_backup(project_backup)
            discard_backup(constants_backup)

        prefix = "[bump_build] (dry-run)" if args.dry_run else "[bump_build]"
        print(f"{prefix} MOON_VERSION: {moon_version} -> {new_version}")
        print(f"{prefix} BUILD_NUMBER: {old_build} -> {new_build}")
        print(f"{prefix} Constants.hx synchronized.")

    except BumpError as error:
        if project_backup is not None:
            restore_backup(PROJECT_HXP, project_backup)
            discard_backup(project_backup)
        if constants_backup is not None:
            restore_backup(CONSTANTS_HX, constants_backup)
            discard_backup(constants_backup)

        print(f"[bump_build] ERROR: {error}")
        sys.exit(1)

    except Exception as error:
        if project_backup is not None:
            restore_backup(PROJECT_HXP, project_backup)
            discard_backup(project_backup)
        if constants_backup is not None:
            restore_backup(CONSTANTS_HX, constants_backup)
            discard_backup(constants_backup)

        print(f"[bump_build] UNEXPECTED ERROR: {error}")
        sys.exit(1)


if __name__ == "__main__":
    main()
