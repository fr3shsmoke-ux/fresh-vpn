"""Опись: что нужно, чтобы собрать десктоп, и что из этого есть на машине.

Сборку НЕ запускает и запускать не может: права нет. Проверяет только
существование путей и наличие инструментов — это показание о НАЛИЧИИ, а не
о пригодности. Инструмент, найденный на месте, может не собрать дерево;
«есть» здесь означает ровно «файл существует», и ничего больше.

Предмет требований выведен из самого дерева, а не из памяти (М-23):
  · .github/workflows/build-fresh-windows.yml — чем собирает CI;
  · deploy/build.bat — что CI на самом деле зовёт;
  · CMakeLists.txt — минимальная версия cmake, стандарт C++.

ДАТА СНЯТИЯ печатается в выводе: перечень, чей предмет живёт вне перечня,
несёт возраст показания (Ф-34).
"""

import datetime
import glob
import os
import shutil
import subprocess
import sys


def which(name):
    return shutil.which(name)


def ver(args):
    """Версия инструмента. Не запустился — так и сказано, а не пропущено."""
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=30)
        out = (p.stdout or p.stderr).strip().splitlines()
        return out[0] if out else "(пустой вывод)"
    except Exception as e:
        return "ОТКАЗ ЗАПУСКА: %s" % e


def main():
    print("ОПИСЬ ПРЕДПОСЫЛОК СБОРКИ — снято %s"
          % datetime.datetime.now().strftime("%Y-%m-%d %H:%M (локальные часы машины)"))
    print("Сборка НЕ запускалась. Ниже — только наличие путей и версии.")
    print()

    print("=== 1. Инструменты на PATH ===")
    tools = [
        ("cmake", ["cmake", "--version"], "обязателен, CMakeLists требует >= 3.25.0"),
        ("conan", ["conan", "--version"], "обязателен, CMakeLists зовёт conan_provider.cmake"),
        ("python", [sys.executable, "--version"], "обязателен, conan и генераторы"),
        ("ninja", ["ninja", "--version"], "НЕ обязателен: build.bat берёт генератор VS, не ninja"),
        ("cl", ["cl"], "НЕ обязателен на PATH: его даёт vcvarsall.bat"),
        ("qmllint", ["qmllint", "--version"], "не для сборки — для проверки QML без неё"),
        ("windeployqt", ["windeployqt", "--version"], "нужен только для раскладки дистрибутива"),
    ]
    for name, args, note in tools:
        p = which(name)
        if p:
            print("  %-12s ЕСТЬ  %s" % (name, p))
            print("  %-12s       версия: %s" % ("", ver(args)))
        else:
            print("  %-12s НЕТ на PATH" % name)
        print("  %-12s       %s" % ("", note))
    print()

    print("=== 2. Qt ===")
    bases = ["C:/Qt", "D:/Qt", os.path.expanduser("~/Qt")]
    found_kit = False
    for b in bases:
        if not os.path.isdir(b):
            print("  %-28s НЕТ каталога" % b)
            continue
        kits = sorted(glob.glob(b + "/6*"))
        if not kits:
            print("  %-28s есть, но версий 6.* внутри нет" % b)
            continue
        for k in kits:
            subs = sorted(
                d for d in os.listdir(k)
                if os.path.isdir(os.path.join(k, d)) and d.startswith("msvc")
            )
            mark = "msvc-набор: " + (", ".join(subs) if subs else "НЕТ — сборке MSVC не годится")
            if subs:
                found_kit = True
            print("  %-28s %s" % (k.replace(chr(92), "/"), mark))
    print("  build.bat зовёт CMAKE_PREFIX_PATH=<Qt>/msvc2022_64 — нужен именно msvc2022_64.")
    print("  CI собирает на Qt 6.10.1 (QT_VERSION в build-fresh-windows.yml).")
    print("  Пригоден хотя бы один msvc-набор: %s" % ("да" if found_kit else "НЕТ"))
    print()

    print("=== 3. MSVC ===")
    vswhere = os.path.join(
        os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)"),
        "Microsoft Visual Studio", "Installer", "vswhere.exe")
    print("  vswhere: %s" % ("ЕСТЬ  " + vswhere if os.path.isfile(vswhere) else "НЕТ  " + vswhere))
    print("    build.bat ищет его ровно по этому пути; нет его — vcvarsall не найдётся.")
    vcvars = []
    for root in ["C:/Program Files/Microsoft Visual Studio",
                 "C:/Program Files (x86)/Microsoft Visual Studio"]:
        vcvars += glob.glob(root + "/*/*/VC/Auxiliary/Build/vcvarsall.bat")
    if vcvars:
        for v in vcvars:
            print("  vcvarsall: ЕСТЬ  %s" % v.replace(chr(92), "/"))
    else:
        print("  vcvarsall: НЕ НАЙДЕН ни под одним из двух корней Visual Studio")
    print()

    print("=== 4. Предыдущая сборка в дереве ===")
    for d in ["build_cc", "deploy/build"]:
        p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), d)
        if os.path.isdir(p):
            n = sum(len(f) for _, _, f in os.walk(p))
            print("  %-16s ЕСТЬ, файлов: %d" % (d, n))
        else:
            print("  %-16s НЕТ" % d)
    print("  Каталог прошлой сборки есть — показание о том, что дерево когда-то")
    print("  собиралось, а НЕ о том, что соберётся сейчас и не о том, чем собиралось.")
    print()

    print("=== ОБЛАСТЬ ЗАМЕРА (чего здесь нет) ===")
    print("  · сборка не запускалась — пригодность набора не установлена;")
    print("  · версии cmake и conan прочитаны, но с требованиями НЕ сверены машинно;")
    print("  · подмодули (checkout submodules: recursive в CI) не проверялись;")
    print("  · remote conan artifactory.amnezia.org не опрашивался: сеть не открыта;")
    print("  · WiX и QtInstallerFramework не проверялись: нужны только установщику.")


if __name__ == "__main__":
    main()
