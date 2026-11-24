"""PreToolUse: Edit|Write|MultiEdit|NotebookEdit — периметр записи файлов.

Периметр ПРОДУКТОВОГО репозитория. От периметра управляющего контура отличается
предметом, а не механикой: канона здесь нет, публикация (`git push`) есть штатная
работа, а защищать надо конфигурацию окружения и то, что перечислено в
`.claude/protected_objects.json`.

Разбор и общие предикаты берутся из `_hooklib.py` — того же файла, что работает в
управляющем контуре. Копия синхронизируется установщиком и несёт строку редакции;
второй разбор означал бы вторые дефекты.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _hooklib import (SECRET_FILE, allow, call_cwd, deny, find_secrets, log_event,
                      отметить_права, целостность,
                      outside_allowed, is_protected, project_dir, read_input, rel_of, resolve)


def decide(data: dict, base: str) -> tuple[bool, str]:
    ti = data.get("tool_input", {}) or {}
    fp = ti.get("file_path") or ti.get("path") or ti.get("notebook_path")
    if not fp:
        return True, ""
    # Путь инструмента разворачивается тем же способом, что путь команды:
    # иначе один и тот же относительный путь решался бы двумя правилами.
    fp = resolve(str(fp), base, call_cwd(data))
    rel = rel_of(str(fp), base)
    if rel is None:
        if not outside_allowed(str(fp), base, call_cwd(data)):
            log_event(base, "guard_paths", "outside_tree", "deny", str(fp))
            return False, (f"[hook:path] Запись вне дерева репозитория запрещена: {fp}. "
                           "Соседние деревья правятся своими сессиями, а не этой.")
        rel = ""
    if rel and is_protected(rel, base):
        log_event(base, "guard_paths", "protected_write", "deny", rel)
        return False, ("[hook:path] Объект из .claude/protected_objects.json: правка только руками "
                       "владельца репозитория. Список — предмет защиты, а не путь.")
    if rel and SECRET_FILE.search("/" + rel):
        log_event(base, "guard_paths", "secret_file", "deny", rel)
        return False, ("[hook:path] Файл окружения или ключа (.env, .env.prod, *.pem, secrets/) агент "
                       "не правит. Значения заполняет человек; шаблон имён (.env.example) — можно.")
    payload = " ".join(str(ti.get(k, "")) for k in ("content", "new_string", "new_str", "file_text"))
    hits = find_secrets(payload)
    if hits:
        log_event(base, "guard_paths", "secret_in_content", "deny", ", ".join(hits))
        return False, (f"[hook:path] В записываемом содержимом похоже на живой секрет ({', '.join(hits)}). "
                       "Используй плейсхолдер и переменную окружения.")
    return True, ""


if __name__ == "__main__":
    data = read_input()
    _корень = project_dir(data)
    отметить_права(_корень, "guard_paths")
    целостность(_корень, "guard_paths")
    ok, msg = decide(data, _корень)
    deny(msg) if not ok else allow()
