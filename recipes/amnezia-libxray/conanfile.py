from conan import ConanFile
from conan.tools.files import get, copy, replace_in_file, apply_conandata_patches, export_conandata_patches
from conan.tools.layout import basic_layout
from conan.errors import ConanInvalidConfiguration, ConanException
from conan.tools.env import Environment

import os
import stat

from pathlib import Path

class AmneziaLibxray(ConanFile):
    name = "amnezia-libxray"
    version = "1.0.3"
    settings = "os", "arch", "compiler"

    def export_sources(self):
        export_conandata_patches(self)

    def configure(self):
        self.settings.rm_safe("compiler.libcxx")
        self.settings.rm_safe("compiler.cppstd")

    def layout(self):
        basic_layout(self, build_folder=".")

    @property
    def _build_on_windows(self):
        return str(self.settings_build.os) == "Windows"

    def build_requirements(self):
        self.tool_requires("go/1.26.0")
        if self._build_on_windows:
            # build.sh is bash-only; reuse the same pattern the other recipes
            # in this repo already use for Windows hosts.
            self.win_bash = True
            if not self.conf.get("tools.microsoft.bash:path", check_type=str):
                self.tool_requires("msys2/cci.latest")
    
    def validate(self):
        if self.settings.os != "Android":
            raise ConanInvalidConfiguration(f"{self.name} v{self.version} does not support {self.settings.os}")

    def source(self):
        get(self, f"https://github.com/amnezia-vpn/amnezia-libxray/archive/refs/tags/v{self.version}.zip",
            sha256="3b1194c2a76e73913fdae49983c40a219c45a164ebdae72ef1297469348de730", strip_root=True
        )

    def generate(self):
        env = Environment()
        ndk_path_str = self.conf.get("tools.android:ndk_path")
        if ndk_path_str:
            ndk_path = Path(ndk_path_str)
            if len(ndk_path.parts) > 2:
                sdk_path = ndk_path.parents[1]
                env.define("ANDROID_HOME", str(sdk_path))
        env.vars(self).save_script("conan_provide_androidhome")

    def _patch_sources(self):
        apply_conandata_patches(self)
        build_path = os.path.join(self.build_folder, "build.sh")
        build_stat = os.stat(build_path)
        os.chmod(build_path, build_stat.st_mode | stat.S_IEXEC)

        # Older build.sh deleted go.mod and regenerated it. That dropped the
        # pinned amnezia-xray-core and resolved to a version whose module path
        # broke "go mod tidy". Upstream 1.0.3 keeps the shipped go.mod (only
        # runs "go mod tidy"), so patch only if the old block is still there.
        build_sh = Path(build_path).read_text()
        if "rm -f go.mod" in build_sh:
            replace_in_file(
                self, build_path,
                "    rm -f go.mod\n    rm -f go.sum\n    go mod init github.com/amnezia-vpn/amnezia-libxray\n    go mod tidy\n",
                "    go mod download\n",
            )

    def build(self):
        self._patch_sources()
        if self.settings_build.os == "Windows":
            self.run("bash build.sh android")
        else:
            self.run("./build.sh android")
        # build.sh has no "set -e": a failed step still returns success and
        # leaves nothing behind, which only surfaces much later as a confusing
        # "file COPY cannot find libxray.aar" from CMake. Fail here instead.
        aar = os.path.join(self.build_folder, "libxray.aar")
        if not os.path.exists(aar):
            raise ConanException(
                "build.sh reported success but produced no libxray.aar"
            )

    def package(self):
        copy(self, "libxray.aar", src=self.build_folder, dst=os.path.join(self.package_folder, "aar"))

    def package_info(self):
        self.cpp_info.set_property("cmake_extra_variables", {
            "AMNEZIA_LIBXRAY_PATH": Path(self.package_folder, "aar", "libxray.aar").as_posix(),
        })
