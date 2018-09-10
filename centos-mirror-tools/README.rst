Create mirror for StarlingX
===========================

Step 1 - Run the container
--------------------------

At this point you had to build the StarlingX docker image. In opposite case
you should follow the instruction to build it `here <../README.rst>`_.

The container shall be run from the same directory where the other
scripts are stored.

.. code-block :: bash

    $ docker run -it -v $(pwd):/localdisk <your_docker_image_name>:<your_image_version> bash

As ``/localdisk`` is defined as the workdir of the container, the same
folder name should be used to define the volume. The container will
start to run and populate a ``logs`` and ``output`` folders in this
directory. The container shall be run from the same directory where the
other scripts are stored.

step 2 - Run the ``download_mirror.sh`` script
----------------------------------------------

Once inside the container run the downloader script

.. code-block :: bash

    $ cd localdisk && bash download_mirror.sh

NOTE: in case there are some downloading failures due to network
instability (or timeout), you should download them manually, to assure
you get all RPMs listed in "rpms\_from\_3rd\_parties.lst" and
"rpms\_from\_centos\_repo.lst".

step 3 - Copy the files to the mirror
-------------------------------------

After all downloading complete, copy the download files to mirror.

.. code-block :: bash

    $ find ./output -name "*.i686.rpm" | xargs rm -f
    $ chown  751:751 -R ./output
    $ cp -rf  output/stx-r1/ <your_mirror_folder>/

In this case ``<your_mirror_folder>`` can be whatever folder you want to
use as mirror.

step 4 - Tweaks in the StarlingX build system.
----------------------------------------------

NOTE: step below is not needed if you've synced the latest codebase.

Go into StarlingX build system (*another* container which hosts cgcs
build system), and follow up below steps:

Debugging issues
----------------

The ``download_mirror.sh`` script will create log files in the form of
``centos_rpms_*.txt``. After the download is complete, it's recommended
to check the content of these files to see if everything was downloaded
correctly.

A quick look into these files could be:

.. code-block :: bash

    $ cd output/
    $ cat *missing*

In this case, there shoudn't be any package in the "missing" files.
