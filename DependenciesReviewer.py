import os
import subprocess
import getpass
import sys

# Error codes
SUCCESS = 0
RPMMISMATCH = 1
FILENOTFOUND = 2
ERRORCODE = SUCCESS

# Log file
results = open("dependenciesreviewer.log", "a")

# Parametrized variables
SELECT = {"centos" : {"name":"centos",
                      "dependencies":"srpm_path",
                      "prefix": "rpms_"
                     },
         }
DISTRO = SELECT["centos"]

# Global variables
USER = getpass.getuser()
WORK = os.path.abspath("..")
REPOS = os.path.join(WORK, "cgcs-root/stx/")
MTOOLS = os.path.join(WORK, "stx-tools/centos-mirror-tools")

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
            print(">>> {} {}".format(self.fullpath, comment), file=results)


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
            print("Mirror lst file not found {}".format(path.split("/")[-1]),
                  file=results)
            ERRORCODE = FILENOTFOUND
            return []

    def check_missing(self):
        """
        Solve the dependencies
        """
        # MODULE
        # Get all srpm_path files in the module
        vardir = os.path.join("*", DISTRO["name"], DISTRO["dependencies"])
        paths = subprocess.check_output(['find',
                                         self.modulepath,
                                         '-wholename',
                                         vardir])
        paths = paths.decode('utf-8')
        module_paths_list = paths.split("\n")
        module_paths_list = list(filter(None, module_paths_list))

        # Fill dictionary and list with content from srpm_path files
        for path in module_paths_list:
            srpm_text = open(path).read()
            srpm_text_list = srpm_text.split("\n")
            srpm_text_list = list(filter(None, srpm_text_list))

            if not srpm_text_list:
                print(">No content in srpm_path: "+path, file=results)
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
        # Generate list of MirrorInfo objects, which is needed for the review
        var = os.listdir(self.mirrorpath)
        var = [x for x in var if DISTRO["prefix"] in x]
        _srpm_mirror = []
        for elem in var:
            # Get package's content
            _tmp_path = os.path.join(self.mirrorpath, elem)
            _tmp_srpms = self._get_content(_tmp_path)
            # Do particular clean up for 3rd party packages' names
            if elem == "rpms_from_3rd_parties.lst":
                _tmp_srpms = [x.split("#")[0] for x in _tmp_srpms]
            # Create a list with the Mirror Info
            _srpm_mirror.append(MirrorInfo(path=_tmp_path, srpms=_tmp_srpms))

        # MATCHING
        # Finding Packages in the mirror
        for mirr in _srpm_mirror:
            # Fill the dictinoary with the location
            self._srpms_dict = self._find_elements(self._srpms_dict,
                                                   mirr.srpms,
                                                   mirr.path)
            # Leave on the list only the missing SRPMs
            self._srpms_list = [element for element in self._srpms_list
                                if element not in mirr.srpms]

    def how_many_missing(self):
        """
        Return the number of missing RPMs
        """
        return len(self._srpms_list)

    def show_missing(self):
        """
        Show the DependenciesReviewer results based on how it was initialized
        """
        for key, value in self._srpms_dict.items():
            #import pdb; pdb.set_trace()
            for i in range(0, len(value)):
                value[i].print_with_comment_if_not_found(key)

if __name__ == "__main__":
    try:
        directories = os.listdir(REPOS)
    except FileNotFoundError:
        print("Directory not found {}".format(REPOS), file=results)
        ERRORCODE = FILENOTFOUND

    if ERRORCODE == SUCCESS:
        stx_directories = []
        for directory in directories:
            if "stx-" in directory:
                A = DependenciesReviewer(modulepath=os.path.join(REPOS, directory),
                                         mirrorpath=MTOOLS)
                A.check_missing()
                if A.how_many_missing() > 0:
                    print("Missing SRPMs in module: "+directory, file=results)
                    A.show_missing()
                    if ERRORCODE != FILENOTFOUND:
                        ERRORCODE = RPMMISMATCH
                else:
                    continue
    if ERRORCODE == SUCCESS:
        print("All SRPMs in stx-* repos were found in Mirror's lists.",
              file=results)
    sys.exit(ERRORCODE)
