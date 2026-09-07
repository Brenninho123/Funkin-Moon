"""
Incrementa o BUILD_NUMBER dentro do project.hxp em +1 toda vez que roda.

Uso:
    python bump_build.py

Ou encadeado antes do lime test (Windows, cmd/powershell):
    python bump_build.py && lime test windows
    python bump_build.py && lime test windows -debug

Procura a linha:
    static final BUILD_NUMBER:Int = 107;
e troca o número por +1, preservando o resto da linha exatamente igual.
"""

import re
import sys
from pathlib import Path

PROJECT_HXP = Path(__file__).resolve().parent.parent / "project.hxp"
PATTERN = re.compile(r'(static\s+final\s+BUILD_NUMBER\s*:\s*Int\s*=\s*)(\d+)(\s*;)')


def bump_build_number(path: Path) -> int:
    if not path.exists():
        print(f"[bump_build] ERRO: não achei {path.resolve()}")
        sys.exit(1)

    text = path.read_text(encoding="utf-8")
    match = PATTERN.search(text)

    if not match:
        print("[bump_build] ERRO: não achei a linha 'static final BUILD_NUMBER:Int = ...;' no project.hxp")
        sys.exit(1)

    old_number = int(match.group(2))
    new_number = old_number + 1

    new_text = text[:match.start()] + match.group(1) + str(new_number) + match.group(3) + text[match.end():]
    path.write_text(new_text, encoding="utf-8")

    return old_number, new_number


if __name__ == "__main__":
    old_number, new_number = bump_build_number(PROJECT_HXP)
    print(f"[bump_build] BUILD_NUMBER: {old_number} -> {new_number}")
