"""
Incrementa o BUILD_NUMBER dentro do project.hxp em +1 toda vez que roda
e sincroniza MOON_VERSION e BUILD_NUMBER com Constants.hx.

Uso:

    python bump_build.py

Ou encadeado antes do lime test:

    python bump_build.py && lime test windows

    python bump_build.py && lime test windows -debug
"""

import re
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent

PROJECT_HXP = ROOT_DIR / "project.hxp"
CONSTANTS_HX = ROOT_DIR / "source" / "funkin" / "util" / "Constants.hx"


BUILD_PATTERN = re.compile(
    r"(static\s+final\s+BUILD_NUMBER\s*:\s*Int\s*=\s*)(\d+)(\s*;)"
)

MOON_VERSION_PATTERN = re.compile(
    r"(static\s+final\s+MOON_VERSION\s*:\s*String\s*=\s*['\"])([^'\"]+)(['\"]\s*;)"
)

CONSTANTS_MOON_VERSION_PATTERN = re.compile(
    r"(return\s+#if\s+\(MOON_VERSION\)\s+MOON_VERSION\s+#else\s+['\"])([^'\"]+)(['\"]\s+#end\s*;)"
)

CONSTANTS_BUILD_NUMBER_PATTERN = re.compile(
    r"(return\s+#if\s+\(BUILD_NUMBER\)\s+BUILD_NUMBER\s+#else\s+['\"])(\d+)(['\"]\s+#end\s*;)"
)


def read_file(path: Path) -> str:
    if not path.exists():
        print(f"[bump_build] ERRO: não achei {path.resolve()}")
        sys.exit(1)

    return path.read_text(encoding="utf-8")


def update_project(path: Path):
    text = read_file(path)

    build_match = BUILD_PATTERN.search(text)
    if not build_match:
        print(
            "[bump_build] ERRO: não achei "
            "'static final BUILD_NUMBER:Int = ...;' no project.hxp"
        )
        sys.exit(1)

    moon_match = MOON_VERSION_PATTERN.search(text)
    if not moon_match:
        print(
            "[bump_build] ERRO: não achei "
            "'static final MOON_VERSION:String = ...;' no project.hxp"
        )
        sys.exit(1)

    old_build = int(build_match.group(2))
    new_build = old_build + 1

    moon_version = moon_match.group(2)

    # Atualiza somente o número do BUILD_NUMBER,
    # preservando o restante da linha.
    new_text = (
        text[:build_match.start()]
        + build_match.group(1)
        + str(new_build)
        + build_match.group(3)
        + text[build_match.end():]
    )

    path.write_text(new_text, encoding="utf-8")

    return moon_version, old_build, new_build


def update_constants(path: Path, moon_version: str, build_number: int):
    text = read_file(path)

    moon_match = CONSTANTS_MOON_VERSION_PATTERN.search(text)
    if not moon_match:
        print(
            "[bump_build] ERRO: não achei o fallback "
            "MOON_VERSION no Constants.hx"
        )
        sys.exit(1)

    build_match = CONSTANTS_BUILD_NUMBER_PATTERN.search(text)
    if not build_match:
        print(
            "[bump_build] ERRO: não achei o fallback "
            "BUILD_NUMBER no Constants.hx"
        )
        sys.exit(1)

    # Sincroniza MOON_VERSION.
    new_text = (
        text[:moon_match.start()]
        + moon_match.group(1)
        + moon_version
        + moon_match.group(3)
        + text[moon_match.end():]
    )

    # Procura novamente depois da alteração anterior.
    build_match = CONSTANTS_BUILD_NUMBER_PATTERN.search(new_text)

    if not build_match:
        print(
            "[bump_build] ERRO: não consegui localizar "
            "BUILD_NUMBER após atualizar MOON_VERSION."
        )
        sys.exit(1)

    # Sincroniza BUILD_NUMBER.
    new_text = (
        new_text[:build_match.start()]
        + build_match.group(1)
        + str(build_number)
        + build_match.group(3)
        + new_text[build_match.end():]
    )

    path.write_text(new_text, encoding="utf-8")


if __name__ == "__main__":
    moon_version, old_build, new_build = update_project(PROJECT_HXP)

    update_constants(
        CONSTANTS_HX,
        moon_version,
        new_build
    )

    print(f"[bump_build] MOON_VERSION: {moon_version}")
    print(f"[bump_build] BUILD_NUMBER: {old_build} -> {new_build}")
    print("[bump_build] Constants.hx sincronizado.")
