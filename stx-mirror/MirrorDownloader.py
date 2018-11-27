"""
MirrorDownloader

The objective of this module is to download packages needed to build
StarlingX ISO.
"""

import logging
import os
import threading
import subprocess
from Queue import Queue
import yaml
from rpmUtils.miscutils import splitFilename

LOCALDISKDIR = "/localdisk"

CONFIG = {"base": os.path.join(LOCALDISKDIR, "output"),
          "stxrel": "stx-r1",
          "distro": "CentOS",
          "osrel": "pike",
          "otherurl": "http://vault.centos.org/7.4.1708/os/x86_64/",
          "maxthreads": 4,
          "logFilename": os.path.join(LOCALDISKDIR, "LogMirrorDownloader.log"),
          "input": os.path.join(LOCALDISKDIR, "manifest.yaml")}

logging.basicConfig(filename=CONFIG["logFilename"],
                    level=logging.DEBUG,
                    format='%(asctime)s [%(levelname)-5s] %(threadName)-10s: %(message)s',
                    datefmt='%a, %d %b %Y %H:%M:%S')

RET_QUEUE = Queue()


class Package:
    """
    Package class
    """
    def __init__(self, pkg_info, pkg_cmd):
        """
        Package class constructor
        :param: pkg_info: package name
        :param: pkg_cmd: download command
        """
        self._info = pkg_info
        self._cmd = pkg_cmd

    def get_cmd(self):
        """
        Returns the download command
        """
        return self._cmd

    def set_cmd(self, cmd):
        """
        Sets the download command
        """
        self._cmd = cmd

    def get_info(self):
        """
        Returns package info
        """
        return self._info


class Manifest:
    """
    Manifest class
    """
    def __init__(self, config):
        """
        Manifest class constructor
        :param: config
        """
        self._name = "Manifest"
        self._packages = []
        self._conf = config
        self._basedir = os.path.join(self._conf["base"],
                                     self._conf["stxrel"],
                                     self._conf["distro"],
                                     self._conf["osrel"])

    def get_packages(self):
        """
        Return a list with the packages in this Manifest
        """
        return self._packages

    def add_package(self, package):
        """
        Add a new package to the Manifest
        :param: package to be added
        """
        self._packages.append(package)

    def num_packages(self):
        """
        Returns number of packages in this Manifest
        """
        return len(self._packages)

    def create_manifest(self):
        """
        Create Manifest based on input provided in Config structure
        """
        _, _extension = os.path.splitext(self._conf['input'])
        if _extension == ".yaml":
            self._handle_yaml(self._conf['input'])
        else:
            logging.info('File type not supported: {}'.format(_extension))

    def _get_wget_cmd(self, link, destdir, timeout_sec=30):
        """
        Make wget command for a package
        :param: link: package link
        :param: destdir: destination directory for downloaded package
        """
        cmd = 'wget -q {} -P {} --connect-timeout={}'.format(link,
                                                             destdir,
                                                             timeout_sec)
        return cmd

    def _centos(self, pkg):
        """
        Make download command for a CentOS package
        :param: pkg: package information for downloading
        """
        downloader = 'sudo -E yumdownloader'
        conf = '-q -C --releasever=7'
        (_n, _v, _r, _e, _a) = splitFilename(pkg)
        pkg = '{}-{}-{}'.format(_n, _v, _r)
        if _a == 'src':
            arch = '--source'
            package_dir = '--destdir {}/Source'.format(self._basedir)
        else:
            arch = '-x \*i686 --archlist=noarch,x86_64'
            package_dir = '--destdir {}/Binary/{}'.format(self._basedir, _a)

        cmd = '{} {} {} {} {}'.format(downloader, conf, arch, pkg, package_dir)
        return cmd

    def _3rdparty(self, url):
        """
        Make download command for a 3rdParty package
        :param: url: package url for downloading
        """
        pkg = url.split('/')[-1]
        (_n, _v, _r, _e, _a) = splitFilename(pkg)
        if _a == "src":
            pkgdir = '{}/Source'.format(self._basedir)
        else:
            pkgdir = '{}/Binary/{}'.format(self._basedir, _a)
        cmd = self._get_wget_cmd(url, pkgdir)
        return cmd

    def _boot(self, pkgline):
        """
        Make download command for a Boot package
        :param: pkgline: package for downloading
        """
        last = len("http://vault.centos.org/7.4.1708/os/x86_64/")
        pkg = pkgline[last:]
        bootdir = os.path.dirname(pkg)
        bootdir = os.path.join(self._basedir, "Binary", bootdir)
        cmd = self._get_wget_cmd(pkgline, bootdir)
        return cmd

    def _customized(self, pkgline):
        """
        Make download command for a Customized package
        :param: pkgline: package for downloading
        """
        downloadsdir = os.path.join(self._basedir, "downloads")
        cmd = self._get_wget_cmd(pkgline, downloadsdir)
        return cmd

    def _maven_artifacts(self, pkgline):
        """
        Make download command for a Maven Artifact
        :param: pkgline: package for downloading
        """
        downloadsdir = os.path.join(self._basedir, "downloads")
        cmd = self._get_wget_cmd(pkgline, downloadsdir)
        return cmd

    def _handle_yaml(self, yaml_file):
        """
        Handle yaml file for downloading
        :param: yaml_file
        """
        with open(yaml_file, 'r') as _file:
            lines = _file.read()
        lines = yaml.load(lines)

        switcher = {
            'CentOS': self._centos,
            'CentOS3rdParty': self._centos,
            '3rdParty': self._3rdparty,
            'Boot': self._boot,
            'Customized': self._customized,
            'MavenArtifacts': self._maven_artifacts,
        }

        for line in lines:
            package_type = line['name']
            for package_line in line['packages']:
                if switcher.has_key(package_type):
                    cmd = switcher[package_type](package_line)
                    self.add_package(Package(package_line, cmd))


class DownloadReturn:
    """
    DownloadReturn class
    """
    def __init__(self, cmd):
        """
        DownloadReturn constructor
        :param: cmd: command
        """
        self._cmd = cmd
        self._ret = None

    def get_cmd(self):
        """
        Returns command
        """
        return self._cmd

    def get_retcode(self):
        """
        Returns retcode
        """
        return self._ret

    def set_pass(self):
        """
        Sets pass
        """
        self._ret = 0

    def set_fail(self):
        """
        Sets fail
        """
        self._ret = 1


class DownloadWorker(threading.Thread):
    """
    DownloadWorker class
    """

    def __init__(self, threadName, cmd):
        """
        DownloadWorker constructor
        """
        threading.Thread.__init__(self, name=threadName, )
        self._cmd = cmd

    def run(self):
        """
        Executes the command passed to DownloadWorker
        """
        try:
            output = subprocess.check_output(self._cmd,
                                             shell=True,
                                             stderr=subprocess.STDOUT)
            output = output.decode('UTF-8')
        except subprocess.CalledProcessError:
            logging.error(self._cmd)
            ret = DownloadReturn(self._cmd)
            ret.set_fail()
        else:
            msg = 'Command: {} Output: {}'.format(self._cmd, output)
            logging.info(msg)
            ret = DownloadReturn(self._cmd)
            ret.set_pass()
        RET_QUEUE.put(ret)


class MirrorDownloader:
    """
    MirrorDownloader class
    """
    def __init__(self, config, manif):
        """
        MirrorDownloader constructor
        """
        self._conf = config
        self._manifest = manif
        self._basedir = ""

    def download(self):
        """
        download function, this calls the other download functions
        """
        self.set_structure(self._conf['stxrel'],
                           self._conf["distro"],
                           self._conf['osrel'])

        if self._conf["distro"] == "CentOS":
            logging.info("yum -q makecache")
            subprocess.check_output('yum -q makecache',
                                    shell=True,
                                    stderr=subprocess.STDOUT)

        logging.info('Using %d CPUs', self._conf['maxthreads'])
        packages = self._manifest.get_packages()
        counter = 0
        total_pkgs = len(packages)
        thread_list = []
        while counter < total_pkgs:
            current_threads = threading.activeCount()
            if current_threads <= self._conf["maxthreads"]:
                dlcmd = packages[counter].get_cmd()
                worker = DownloadWorker(threadName='Thread-{}'.format(counter),
                                        cmd=dlcmd)
                worker.start()
                thread_list.append(worker)
                counter += 1
            else:
                for thread in thread_list:
                    if not thread.is_alive():
                        thread_list.remove(thread)

        for thread in thread_list:
            thread.join()

        self.check_download()

    def set_structure(self, stx_release, os_distribution, openstack_version):
        """
        creates directory structure based on stx release, os and
        openstack release name
        """
        base = self._conf['base']

        self._basedir = os.path.join(base, stx_release, os_distribution,
                                     openstack_version)
        bin_path = os.path.join(self._basedir, "Binary")
        dl_path = os.path.join(self._basedir, "downloads")
        src_path = os.path.join(self._basedir, "Source")

        for dirpath in [bin_path, dl_path, src_path]:
            try:
                os.makedirs(dirpath)
            except OSError:
                logging.debug('Directory exists: %s', dirpath)

    def check_download(self):
        """
        Check the download results
        how many packages were downloaded versus how many packages are in the
        Manifest
        """
        logging.info("Check download...")
        missed_num = 0
        while not RET_QUEUE.empty():
            result = RET_QUEUE.get()
            if result.get_retcode():
                logging.error('Failed commands: %s', result.get_cmd())
                missed_num = missed_num + 1
        logging.error('Number of failed commands %d', missed_num)

    def check_mirror(self):
        """
        check_mirror
        gives information about what packages in the manifest are not in the
        mirror
        """
        path = self._conf['base']
        in_mirror = []
        for (_, _, filenames) in os.walk(path):
            in_mirror.extend(filenames)

        in_manifest = []
        package_list = self._manifest.get_packages()
        for package in package_list:
            package_info = package.get_info()
            tmp = package_info.split('/')[-1]
            in_manifest.append(tmp)

        results = list(set(in_manifest) - set(in_mirror))
        return results


if __name__ == "__main__":
    logging.info("Starting program")
    MANIFEST = Manifest(CONFIG)
    MANIFEST.create_manifest()
    if MANIFEST.num_packages():
        logging.info('Manifest created successfully')
        DL_MIRROR = MirrorDownloader(CONFIG, MANIFEST)
        logging.info('Starting download')
        DL_MIRROR.download()
        MISSING = DL_MIRROR.check_mirror()
        if MISSING:
            logging.info("Manifest is not complete in this mirror.")
            logging.error('Number packages missing: %d', len(MISSING))
            logging.error('Packages missing: %s', MISSING)
        else:
            logging.info("Manifest is complete in this mirror.")
    else:
        logging.error("Could not create a Manifest")
