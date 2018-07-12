import os
import subprocess
import getpass
import sys

ERRORCODE = 0 # 0 - Success, 1 - Mismatch, 2 - File not found

class SrpmInfo:
    """
    SrpmInfo has a name, mirror location and full path
    """
    def __init__(self, name, location="NotFound", fullpath=""):
        """
        Initialize SrpmInfo object
        """
        self.name = name
        self.location = location
        self.fullpath = fullpath

    def __str__(self):
        """
        Return information about SrpmInfo object
        """
        return "Name: {}\nLocation: {}\nFull Path: {}\n".format(self.name,
                                                                self.location,
                                                                self.fullpath)
    def print_with_comment_if_not_found(self, comment=""):
        """
        Prints the full path of an SrpmInfo object if it doesn't have
        location, followed by a comment provided by the user.
        """
        if self.location == "NotFound":
            print(">>> {} {}".format(self.fullpath, comment))


class MirrorInfo:
    """
    MirrorInfo has a path and a list of srpms
    """
    def __init__(self, path, srpms=None):
        """
        Initialize MirrorInfo object
        """
        self.path = path
        self.srpms = srpms

    def __str__(self):
        """
        Return information about MirrorInfo object
        """
        return "MirrorInfo: {} {}".format(self.path, self.srpms)

class DependenciesReviewer:
    """
    DependenciesReviewer class reviews the content in stx-'s
    */centos/srpm_path matches with the information in the mirror's lists.
    If there are modules that does not match, the DependenciesReviewer can
    display the information.
    """
    def __init__(self, modulepath=os.path.abspath(".."),
                 mirrorpath=os.path.abspath(".")):
        self.modulepath = modulepath
        self.mirrorpath = mirrorpath
        self._srpms_dict = {}
        self._srpms_list = []
        self._missing_srpms_list = []

    def __str__(self):
        return "DependenciesReviewer: {} {} {}".format(self.modulepath,
                                                       self.mirrorpath)

    # Find mirror location for the SRPMs listed in the module
    def _find_elements(self, srpmsdict, mirror_list, mirror_path):
        """
        Fill the dictionary with the location in the mirror's list
        """
        for key, value in srpmsdict.items():
            for i in range(0, len(value)):
                if value[i].name in mirror_list:
                    #value[i].location = mirror_path
                    srpmsdict[key][i].location = mirror_path
        return srpmsdict

    def _get_content(self, path):
        """ Get path's content as a list """
        try:
            text = open(path).read()
            text_list = text.split("\n")
            text_list = list(filter(None, text_list))
            return text_list
        except FileNotFoundError:
            print("Mirror lst file not found {}".format(path.split("/")[-1]))
            ERRORCODE = 2 # Meaning file not found
            return []

    def check_missing(self):
        """
        Solve the dependencies
        """
        # Get SrpmInfo dictionary and list needed by this DependenciesReviewer
        # Get all srpm_path files in the module
        # MODULE
        paths = subprocess.check_output(['find', self.modulepath,
                                         '-wholename',
                                         '*/centos/srpm_path'])
        paths = paths.decode('utf-8')
        module_paths_list = paths.split("\n")
        module_paths_list = list(filter(None, module_paths_list))

        # Fill dictionary and list with content from srpm_path files
        for path in module_paths_list:
            srpm_text = open(path).read()
            srpm_text_list = srpm_text.split("\n")
            srpm_text_list = list(filter(None, srpm_text_list))

            if not srpm_text_list:
                print(">No content in srpm_path: "+path)
            else:
                temp = []
                for i in range(0, len(srpm_text_list)):
                    if "mirror:" in srpm_text_list[i]:
                        srpmname = srpm_text_list[i].split("/")[-1]
                        temp.append(SrpmInfo(srpmname, location="NotFound",
                                             fullpath=srpm_text_list[i]))
                        self._srpms_list.append(srpmname)
            self._srpms_dict[path] = temp

        # MIRROR
        # Get MirrorInfo objects needed by this DependenciesReviewer
        _other_mirror = MirrorInfo(os.path.join(self.mirrorpath,
                                                "other_downloads.lst"))
        _third_mirror = MirrorInfo(os.path.join(self.mirrorpath,
                                                "rpms_from_3rd_parties.lst"))
        _centh_mirror = MirrorInfo(os.path.join(self.mirrorpath,
                                                "rpms_from_centos_3rd_parties.lst"))
        _cenre_mirror = MirrorInfo(os.path.join(self.mirrorpath,
                                                "rpms_from_centos_repo.lst"))

        # Get SRPMs from mirror list
        _other_mirror.srpms = self._get_content(_other_mirror.path)
        _third_mirror.srpms = self._get_content(_third_mirror.path)
        _centh_mirror.srpms = self._get_content(_centh_mirror.path)
        _cenre_mirror.srpms = self._get_content(_cenre_mirror.path)

        # Third Party Repo particular clean up to get the rpm name
        for i in range(0, len(_third_mirror.srpms)):
            _third_mirror.srpms[i] = _third_mirror.srpms[i].split("#")[0]

        # Find in the mirror paths the SRPMs and set the location
        self._srpms_dict = self._find_elements(self._srpms_dict,
                                               _third_mirror.srpms,
                                               _third_mirror.path)
        self._srpms_dict = self._find_elements(self._srpms_dict,
                                               _centh_mirror.srpms,
                                               _centh_mirror.path)
        self._srpms_dict = self._find_elements(self._srpms_dict,
                                               _cenre_mirror.srpms,
                                               _cenre_mirror.path)

        # Leave on the list only the missing SRPMs
        self._missing_srpms_list = [element for element in self._srpms_list
                                    if element not in _other_mirror.srpms
                                    and element not in _third_mirror.srpms
                                    and element not in _centh_mirror.srpms
                                    and element not in _cenre_mirror.srpms]

    def how_many_missing(self):
        """
        Return the number of missing RPMs
        """
        return len(self._missing_srpms_list)

    def show_missing(self):
        """
        Show the DependenciesReviewer results based on how it was initialized
        """
        for key, value in self._srpms_dict.items():
            for i in range(0, len(value)):
                value[i].print_with_comment_if_not_found(key)

if __name__ == "__main__":
    USER = getpass.getuser()
    WORK = os.path.abspath("..")
    MOP = os.path.join(WORK, "cgcs-root/stx/")
    MIP = os.path.join(WORK, "stx-tools/centos-mirror-tools")
    try:
        directories = os.listdir(MOP)
    except FileNotFoundError:
        print("Directory not found {}".format(MOP))
        ERRORCODE = 2 # Meaning file not found

    if ERRORCODE == 0:
        stx_directories = []
        for directory in directories:
            if "stx-" in directory:
                A = DependenciesReviewer(modulepath=os.path.join(MOP, directory),
                                         mirrorpath=MIP)
                A.check_missing()
                if A.how_many_missing() > 0:
                    print("Missing SRPMs in module: "+directory)
                    A.show_missing()
                    if ERRORCODE != 2:
                        ERRORCODE = 1 # Meaning there are missing SRPMs
                else:
                    continue
                    #print("List empty: "+directory)
    if ERRORCODE == 0:
        print("All SRPMs in stx-* repos were found in Mirror's lists.")
    sys.exit(ERRORCODE)
