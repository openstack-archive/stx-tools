# stx-tools

StarlingX Build Tools

The StarlingX build process is tightly tied to CentOS in a number of ways,
doing the build inside a Docker container makes this much easier on other
flavors of Linux.

## Container Build Preparation
We will use a copy of your existing `.gitconfig` in the container to pick up existing
configuration.  The StarlingX build system also has some specific requirements that
do not need to be in your personal `.gitconfig`.  Copy it into `toCOPY` to be picked
up in the container build.
```
cp ~/.gitconfig toCOPY
```

## Configuration
tbuilder uses a two-step configuration process that provides access to certain
configuration values both inside and outside the container.  This is extremely
useful for path variables such as `MY_REPO` with have different values inside
and outside but can be set to point to the same place.

The `buildrc` file is a shell script that is used to set the default configuration
values.  It is contained in the tbuilder repo and should not need to be modified by
users as it reads a `localrc` file that will not be overwritten by tbuilder updates.
This is where users should alter the default settings.

### Sample `localrc`
```
# tbuilder localrc

MYUNAME=stx-builder
PROJECT=stx-work
HOST_PREFIX=$HOME/work

```

## Makefile
tbuilder contains a Makefile that can be used to automate the build lifecycle
of a container.  The commands below are handled by the Makefile and will read the
contents of the `buildrc` file.

The targets commonly used are:
* build - build the Docker images as required (This includes dev-centos, to build
  just the base dev image use target `base-build`.)
* clean - remove the stx-builder image (The dev-centos image is not removed, use
  `base-clean` to do that)

## Base Container Build
The container build has been split into two parts to simplify iterating on build development.
The basic CentOS image and the nearly 500 required development packages are pre-installed
into a base image (`local/dev-centos:7.3`) that is then used for the StarlingX builder-specific
bits.
```
make base-build
```
will run essentially the following manual build command:
```
docker build \
    --ulimit core=0 \
    -t local/dev-centos:7.3 \
    -f Dockerfile.centos73 \
    .
```

## STX Builder Container Build
StarlingX Builder container images are tied to your UID so image names should include your
username.
```
make build
```


#### NOTE:
* Do NOT change the UID to be different from the one you have on your host or things
  will go poorly. i.e. do not change `--build-arg MYUID=$(id -u)`

* The Dockerfile needs MYUID and MYUNAME defined, the rest of the configuration is
  copied in via buildrc/localrc.

## Use the Builder Container
The `tb.sh` script is used to manage the run/stop lifecycle of working containers.
Copy it to somewhere on your `PATH`, say `$HOME/bin` if you have one, or maybe
`/usr/local/bin`.

The basic workflow is to create a working directory for a particular build,
say a specific branch or whatever.  Copy the `buildrc` file from the tbuilder repo
to your work directory and create a `localrc` if you need one. The current
working directory is assumed to be this work directory for all `tb.sh` commands.
You switch projects by switching directories.

By default `LOCALDISK` will be placed under the directory pointed to by `HOST_PREFIX`,
which defaults to `$HOME/starlingx`.

The `tb.sh` script uses sub-commands to select the operation:
* `run` - Runs the container in a shell. It will also create `LOCALDISK` if it does not exist.
* `stop` - Kills the running shell.
* `exec` - Starts a shell inside the container.

You should name your running container with your username.  tbuilder does this automatically
using the `USER` environment variable.

`tb.sh run` will create `LOCALDISK` if it does not already exist before starting the
container.

Set the mirror directory to the shared mirror pointed to by `HOST_MIRROR_DIR`.  The mirror
is LARGE, if you are on a shared machine use the shared mirror.  For example you could set
the default value for `HOST_MIRROR_DIR` to
`/home/starlingx/mirror` and share it.

### Running the Container
Start the builder container:
```
tb.sh run
```
or by hand:
```
docker run -it --rm \
    --name ${TC_CONTAINER_NAME} \
    --detach \
    -v ${LOCALDISK}:${GUEST_LOCALDISK} \
    -v ${HOST_MIRROR_DIR}:/import/mirrors:ro \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v ~/.ssh:/mySSH:ro \
    -e "container=docker" \
    --security-opt seccomp=unconfined \
    ${TC_CONTAINER_TAG}
```

### Running a Shell Inside the Container
Since running the container does not return to a shell prompt the exec into the container
must be done from a different shell:
```
tb.sh exec
```
or by hand:
```
docker exec -it --user=${MYUNAME} ${USER}-centos-builder bash
```

#### Notes:
* The above will reusult in a running container in systemd mode. It will have NO login.
* I tend to use tmux to keep a group of shells related to the build container
* `--user=${USER}` is the default username, set `MYUNAME` in `buildrc` to change it.

### Stop the Container
```
tb.sh stop
```
or by hand:
```
docker kill ${USER}-centos-builder
```

## What to do to build from WITHIN the container

### To make git cloning less painful
```
$ eval $(ssh-agent)
$ ssh-add
```

### To start a fresh source tree

#### Instructions

# Initialize the source tree.
```
cd $MY_REPO_ROOT_DIR
repo init -u git@git.openstack.org:openstack/stx-manifest.git -m stx-manifest.xml
repo sync
```

### To generate cgcs-centos-repo

The cgcs-centos-repo is a set of symbolic links to the packages in the mirror
and the mock configuration file. It is needed to create these links if this is
the first build or the mirror has been updated.

```
generate-cgcs-centos-repo.sh /import/mirror/CentOS/pike
```

Where the argument to the script is the path of the mirror.


### To build all packages:
```
$ cd $MY_REPO
$ build-pkgs or build-pkgs --clean <pkglist>; build-pkgs <pkglist>
```

### To generate cgcs-tis-repo:

The cgcs-tis-repo has the dependency information that sequences the build
order; To generate or update the information the following command needs
to be executed after building modified or new packages.
```
$ generate-cgcs-tis-repo
```

### To make an iso:
```
$ build-iso
```

### First time build

The entire project builds as a bootable image which means that the resulting ISO needs the boot files (initrd, vmlinuz, etc) that are also built by this build system. The symptom of this issue is that even if the build is successful, the ISO will be unable to boot.

For more specific instructions on how to solve this issue, please the README on `installer` folder in `stx-beas` repository.

## WARNING HACK WARNING
* Due to a lack of full udev support in the current build container, you need to do the following:
```
$ cd $MY_REPO
$ rm build-tools/update-efiboot-image
$ ln -s /usr/local/bin/update-efiboot-image $MY_REPO/build-tools/update-efiboot-image
```
  * if you see complaints about udisksctl not being able to setup the loop device or not being able to mount it, you need to make sure the build-tools/update-efiboot-image is linked to the one in /usr/local/bin

## Troubleshooting
* if you see:
```
Unit tmp.mount is bound to inactive unit dev-sdi2.device. Stopping, too.
```
  * it's a docker bug. just kill the container and restart the it using a different name.
    * I usually switch between <uname>-centos-builder and <uname>-centos-builder2. It's some kind of timeout (bind?) issue.
