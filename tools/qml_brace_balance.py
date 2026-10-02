"""Счётчик несбалансированных скобок в QML/JS — слабый прибор, назван слабым.

ПРЕДМЕТ ИЗМЕРЕНИЯ: баланс скобок () [] {} вне строк и комментариев.
ПРЕДИКАТ ОПОЗНАНИЯ ПРЕДМЕТА: посимвольный разбор с снятием // /* */ "..." '...'.

ЧЕГО ПРИБОР НЕ ВИДИТ (область, Ф-28/Ф-38):
  - ошибок типов QML, неизвестных свойств, циклов привязок;
  - отсутствующих import и незарегистрированных в .qrc файлов;
  - регулярных выражений (literal /.../) — разбираются как деление, и файл
    с ними даёт ложные показания; такие файлы в замер не подавать;
  - вообще всего, что видно только при загрузке предмета (М-55).

Настоящая проверка — qmllint; он есть на машине, но вне permissions.allow,
и позвать его нельзя. Это прибор на время, пока того нет.

КАЛИБРОВКА: обе половины эталона (Ф-15) прогоняются перед замером, ожидаемое
написано рукой. Не сошлось — показаний нет вовсе, а не пометка в выводе.
"""

import sys

OPEN = "([{"
CLOSE = ")]}"
PAIR = {")": "(", "]": "[", "}": "{"}
NL = chr(10)
BACKSLASH = chr(92)
QUOTES = ('"', chr(39))


def scan(src):
    i, n = 0, len(src)
    stack = []
    errs = []
    line = 1
    while i < n:
        c = src[i]
        if c == NL:
            line += 1
            i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != NL:
                i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                if src[i] == NL:
                    line += 1
                i += 1
            i += 2
            continue
        if c in QUOTES:
            q = c
            i += 1
            while i < n and src[i] != q:
                if src[i] == BACKSLASH:
                    i += 1
                if i < n and src[i] == NL:
                    line += 1
                i += 1
            i += 1
            continue
        if c in OPEN:
            stack.append((c, line))
            i += 1
            continue
        if c in CLOSE:
            if not stack:
                errs.append("line %d: closing %s with nothing open" % (line, c))
            elif stack[-1][0] != PAIR[c]:
                errs.append(
                    "line %d: closing %s but %s opened at line %d"
                    % (line, c, stack[-1][0], stack[-1][1])
                )
                stack.pop()
            else:
                stack.pop()
            i += 1
            continue
        i += 1
    for ch, ln in stack:
        errs.append("line %d: %s never closed" % (ln, ch))
    return errs


def calibrate():
    """Положительная и отрицательная половины эталона. Ожидаемое — рукой."""
    positive = (
        "Item { property int a: 1 // } закрывающая в комментарии" + NL
        + ' Text { text: "}{" } }'
    )
    negative = 'Item { Text { text: "x" } '
    negative2 = "Item { a: f(1 } }"
    cases = [
        ("positive: баланс есть, скобки спрятаны в строке и комментарии", 0, scan(positive)),
        ("negative: одна { не закрыта", 1, scan(negative)),
        ("negative: ( закрыта }", 1, scan(negative2)),
    ]
    ok = True
    print("--- КАЛИБРОВКА ---")
    for name, expect_nonzero, got in cases:
        passed = (len(got) == 0) if expect_nonzero == 0 else (len(got) > 0)
        ok = ok and passed
        print(
            "  %-62s ожидалось %-7s получено %d  %s"
            % (name, "0" if expect_nonzero == 0 else ">0", len(got), "PASS" if passed else "FAIL")
        )
    return ok


def main(paths):
    if not calibrate():
        print()
        print("КАЛИБРОВКА НЕ СОШЛАСЬ -> показаний нет (Ф-15).")
        return 2
    print()
    print("--- ЗАМЕР ---")
    if not paths:
        print("  предмета не подано -> не зелёное (Ф-23)")
        return 3
    total = 0
    for p in paths:
        try:
            src = open(p, encoding="utf-8").read()
        except OSError as e:
            print("  %-52s ОТКАЗ ЧТЕНИЯ: %s" % (p, e))
            return 4
        errs = scan(src)
        total += len(errs)
        print("  %-52s %d" % (p, len(errs)))
        for x in errs:
            print("        ", x)
    print()
    print("ИТОГО несбалансированных: %d  (файлов измерено: %d)" % (total, len(paths)))
    print("ОБЛАСТЬ: только баланс скобок вне строк и комментариев.")
    print("НЕ проверено: типы QML, неизвестные свойства, циклы привязок, import,")
    print("              регистрация в .qrc, загрузка предмета, поведение.")
    return 0 if total == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
