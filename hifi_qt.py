import hifi_utils
import hifi_android
import hashlib
import os
import platform
import re
import shutil
import tempfile
import json
import xml.etree.ElementTree as ET
import functools

print = functools.partial(print, flush=True)

# Encapsulates the vcpkg system
class QtDownloader:
    CMAKE_TEMPLATE = """
# this file auto-generated by hifi_qt.py
get_filename_component(QT_CMAKE_PREFIX_PATH "{}" ABSOLUTE CACHE)
get_filename_component(QT_CMAKE_PREFIX_PATH_UNCACHED "{}" ABSOLUTE)

# If the cached cmake toolchain path is different from the computed one, exit
if(NOT (QT_CMAKE_PREFIX_PATH_UNCACHED STREQUAL QT_CMAKE_PREFIX_PATH))
    message(FATAL_ERROR "QT_CMAKE_PREFIX_PATH has changed, please wipe the build directory and rerun cmake")
endif()
"""
    def __init__(self, args):
        self.args = args
        self.configFilePath = os.path.join(args.build_root, 'qt.cmake')
        self.version = os.getenv('VIRCADIA_USE_QT_VERSION', '5.12.3')

        self.assets_url = hifi_utils.readEnviromentVariableFromFile(args.build_root, 'EXTERNAL_BUILD_ASSETS')

        defaultBasePath = os.path.expanduser('~/hifi/qt')
        self.basePath = os.getenv('HIFI_QT_BASE', defaultBasePath)
        if (not os.path.isdir(self.basePath)):
            os.makedirs(self.basePath)
        self.path = os.path.join(self.basePath, self.version)
        self.fullPath = os.path.join(self.path, 'qt5-install')
        self.cmakePath = os.path.join(self.fullPath, 'lib/cmake')

        print("Using qt path {}".format(self.path))
        lockDir, lockName = os.path.split(self.path)
        lockName += '.lock'
        if not os.path.isdir(lockDir):
            os.makedirs(lockDir)

        self.lockFile = os.path.join(lockDir, lockName)

        if (os.getenv('VIRCADIA_USE_PREBUILT_QT')):
            print("Using pre-built Qt5")
            return

        # OS dependent information
        system = platform.system()

        if 'Windows' == system:
            self.qtUrl = self.assets_url + '/dependencies/vcpkg/qt5-install-5.12.3-windows3.tar.gz%3FversionId=5ADqP0M0j5ZfimUHrx4zJld6vYceHEsI'
        elif 'Darwin' == system:
            self.qtUrl = self.assets_url + '/dependencies/vcpkg/qt5-install-5.12.3-macos.tar.gz%3FversionId=bLAgnoJ8IMKpqv8NFDcAu8hsyQy3Rwwz'
        elif 'Linux' == system:
            import distro
            dist = distro.linux_distribution()

            if distro.id() == 'ubuntu':
                u_major = int( distro.major_version() )
                u_minor = int( distro.minor_version() )

                if u_major == 16:
                    self.qtUrl = self.assets_url + '/dependencies/vcpkg/qt5-install-5.12.3-ubuntu-16.04-with-symbols.tar.gz'
                elif u_major == 18:
                    self.qtUrl = self.assets_url + '/dependencies/vcpkg/qt5-install-5.12.3-ubuntu-18.04.tar.gz'
                elif u_major == 19 and u_minor == 10:
                    self.qtUrl = self.assets_url + '/dependencies/vcpkg/qt5-install-5.12.6-ubuntu-19.10.tar.xz'
                elif u_major > 19:
                    print("We don't support " + distro.name(pretty=True) + " yet. Perhaps consider helping us out?")
                    raise Exception('LINUX DISTRO IS NOT SUPPORTED YET!!!')
                else:
                    print("Sorry, " + distro.name(pretty=True) + " is old and won't be officially supported. Please consider upgrading.");
                    raise Exception('UNKNOWN LINUX DISTRO VERSION!!!')
            else:
                print("Sorry, " + distro.name(pretty=True) + " is not supported. Please consider helping us out.")
                print("It's also possible to build Qt for your distribution, please see the documentation at:")
                print("https://github.com/vircadia/vircadia/tree/master/tools/qt-builder")
                raise Exception('UNKNOWN LINUX VERSION!!!')
        else:
            print("System      : " + platform.system())
            print("Architecture: " + platform.architecture())
            print("Machine     : " + platform.machine())
            raise Exception('UNKNOWN OPERATING SYSTEM!!!')

    def writeConfig(self):
        print("Writing cmake config to {}".format(self.configFilePath))
        # Write out the configuration for use by CMake
        cmakeConfig = QtDownloader.CMAKE_TEMPLATE.format(self.cmakePath, self.cmakePath).replace('\\', '/')
        with open(self.configFilePath, 'w') as f:
            f.write(cmakeConfig)

    def installQt(self):
        if not os.path.isdir(self.fullPath):
            print ('Downloading Qt from AWS')
            print('Extracting ' + self.qtUrl + ' to ' + self.path)
            hifi_utils.downloadAndExtract(self.qtUrl, self.path)
        else:
            print ('Qt has already been downloaded')
