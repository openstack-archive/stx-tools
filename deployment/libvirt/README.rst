Madawaska Installation Using libvirt/kvm
========================================

Install OS
----------

Freshly Install Ubuntu 16.04.03 Desktop 64bit.

Note: PXE boot in kvm may not work if OS is not freshly installed.

Install Packages
-----------------

#./install_packages.sh


Install Madawaska
------------------

copy ISO to this directory

#./setup_tic.sh

Cleanup
-------

#./destroy_tic.sh
