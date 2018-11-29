StarlingX Deployment on Libvirt
===============================

This is a quick reference for deploying StarlingX on libvirt/qemu systems.
It assumes you have a working libvirt/qemu installation for a non-root user
and that your user has NOPASSWD sudo permissions.

Refer also to pages "Installation Guide Virtual Environment", "Testing Guide"
on the StarlingX wiki: https://wiki.openstack.org/wiki/StarlingX

Overview
--------

We create 4 bridges to use for the STX cloud.  This is done in an initial step
separate from the VM management.

Depending on which basic configuration is chosen, we create a number of VMs
for one or more controllers and storage nodes.

These scripts are configured using environment variables that all have built-in
defaults.  On shared systems you probably do not want to use the defaults.
The simplest way to handle this is to keep an rc file that can be sourced into
an interactive shell that configures everything.  Here's an example::

	export CONTROLLER=madcloud
	export COMPUTE=madnode
	export BRIDGE_INTERFACE=madbr
	export EXTERNAL_NETWORK=172.30.20.0/24
	export EXTERNAL_IP=172.30.20.1/24

There is also a script ``cleanup_network.sh`` that will remove networking
configuration from libvirt.

Networking
----------

Configure the bridges using ``setup_network.sh`` before doing anything else. It
will create 4 bridges named ``stxbr1``, ``stxbr2``, ``stxbr3`` and ``stxbr4``.
Set the BRIDGE_INTERFACE environment variable if you need to change stxbr to
something unique.

The ``destroy_network.sh`` script does the reverse, and should not be used lightly.
It should also only be used after all of the VMs created below have been destroyed.

Controllers
-----------

There are two scripts for creating the controllers: ``setup_allinone.sh`` and
``setup_standard_controller.sh``.  They are operated in the same manner but build
different StarlingX cloud configurations. Choose wisely.

You need an ISO file for the installation, these scripts take a name with the
``-i`` option::

	./setup_allinone.sh -i stx-2018-08-28-93.iso

And the setup will begin.  The scripts create one or more VMs and start the boot
of the first controller, named oddly enough ``controller-0``.  If you have Xwindows
available you will get virt-manager running.
If not, Ctrl-C out of that attempt if it doesn't return to a shell prompt.
Then connect to the serial console::

	virsh console controller-0

Continue the usual StarlingX installation from this point forward.

Tear down the VMs using ``destroy_allinone.sh`` and ``destroy_standard_controller.sh``.
