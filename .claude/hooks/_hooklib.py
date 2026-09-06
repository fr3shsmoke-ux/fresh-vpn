"""Общая библиотека хуков FR3SH. Только stdlib — работает на Windows/Linux.
Контракт Claude Code: JSON на stdin; exit 0 = разрешить (stdout -> контекст для
некоторых событий), exit 2 = заблокировать (stderr возвращается Claude)."""
from __future__ import annotations

import json
import os
import re
import sys

BS = chr(92)  # обратная косая: литералом в исходнике не пишется

SECRET_PATTERNS: list[tuple[str, re.Pattern]] = [
    ("Anthropic API key", re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}")),
    ("AWS Access Key", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("GitHub token", re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}")),
    ("Slack token", re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}")),
    ("Telegram bot token", re.compile(r"\b\d{8,10}:AA[A-Za-z0-9_-]{33}\b")),
    ("Private key block", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("Generic assigned secret", re.compile(
        r"(?i)(api_key|apikey|secret|password|token)\s*[=:]\s*['\"][A-Za-z0-9_\-/+]{16,}['\"]")),
]


def read_input() -> dict:
    try:
        return json.load(sys.stdin)
    except Exception:
        return {}


def deny(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(2)


def allow(msg: str | None = None) -> None:
    if msg:
        print(msg)
    sys.exit(0)


def contour_root(start: str) -> str:
    """Корень контура: ближайший вверх каталог, в котором лежит `.claude`.

    Прежде корнем НАЗНАЧАЛСЯ рабочий каталог вызова. Допущение «cwd контура —
    сам репозиторий» ломается первым же заходом в подпапку: `base` становился
    `miniapp/`, и вместе с ним уезжали ОБА списка — боевые цели и защищённые
    объекты, — потому что читаются они из `<base>/.claude/`. Проба 22.08.2026:
    санкционированная запись в боевое дерево из подпапки отбивалась, и отказ
    выглядел как запрет периметра, а не как поломка предиката.
    """
    cur = os.path.realpath(start)
    while True:
        if os.path.isdir(os.path.join(cur, ".claude")):
            return cur
        вверх = os.path.dirname(cur)
        if вверх == cur:
            return os.path.realpath(start)
        cur = вверх


def call_cwd(data: dict) -> str:
    """Рабочий каталог ВЫЗОВА — основание относительных путей команды.

    От корня контура отличался всегда; их считали одним, и относительный путь
    наружу (`../соседнее/файл`) проходил периметр из корня репозитория.
    """
    return os.path.realpath(data.get("cwd") or os.getcwd())


def project_dir(data: dict) -> str:
    return contour_root(call_cwd(data))


def rel_of(path: str, base: str) -> str | None:
    """Относительный путь внутри base с '/'-разделителями; None, если снаружи."""
    p = os.path.realpath(path if os.path.isabs(path) else os.path.join(base, path))
    if p != base and not p.startswith(base + os.sep):
        return None
    return os.path.relpath(p, base).replace("\\", "/")


def find_secrets(text: str) -> list[str]:
    return [name for name, rx in SECRET_PATTERNS if rx.search(text or "")]


FORMULA_FILE = os.path.join(".claude", "acceptance_formula.json")


def acceptance_word(base: str) -> str:
    """Действующая формула приёмки. Один источник для матчера и для подсказок.

    Отсутствие конфига возвращает пустую строку: подсказка тогда честно говорит,
    что слова нет, вместо того чтобы называть выдуманное.
    """
    try:
        with open(os.path.join(base, FORMULA_FILE), encoding="utf-8") as fh:
            return str(json.load(fh).get("active") or "")
    except Exception:
        return ""


def marker(base: str, name: str) -> bool:
    """Маркеры-апрувы Владельца: файл .claude/<name> существует = явное разрешение."""
    return os.path.exists(os.path.join(base, ".claude", name))


# --- Единый предмет защиты для ОБОИХ гардов -------------------------------
# Правка 2026-08-18 (решение Владельца): предмет защиты задаётся СПИСКОМ
# ОБЪЕКТОВ в .claude/canonical_hashes.json, а не путём. Прежде guard_paths
# защищал два файла по точному пути, а guard_bash — всё дерево
# docs/regulation/, включая черновики, каноном не являющиеся. Один список для
# обоих гардов убирает расхождение по построению.
#
# Отказ чтения списка -> fail-closed: возвращается запасной набор. Пустой
# список означал бы «защищать нечего», то есть отключение гарда сбоем чтения.

_FALLBACK_PROTECTED = (
    "docs/regulation/holding_regulation.md",
    "docs/regulation/EVALUATION_PROTOCOL.md",
)


# Пути, запись в которые разрешена ВНЕ репозитория. Список закрытый и короткий:
# каждая строка — санкционированное Владельцем размещение либо временный файл.
# Живёт здесь, а не в отдельном гарде: 2026-08-19 обнаружено, что запрещающая
# половина предмета была общей, а разрешающая — нет, и один и тот же путь
# проходил командой и не проходил инструментом. Класс тот же, что у дефекта
# «предмет защиты определён путём, а не списком», только на разрешающей стороне.
SKILLS_MARK = "/.claude/skills"   # развёрнутая копия TIER 5 (Патч 9, уточнение)
PLANS_MARK = "/.claude/plans/"    # план-файлы plan-режима: служебный каталог харнесса сессии
MEMORY_MARK = "/.claude/projects/"   # память сессии: служебный каталог харнесса
NULL_SINKS = ("/dev/null", "nul")


def temp_roots() -> tuple[str, ...]:
    """Корни временных каталогов — КОРНИ, а не подстроки.

    Подстрочная проверка («/temp/» где угодно в пути) разрешала бы запись в
    D:/legacy/temp/secrets.txt — тот же класс ловушки, что «Edit» внутри
    «MultiEdit» при разборе матчера. Поэтому сверка идёт по началу пути.
    """
    roots = []
    for var in ("TEMP", "TMP", "TMPDIR"):
        v = os.environ.get(var)
        if v:
            roots.append(v.replace(chr(92), "/").rstrip("/").lower() + "/")
    try:
        import tempfile
        roots.append(tempfile.gettempdir().replace(chr(92), "/").rstrip("/").lower() + "/")
    except Exception:
        pass
    roots += ["/tmp/", "/var/tmp/"]
    return tuple(sorted(set(roots)))


USER_MEMORY_MARK = "/.claude/claude.md"   # пользовательский CLAUDE.md машины


def norm_path(token: str) -> str:
    """Одна форма записи пути для всех решений гардов.

    Правка 2026-08-19: разрешающий предикат сравнивал СЫРОЙ токен, и потому
    путь с тильдой проходил проверку существования (файла с буквальной тильдой
    не бывает) и читался как создание. Тот же путь в другой НОТАЦИИ — соседний
    уровень по оси роли (М-5): элементы те же, роль записи другая. Разворот
    тильды и git-bash-формы делается здесь, один раз на оба гарда.
    """
    t = str(token).strip().strip("'" + chr(34)).replace(chr(92), "/")
    if t.startswith("~"):
        t = os.path.expanduser(t).replace(chr(92), "/")
    m = re.match(r"^/([a-zA-Z])/(.*)$", t)      # форма git-bash приводится к дисковой
    if m:
        t = m.group(1) + ":/" + m.group(2)
    return t


def resolve(token: str, base: str = "", cwd: str = "") -> str:
    """Путь в одной форме и ВСЕГДА абсолютный.

    Относительный путь основывается на рабочем каталоге ВЫЗОВА, а не на корне
    контура: это разные каталоги, и подмена одного другим делала `..`-выход
    невидимым для периметра. Ось та же, что у `norm_path`: один и тот же путь
    в другой нотации — соседний уровень по роли записи (М-5).
    """
    t = norm_path(token)
    if not t:
        return t
    if os.path.isabs(t) or re.match(r"^[a-zA-Z]:/", t) or t.startswith("//"):
        return t
    основание = cwd or base
    if not основание:
        return t
    return os.path.realpath(os.path.join(основание, t)).replace(chr(92), "/")


COMBAT_MARKER = "allow_combat_edit"
COMBAT_LIST = "combat_targets.json"
EXCHANGE_LIST = "exchange_paths.json"   # санкция обмена (пакет №55, позиция 1)


def exchange_roots(base: str) -> tuple:
    """Корни каталога обмена, куда сессии этого дерева разрешена запись. Нет файла — нет корней."""
    try:
        with open(os.path.join(base, ".claude", EXCHANGE_LIST), encoding="utf-8") as fh:
            roots = json.load(fh).get("писать") or []
    except (OSError, ValueError):
        return ()
    return tuple(norm_path(str(r)).lower().rstrip("/") for r in roots if str(r).strip())


def exchange_allowed(path: str, base: str) -> bool:
    """Санкция обмена: запись только в корни из exchange_paths.json (пакет №55, слово Владельца
    02.09 и 04.09). Предикат по КОРНЮ после нормализации — не по подстроке (М-18): корень-файл
    совпадает целиком, корень-каталог — префиксом с разделителем. Маркера не требует: санкция
    дана словом на постоянной основе, а список — защищённый объект, расширяемый только пакетом.
    """
    if not base:
        return False
    low = norm_path(path).lower().rstrip("/")
    for r in exchange_roots(base):
        if low == r or low.startswith(r + "/"):
            log_event(base, "exchange", "exchange_write", "allow", norm_path(path))
            return True
    return False


def combat_targets(base: str) -> tuple:
    """Корни боевых деревьев, правка которых санкционирована. Данные, не код."""
    try:
        with open(os.path.join(base, ".claude", COMBAT_LIST), encoding="utf-8") as fh:
            roots = json.load(fh).get("roots") or []
    except Exception:
        return ()
    out = []
    for r in roots:
        low = norm_path(r).lower().rstrip("/")
        if low:
            out.append(low + "/")
    return tuple(out)


def combat_allowed(path: str, base: str) -> bool:
    """Разрешена ли запись в боевое дерево ЗДЕСЬ И СЕЙЧАС.

    Два условия, и оба обязательны: путь в списке целей И стоит разрешение,
    рождённое фразой Владельца. Список сам по себе власти не даёт — он говорит,
    КУДА можно, а не МОЖНО ЛИ; разделение то же, что у пакета канона (П-1).
    """
    if not base or not marker(base, COMBAT_MARKER):
        return False
    low = norm_path(path).lower()
    roots = combat_targets(base)
    if not any(low.startswith(r) for r in roots):
        return False
    # запись в чужое дерево — событие даже когда разрешена: санкция снимает
    # запрет, но не отменяет наблюдаемости
    log_event(base, "combat", "combat_write", "allow", norm_path(path))
    return True


def outside_allowed(path: str, base: str = "", cwd: str = "") -> bool:
    """Разрешён ли этот внешний путь. Один ответ для обоих гардов.

    Предикат смотрит на файловую систему в одном месте — у пользовательского
    CLAUDE.md: его СОЗДАНИЕ разрешено (подключение правил ставится один раз),
    а ПЕРЕЗАПИСЬ и УДАЛЕНИЕ — нет. Способность переписывать умолчание всех
    сессий машины агенту не нужна: она означала бы, что он выписывает себе
    постоянные указания. Удаление закрыто отдельно: «убрать и создать заново»
    даёт перезапись в два хода, если удаление не считать мутацией.
    """
    # `nul` относителен по виду: проверяем ДО разворота, иначе он склеится с
    # рабочим каталогом и перестанет быть стоком.
    if norm_path(path).lower() in NULL_SINKS:
        return True
    real = resolve(path, base, cwd)
    low = real.lower()
    if SKILLS_MARK in low or low.startswith(".claude/skills"):
        return True
    if PLANS_MARK in low:
        return True
    if MEMORY_MARK in low:
        return True
    if low.endswith(USER_MEMORY_MARK):
        return not os.path.exists(real)
    if low.startswith(temp_roots()):
        return True
    return combat_allowed(real, base) or exchange_allowed(real, base)


def protected_paths(base: str) -> list[str]:
    """Объекты TIER 3 под защитой гардов.

    Два источника, оба — данные, а не код:
      * `.claude/canonical_hashes.json` — файлы канона (там же их хеши);
      * `.claude/protected_objects.json` — прочие объекты TIER 3, в том числе
        каталоги (запись оканчивается на «/» и означает префикс).
    Разделение нужно потому, что реестр хешей по построению перечисляет файлы,
    а `governance/sops/` — каталог: его состав меняется, а статус TIER 3 нет.
    """
    names: list[str] = []
    for fname in ("canonical_hashes.json", "protected_objects.json"):
        try:
            with open(os.path.join(base, ".claude", fname), encoding="utf-8") as fh:
                data = json.load(fh)
            names += [str(k).replace("\\", "/") for k in (data if isinstance(data, list) else data)]
        except Exception:
            continue
    return sorted(set(names) | set(_FALLBACK_PROTECTED))


# --- Разбор командной строки (без политики) ---------------------------------
# Переехало из guard_bash 2026-08-19: тот же разбор нужен периметру
# продуктовых репозиториев, а второй разбор означал бы вторые дефекты.

# Дублирование дескрипторов: 2>&1, 1>&2, >&2, 2>&-. Файл не затрагивается.
# `&>` НЕ исключается: `&> файл` — настоящая запись обоих потоков в файл.
FD_DUP = re.compile(r"\d*>&(?:\d+|-)")
# Граница токена, а не подстроки: слово «install» встречается и в пути
# (perimeter/install.py), и правило по подстроке отклоняло собственный
# установщик. Кавычки в шаблон не вносим — их снимает unquote() перед
# разбором, иначе класс символов сам становится ловушкой нотации.
WRITE_NAMES = (r"tee|dd|cp|mv|install|rm|del|rmdir|unlink|Set-Content|Out-File|"
               r"Add-Content|Copy-Item|Move-Item|New-Item|Remove-Item")
WRITE_OP = re.compile(r">{1,2}|(?:^|\s)(?:" + WRITE_NAMES +
                      r"|sed\s+(?:-[a-zA-Z]*\s+)*-i)(?=\s|$)", re.I)


def unquote(seg: str) -> str:
    """Обёртки вложенного исполнения заменяются пробелом.

    Кавычки (bash -c "rm x") и скобки подстановки (n=$(cp a b)) — это оболочка
    вокруг команды, а не часть её имени. Снимаем их до разбора, иначе граница
    токена, введённая против совпадения «install» с путём, отрежет вложенные
    команды: они стоят не после пробела, а после кавычки или скобки.
    """
    out = seg
    for ch in (chr(34), chr(39), "(", ")"):
        out = out.replace(ch, " ")
    return out


CMD_SPLIT = re.compile(r"\|\||&&|[;|\n]")
TOKEN = re.compile(r"[^\s'\"|<>;&()]+")

# `.env` с любым суффиксом: .env, .env.prod, .env.local, .env.production.
# Правка 2026-08-19 — прежний шаблон требовал `.env` РОВНО в конце пути, и
# `.env.prod` продуктового репозитория проходил мимо правила.
# Шаблоны имён (.env.example и родня) исключены: они содержат имена без
# значений, и CLAUDE.md прямо требует их вести.
SECRET_FILE = re.compile(
    r"(^|/)\.env(\.(?!example$|sample$|template$|dist$)[A-Za-z0-9_-]+)?$"
    r"|\.(pem|key|jks|p12|pfx)$|(^|/)secrets?/", re.I)

# ALLOW_OUTSIDE и outside_allowed живут в _hooklib: один список на оба гарда.


def segments(cmd: str) -> list[str]:
    """Строка команд -> отдельные команды. Правило применяется к каждой."""
    return CMD_SPLIT.split(cmd)


def has_write(seg: str) -> bool:
    """Есть ли в сегменте оператор записи (дублирование дескрипторов не в счёт)."""
    return bool(WRITE_OP.search(FD_DUP.sub(" ", unquote(seg))))


def tokens_of(seg: str) -> list[str]:
    return TOKEN.findall(seg)


# Цель записи, а не любой путь в сегменте. Правка 2026-08-18, второй заход:
# первая редакция проверяла ЛЮБОЙ путь сегмента, в котором есть оператор
# записи, и потому блокировала `ls /d/legacy 2>/dev/null` — чтение с отводом
# ошибок в /dev/null. Это тот же дефект, что был у REG_SHELL_WRITE: оператор
# записи и путь оказались в одном сегменте, но не связаны между собой.
REDIRECT_TARGET = re.compile(r"(?:\d*>{1,2}|&>{1,2})\s*([^\s;|&<>]+)")
WRITE_KEYWORD = re.compile(r"(?:^|\s)(" + WRITE_NAMES + r"|sed)(?=\s|$)", re.I)
DD_TARGET = re.compile(r"\bof=([^\s;|&]+)")


def command_name(seg: str) -> str:
    """Имя команды сегмента: первый токен, не похожий на присваивание окружения."""
    for tok in tokens_of(seg):
        if "=" in tok:
            continue
        return os.path.basename(tok.replace(BS, "/")).lower()
    return ""


def write_targets(seg: str) -> list[str]:
    """Пути, В КОТОРЫЕ сегмент пишет. Прочие пути сегмента целями не считаются.

    Два разных по природе источника целей:
      * перенаправления — ГРАММАТИКА оболочки, перечисляется исчерпывающе;
      * аргументы команд записи и УДАЛЕНИЯ — ПЕРЕЧЕНЬ имён, и он всегда неполон.
    Второе — постоянная граница «запись через семантику команд покрыта перечнем,
    а не разбором» (решение Владельца 2026-08-18): полнота здесь недостижима,
    потому что любая новая команда записи в перечень не входит, пока не внесена.
    """
    clean = FD_DUP.sub(" ", unquote(seg))
    targets = REDIRECT_TARGET.findall(clean)          # грамматика
    targets += DD_TARGET.findall(clean)               # dd of=<цель>
    m = WRITE_KEYWORD.search(clean)
    if m:
        name = m.group(1).lower()
        args = [t for t in tokens_of(clean[m.end():]) if not t.startswith("-") and "=" not in t]
        if name in ("cp", "copy-item"):
            targets += args[-1:]                      # пишет только в назначение
        elif name in ("mv", "move-item", "install"):
            targets += args                           # источник тоже меняется: он исчезает
        elif name in ("tee", "sed"):
            targets += args                           # пишет во все перечисленные файлы
        elif name in ("rm", "del", "rmdir", "unlink", "remove-item"):
            targets += args                           # цель уничтожается: та же роль,
            # что у источника при mv. Без этой строки запрет перезаписи обходился
            # в два хода — «удалить и создать заново» (находка Владельца 19.08).
            # unlink в перечень Владельца не входил и добавлен исполнителем: та же
            # роль, и его отсутствие было бы ровно той дырой, что здесь чинится.
        elif name == "dd":
            pass                                      # цель уже взята из of=
        else:
            targets += args                           # PowerShell-цмдлеты: -Path/-FilePath/позиционный
    return [t.strip("'\"") for t in targets if t]


# --- Временный накопитель событий гардов ----------------------------------
# Решение Владельца 2026-08-18: до потока guard_event (§1 и §4 проекта контура
# улучшения) наблюдаемость держится на append-only файле — «мост дешевле
# слепоты». Без накопления нет ни очереди незакрытых событий, ни ревизии по ним.
#
# Секретная гигиена: полный текст команды НЕ пишется. В журнал идут правило,
# решение и цель; любое значение прогоняется через секрет-скан и заменяется на
# [REDACTED] при совпадении.

GUARD_LOG = os.path.join("var", "guard_events.jsonl")


def _redact(text: str) -> str:
    t = (text or "")[:300]
    return "[REDACTED]" if find_secrets(t) else t


def log_event(base: str, guard: str, rule: str, decision: str, target: str = "") -> None:
    """Одна строка на событие. Отказ записи журнала работу не останавливает."""
    try:
        path = os.path.join(base, GUARD_LOG)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        row = {
            "ts": __import__("datetime").datetime.now().isoformat(timespec="seconds"),
            "guard": guard,
            "rule": rule,
            "decision": decision,
            "target": _redact(target),
        }
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    except Exception:
        pass  # журнал не может быть причиной отказа в работе


def права_админа() -> bool:
    """Запущены ли мы с правами администратора (root).

    При таких правах защита объектов правами файловой системы НЕ ДЕЙСТВУЕТ:
    повышенный процесс пишет туда, куда обычному запрещено. Знать об этом
    обязаны обе стороны — и потому состояние попадает в журнал.
    """
    try:
        if os.name == "nt":
            import ctypes
            return bool(ctypes.windll.shell32.IsUserAnAdmin())
        return os.geteuid() == 0
    except Exception:
        return False


def _последнее_состояние_прав(base: str) -> str:
    """Что журнал помнит о правах в прошлый раз. Пусто — не помнит ничего."""
    try:
        path = os.path.join(base, GUARD_LOG)
        with open(path, "rb") as fh:
            fh.seek(0, os.SEEK_END)
            назад = min(fh.tell(), 65536)
            fh.seek(-назад, os.SEEK_END)
            хвост = fh.read().decode("utf-8", "ignore")
        for line in reversed(хвост.splitlines()):
            if '"elevated"' not in line:
                continue
            return json.loads(line).get("decision") or ""
    except Exception:
        pass
    return ""


def отметить_права(base: str, guard: str) -> None:
    """Записать смену состояния прав. Одинаковое подряд не дублируется."""
    сейчас = "warn" if права_админа() else "ok"
    if сейчас == _последнее_состояние_прав(base):
        return
    log_event(
        base,
        guard,
        "elevated",
        сейчас,
        "ЗАЩИТА ПРАВАМИ ФС НЕ ДЕЙСТВУЕТ: терминал запущен от администратора"
        if сейчас == "warn"
        else "обычные права: защита файловой системы в силе",
    )


# --- Наблюдатель целостности защищаемых объектов --------------------------
# Правка 22.08.2026 по решению Владельца: «сначала работающий журнал, потом
# права». Основание — обход, случившийся в этот день и не оставивший следа.

СЛЕПОК = os.path.join("var", "protected_state.json")
ЖИВОСТЬ_СЕКУНД = 3600      # как часто писать «проверено, всё на месте»


def _хеш(path: str) -> str:
    """SHA-256 файла. Нечитаемый файл — отдельное состояние, не пустая строка."""
    import hashlib
    try:
        h = hashlib.sha256()
        with open(path, "rb") as fh:
            for кусок in iter(lambda: fh.read(65536), b""):
                h.update(кусок)
        return h.hexdigest()
    except Exception:
        return "нечитаем"


def защищаемые_файлы(base: str) -> list[str]:
    """Развернуть список защищаемых объектов в конкретные файлы.

    Каталог из списка (запись с «/» на конце) разворачивается в свои файлы:
    сверять надо содержимое, а у каталога его нет. Кэш интерпретатора
    (`__pycache__`) пропускается — он меняется сам и событием не является.
    """
    файлы: list[str] = []
    for объект in protected_paths(base):
        путь = os.path.join(base, объект.replace("/", os.sep))
        if os.path.isdir(путь):
            for корень, каталоги, имена in os.walk(путь):
                каталоги[:] = [к for к in каталоги if к != "__pycache__"]
                for имя in имена:
                    if имя.endswith((".pyc", ".pyo")):
                        continue
                    полный = os.path.join(корень, имя)
                    файлы.append(os.path.relpath(полный, base).replace(os.sep, "/"))
        elif os.path.isfile(путь):
            файлы.append(объект.replace("\\", "/"))
    return sorted(set(файлы))


def целостность(base: str, guard: str) -> None:
    """Сверить суммы защищаемых объектов с прошлым разом и записать расхождения.

    Порядок намеренный: сначала событие, потом обновление слепка. Падение между
    ними оставит старый слепок, и расхождение будет замечено ещё раз — повтор
    события безвреден, пропуск события нет.
    """
    if not base:
        return
    try:
        путь = os.path.join(base, СЛЕПОК)
        было = {}
        отметка = 0.0
        if os.path.exists(путь):
            with open(путь, encoding="utf-8") as fh:
                данные = json.load(fh)
            было = данные.get("суммы") or {}
            отметка = float(данные.get("проверено") or 0)

        стало = {имя: _хеш(os.path.join(base, имя)) for имя in защищаемые_файлы(base)}

        if not было:
            log_event(base, guard, "integrity", "baseline",
                      f"слепок снят впервые, объектов {len(стало)}")
        else:
            for имя in sorted(set(было) | set(стало)):
                старое, новое = было.get(имя), стало.get(имя)
                if старое == новое:
                    continue
                если_нет = "исчез" if новое is None else ("появился" if старое is None else "ИЗМЕНЁН")
                log_event(base, guard, "integrity", "warn", f"{имя}: {если_нет}")

        import time
        сейчас = time.time()
        пишем_живость = сейчас - отметка > ЖИВОСТЬ_СЕКУНД
        if пишем_живость and было and стало == было:
            log_event(base, guard, "integrity", "ok",
                      f"проверено объектов {len(стало)}, расхождений нет")
        if стало != было or пишем_живость:
            os.makedirs(os.path.dirname(путь), exist_ok=True)
            with open(путь, "w", encoding="utf-8") as fh:
                json.dump({"проверено": сейчас, "суммы": стало}, fh,
                          ensure_ascii=False, indent=1)
    except Exception as e:
        # Наблюдатель не может быть причиной отказа в работе, но и молчать о
        # собственном отказе не должен: молчащий наблюдатель неотличим от
        # спокойного.
        try:
            log_event(base, guard, "integrity", "fail", e.__class__.__name__)
        except Exception:
            pass


MEMORY_IMPORT = re.compile(r"^@(\S+)\s*$", re.M)


def rules_state(base: str) -> tuple:
    """(идентификатор редакции, причина отказа) — ровно одно из двух не пусто.

    Проверяется ЦЕПОЧКА ПОДКЛЮЧЕНИЯ, а не доставка: что модель действительно
    получила текст в контекст, из хука не наблюдаемо. Наблюдаемо лишь то, что
    раскрывать было что, — и этого достаточно, чтобы битый путь перестал быть
    тихим (М-6: молчаливая неполнота хуже объявленного отсутствия).

    Номер редакции берётся у генератора, а не считается здесь заново: второй
    счёт того же числа есть второй источник истины.
    """
    try:
        import importlib.util
        src = os.path.join(base, "governance", "gen_agent_rules.py")
        if not os.path.exists(src):
            return None, "генератор файла передачи отсутствует"
        spec = importlib.util.spec_from_file_location("gen_agent_rules_hook", src)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        if not os.path.exists(os.path.join(base, "docs", "regulation", "agent_default_rules.md")):
            return None, "файл передачи отсутствует"
        memory = os.path.join(os.path.expanduser("~"), ".claude", "CLAUDE.md")
        if not os.path.exists(memory):
            return None, "пользовательский CLAUDE.md отсутствует — сессии стартуют без правил"
        with open(memory, encoding="utf-8", errors="ignore") as fh:
            targets = MEMORY_IMPORT.findall(fh.read())
        if not targets:
            return None, "в пользовательском CLAUDE.md нет импорта правил"
        broken = [t for t in targets if not os.path.exists(os.path.expanduser(t))]
        if broken:
            return None, "импорт не раскрывается: " + " ".join(broken)
        number, digest = mod.revision(mod.canon_text())
        return f"{number}/{digest[:12]}", None
    except Exception as e:
        return None, f"проверка подключения не выполнилась ({e.__class__.__name__})"


def journal_heartbeat(base: str) -> None:
    """Строка «жив» при старте сессии.

    «Отсутствие результата — событие» касается и наблюдателя: без хартбита
    молчащий журнал неотличим от журнала без событий. Строка несёт размер файла
    на момент записи — по нему следующая сессия видит усечение или откат.
    """
    try:
        path = os.path.join(base, GUARD_LOG)
        size = os.path.getsize(path) if os.path.exists(path) else 0
    except Exception:
        size = 0
    rev, why = rules_state(base)
    mark = f"rules={rev}" if rev else "rules=НЕ ПОДКЛЮЧЕНЫ"
    log_event(base, "session", "heartbeat", "alive", f"size={size} {mark}")
    if why:
        # Отсутствие — событие, а не тихий старт без правил (решение Владельца
        # 2026-08-19). Строка идёт отдельной записью: хартбит говорит «жив»,
        # событие говорит «жив, но без правил», и это разные факты.
        log_event(base, "session", "rules_missing", "warn", why)


def journal_state(base: str) -> tuple[str, str]:
    """(статус, пояснение) о живости журнала: читается тем же прогоном, что K.drift."""
    path = os.path.join(base, GUARD_LOG)
    if not os.path.exists(path):
        return "FAIL", "журнал событий гардов отсутствует — наблюдатель молчит, а не наблюдает"
    try:
        size = os.path.getsize(path)
        rows = [json.loads(line) for line in open(path, encoding="utf-8") if line.strip()]
    except Exception as e:
        return "FAIL", f"журнал нечитаем ({e.__class__.__name__}) — записи не проверяемы"
    beats = [r for r in rows if r.get("rule") == "heartbeat"]
    if not beats:
        return "WARN", "в журнале нет ни одного хартбита: живость наблюдателя не подтверждена"
    prev = 0
    for b in beats[:-1][::-1]:
        try:
            prev = int(str(b.get("target", "size=0")).split("=", 1)[1])
            break
        except Exception:
            continue
    if size < prev:
        return "FAIL", (f"журнал усечён: было {prev} байт на прошлой сессии, сейчас {size} — "
                        "откат или подмена")
    return "PASS", f"журнал жив: {len(rows)} записей, {len(beats)} хартбитов, {size} байт"


def is_protected(rel: str, base: str) -> bool:
    """Относится ли путь к защищаемым объектам (файл целиком или префикс каталога)."""
    # Ведущее «./» снимается КАК ПРЕФИКС, а не как набор символов: lstrip("./")
    # съедал ведущую точку у `.claude/...`, и объект переставал совпадать с самим
    # собой в списке. Ось нотации: тот же путь в другой записи.
    r = (rel or "").replace(chr(92), "/").lower()
    # НОРМАЛИЗУЕТСЯ ВЕСЬ ПУТЬ, и АБСОЛЮТНЫЙ ПУТЬ ПРИВОДИТСЯ К ОТНОСИТЕЛЬНОМУ.
    #
    # Ось нотации, две половины, измерены `governance/probe_notation_axis.py`:
    #   1) внутренние «./», «//», «..» не сворачивались — 3 дыры из 8 (05.09);
    #   2) путь ОТ КОРНЯ ДИСКА не ловился ветвью записи-каталога вовсе, потому
    #      что она сверяется префиксом: `d:/дерево/.claude/hooks/x.py` не
    #      начинается с `.claude/hooks/` — 3 дыры из 5 (06.09, находка агента
    #      панели). В управляющем контуре вторая половина СКРЫТА полнотой
    #      реестра хешей: там каждый файл хуков перечислен поимённо, и ловит
    #      ветвь записи-файла. Признак держался на постороннем свойстве.
    #
    # Обратная сторона той же непоследовательности: запись-ФАЙЛ ловилась
    # суффиксом в ЛЮБОМ дереве, то есть предикат защищал `.claude/settings.json`
    # чужого дерева от имени этого. Приведение к относительному снимает и это:
    # путь вне корня — предмет предиката «снаружи», а не защиты канона (М-18).
    _б = (base or "").replace(chr(92), "/").lower().rstrip("/")

    def _мсис(п):
        # `/c/Users/...` — форма msys; тот же путь в другой записи.
        if len(п) > 2 and п[0] == "/" and п[1].isalpha() and п[2] == "/":
            return п[1] + ":" + п[2:]
        return п

    def _норм(п):
        части = []
        for сег in п.split("/"):
            if сег in ("", "."):
                continue
            if сег == "..":
                if части:
                    части.pop()
                continue
            части.append(сег)
        return "/".join(части)

    _абсолютный = (len(r) > 1 and r[1] == ":") or r.startswith("/")
    r = _норм(_мсис(r))
    if _абсолютный:
        _б = _норм(_мсис(_б))
        if not _б or not (r == _б or r.startswith(_б + "/")):
            return False
        r = r[len(_б) + 1:]
    if not r:
        return False
    for obj in protected_paths(base):
        o = obj.lower()
        if o.endswith("/"):
            if r.startswith(o) or r == o.rstrip("/"):
                return True
        elif r == o or r.endswith("/" + o):
            return True
    return False


def outside_repo(token: str, base: str, cwd: str = "") -> bool:
    """Указывает ли токен команды на путь ВНЕ дерева репозитория.

    🔴 Правка 22.08.2026. Прежде здесь стояло: «относительные пути считаются
    внутренними: их основанием служит cwd, а cwd контура — сам репозиторий».
    Второе неверно с первого же захода в подпапку, а первое неверно всегда:
    `..` выводит наружу из любого каталога. Калибровочная проба показала, что
    `echo x > ../соседнее/файл` проходил периметр ИЗ КОРНЯ репозитория.

    Теперь путь разворачивается от каталога вызова и сверяется как абсолютный.
    Вид записи решения больше не принимает.
    """
    t = str(token).strip().strip("'" + chr(34))
    if not t:
        return False
    real = resolve(t, base, cwd)
    if not real:
        return False
    return rel_of(real, base) is None
