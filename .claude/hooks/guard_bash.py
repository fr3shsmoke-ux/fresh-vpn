"""PreToolUse: Bash|PowerShell — периметр команд продуктового репозитория.

Что покрыто: цели записи И удаления (перенаправления разбираются грамматикой,
команды — перечнем ролей), запись вне дерева, файлы окружения и ключей, объекты
из `.claude/protected_objects.json`, секрет-скан перед коммитом, pipe-to-shell.

Чего здесь НЕТ и почему:
  * запрета `git push` — в продуктовом репозитории публикация есть штатная
    работа, а не Фаза D управляющего контура;
  * правил про канон — канона в продуктовом дереве не существует.

Граница, названная сразу: гард читает ТЕКСТ команды. Путь, собранный в рантайме,
в тексте не появляется — недостижимость даёт только уровень ОС.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _hooklib import (BS, SECRET_FILE, allow, call_cwd, deny, is_protected, log_event,
                      отметить_права, целостность,
                      outside_allowed, outside_repo, project_dir, read_input, segments,
                      has_write, write_targets)

RULES: list[tuple[re.Pattern, str]] = [
    (re.compile(r"(curl|wget|iwr|Invoke-WebRequest|irm|Invoke-RestMethod)\b.*\|\s*(sh|bash|zsh|iex|powershell)\b",
                re.I),
     "[hook:bash] pipe-to-shell запрещён (supply chain): скачай, покажи, дождись решения, потом исполняй."),
    (re.compile(r"(\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\b|Remove-Item\b(?=.*-Recurse))"
                r"(?=.*(\.git\b|[A-Za-z]:[/" + BS + BS + r"]\s*$|\s/\s*$))", re.I),
     "[hook:bash] Рекурсивное удаление по критическому пути (.git, корень диска) запрещено."),
]


def hits_protected(targets: list[str], base: str) -> bool:
    return any(is_protected(t.replace(BS, "/"), base) for t in targets)


def hits_secret_file(targets: list[str]) -> bool:
    return any(SECRET_FILE.search(tok.replace(BS, "/")) for tok in targets)


def hits_outside(targets: list[str], base: str, cwd: str = "") -> bool:
    """Рабочий каталог вызова передаётся ОБОИМ предикатам.

    Разрешающая и запрещающая половины обязаны разворачивать путь одинаково:
    расхождение между ними и есть та щель, в которую проходил `..`-выход.
    """
    for tok in targets:
        if outside_allowed(tok, base, cwd):
            continue
        if outside_repo(tok, base, cwd):
            return True
    return False


def _staged_secret_scan(base: str) -> str | None:
    """Секрет в staged-изменениях останавливает коммит: единственный момент,
    когда его ещё можно убрать без переписывания истории."""
    try:
        # ФОРМА ВЫВОДА ЧУЖОГО ИНСТРУМЕНТА ЗАКРЕПЛЯЕТСЯ, А НЕ ПРЕДПОЛАГАЕТСЯ (М-23).
        # Находка агента панели 06.09: по умолчанию git ЭКРАНИРУЕТ не-ASCII в
        # именах путей и берёт их в кавычки — «"src/\320\272..."». Следующий
        # `git show :<имя>` падал с кодом 128, а падение читалось как «чисто»
        # (М-14: упавшая проверка есть отсутствие проверки). Измерено на одном
        # образце: имя латиницей — находка, то же имя кириллицей — None.
        # В деревьях холдинга кириллические имена норма, и сама сеть на секреты
        # называется `сеть_на_секреты.py`: скан не увидел бы и её.
        #
        # `-z` снимает кавычки и экранирование целиком; `--diff-filter=ACMRT`
        # убирает снятия с учёта — их содержимое никуда не входит, а `git show`
        # по снятому имени падает штатно и не должен запрещать коммит.
        names = subprocess.run(["git", "-c", "core.quotepath=false", "diff", "--cached",
                                "-z", "--name-only", "--diff-filter=ACMRT"], cwd=base,
                               capture_output=True, text=True, timeout=15)
        if names.returncode != 0:
            return None
        for rel in (names.stdout or "").split(chr(0)):
            rel = rel.strip()
            if not rel:
                continue
            body = subprocess.run(["git", "show", ":" + rel], cwd=base,
                                  capture_output=True, text=True, timeout=15)
            if body.returncode != 0:
                # ПАДЕНИЕ ЗАПРЕЩАЕТ. Прежняя редакция здесь стояла `continue` —
                # файл, содержимое которого не прочитано, считался чистым.
                return ("%s: содержимое не прочитано (git show, код %d) — "
                        "упавшая проверка есть отсутствие проверки" % (rel, body.returncode))
            from _hooklib import find_secrets
            hits = find_secrets(body.stdout or "")
            if hits:
                return f"{rel}: {', '.join(hits)}"
    except Exception:
        return None
    return None


def decide(data: dict, base: str) -> tuple[bool, str]:
    cmd = str((data.get("tool_input", {}) or {}).get("command", ""))
    cwd = call_cwd(data)
    if not cmd.strip():
        return True, ""
    for rx, msg in RULES:
        if rx.search(cmd):
            log_event(base, "guard_bash", rx.pattern[:40], "deny")
            return False, msg
    for seg in segments(cmd):
        if not has_write(seg):
            continue
        targets = write_targets(seg)
        if not targets:
            continue
        if hits_protected(targets, base):
            log_event(base, "guard_bash", "protected_write", "deny", " ".join(targets))
            return False, ("[hook:bash] Команда пишет или удаляет объект из "
                           ".claude/protected_objects.json — обход периметра записи.")
        if hits_secret_file(targets):
            log_event(base, "guard_bash", "secret_file", "deny", " ".join(targets))
            return False, ("[hook:bash] Команда трогает файл окружения или ключа "
                           "(.env, .env.prod, *.pem, secrets/). Значения заполняет человек.")
        if hits_outside(targets, base, cwd):
            log_event(base, "guard_bash", "outside_tree", "deny", " ".join(targets))
            return False, ("[hook:bash] Запись вне дерева репозитория запрещена: соседние деревья "
                           "правятся своими сессиями.")
    if re.search(r"\bgit\s+commit\b", cmd):
        finding = _staged_secret_scan(base)
        if finding:
            return False, (f"[hook:bash] Коммит остановлен секрет-сканом: {finding}. "
                           "Убери значение из staged и повтори.")
        log_event(base, "guard_bash", "commit_seen", "allow", "git commit")
    return True, ""


if __name__ == "__main__":
    data = read_input()
    _корень = project_dir(data)
    отметить_права(_корень, "guard_bash")
    целостность(_корень, "guard_bash")
    ok, msg = decide(data, _корень)
    deny(msg) if not ok else allow()
