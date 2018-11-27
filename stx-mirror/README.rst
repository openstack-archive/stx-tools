stx-mirror
=========

MirrorDownloader.py
---------------------
This is the Mirror Downloader proposal proof of concept.
Specfile: https://review.openstack.org/#/c/619631/

Container using Unified Dockerfile
---------------------

.. code-block:: bash

    pushd ..
    make
    popd

Running the Mirror Download tool
---------------------

.. code-block:: bash

   docker run -it -v $(pwd):/localdisk --rm <your_docker_image_name>:<your_image_version> python /localdisk/MirrorDownloader.py

Running Custom Hooks
---------------------
This script implements the dl_tarball.sh hooks in the current Mirror Download 
flow.

.. code-block:: bash

./custom_src_hook.sh

Results
---------------------
After tool completion, the packages will be stored in the output directory
and the logfile is LogMirrorDownloader.log. At the end of the logfile is the 
summary for missing packages.

Disclaimer
---------------------
- Manifest could not be up to date.
- This is not a complete implementation for stx-mirror tool.
