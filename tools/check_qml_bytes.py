"""Проверка ЗАПИСАННОГО: кодировка и первые байты файлов QML/JS (М-55).

Правка считается внесённой не когда текст подан на запись, а когда предмет
грузится. Между подачей и файлом стоит инструмент записи, который вправе
изменить предмет: добавить метку кодировки (BOM), переложить переводы строк,
испортить не-латиницу. Qt разбирает QML как UTF-8; BOM в начале QML-файла
и неверная кодировка дают ошибку загрузки, невидимую при чтении исходника.

ПРЕДМЕТ: первые байты файла и декодируемость всего файла как UTF-8.
ОБЛАСТЬ: НЕ проверяет синтаксис QML, типы, import, загрузку в движок.

КАЛИБРОВКА обеими половинами — ниже, перед замером.
"""

import os
import sys
import tempfile

BOM = b"\xef\xbb\xbf"


def inspect(path):
    """Возвращает список находок. Пустой список — находок нет."""
    errs = []
    with open(path, "rb") as f:
        raw = f.read()
    if raw.startswith(BOM):
        errs.append("начинается с BOM EF BB BF — Qt не примет это как QML")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        errs.append("не декодируется как UTF-8: %s" % e)
        return errs
    if "\x00" in text:
        errs.append("содержит нулевой байт")
    # Счётчик знаков вне латиницы: ноль такого счётчика неотличим от
    # неспособности прибора увидеть знак, поэтому он печатается всегда и
    # калибруется не-нулём на эталоне (Ф-15).
    cyr = sum(1 for ch in text if "Ѐ" <= ch <= "ӿ")
    nonascii = sum(1 for ch in text if ord(ch) > 127)
    return errs, cyr, nonascii


def calibrate():
    print("--- КАЛИБРОВКА ---")
    ok = True
    d = tempfile.mkdtemp()

    good = os.path.join(d, "good.qml")
    with open(good, "wb") as f:
        f.write("Item { }\n// кириллица здесь, знак ∞ тоже\n".encode("utf-8"))
    r = inspect(good)
    passed = len(r[0]) == 0 and r[1] > 0 and r[2] > 0
    ok = ok and passed
    print(
        "  positive: UTF-8 без BOM, кириллица есть   ожидалось 0 находок и cyr>0   "
        "получено %d находок, cyr=%d, non-ascii=%d  %s"
        % (len(r[0]), r[1], r[2], "PASS" if passed else "FAIL")
    )

    bad = os.path.join(d, "bom.qml")
    with open(bad, "wb") as f:
        f.write(BOM + b"Item { }\n")
    r = inspect(bad)
    passed = len(r[0]) > 0
    ok = ok and passed
    print(
        "  negative: тот же текст с BOM              ожидалось >0 находок          "
        "получено %d находок  %s" % (len(r[0]), "PASS" if passed else "FAIL")
    )

    bad2 = os.path.join(d, "cp1251.qml")
    with open(bad2, "wb") as f:
        f.write("Item { } // кириллица\n".encode("cp1251"))
    r = inspect(bad2)
    passed = len(r[0]) > 0
    ok = ok and passed
    print(
        "  negative: кириллица в cp1251, не UTF-8    ожидалось >0 находок          "
        "получено %d находок  %s" % (len(r[0]), "PASS" if passed else "FAIL")
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
        r = inspect(p)
        errs, cyr, nonascii = r[0], r[1], r[2]
        total += len(errs)
        print("  %-52s находок %d  cyr=%-5d non-ascii=%d" % (p, len(errs), cyr, nonascii))
        for x in errs:
            print("        ", x)
    print()
    print("ИТОГО находок: %d  (файлов измерено: %d)" % (total, len(paths)))
    print("ОБЛАСТЬ: первые байты и декодируемость UTF-8.")
    print("НЕ проверено: синтаксис QML, типы, import, загрузка предмета движком.")
    return 0 if total == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
