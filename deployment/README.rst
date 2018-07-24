StarlingX Deployment in Virtualized Environments
================================================

A StarlingX system can be installed in a variety of platforms with the following
deployment options:

- Standard Controller

  - Dedicated Storage
  - Controller Storage

- All-in-one

  - Duplex
  - Simplex

Deployment options uses a variety of configurations based on 3 node identities:

- Controller
- Storage
- Compute

Standard Controller :: Dedicated Storage
----------------------------------------

The software installation workflow for an initial Ceph-backed block
storage on dedicated storage nodes is:

- Controller-0 Installation and Provisioning
- Controller-1 / Compute Host / Storage Host Installation
- Controller-1 Provisioning
- Provider Network Configuration
- Compute Host Provisioning
- Storage Host Provisioning

Standard Controller :: Controller Storage
-----------------------------------------

The software installation workflow for an initial LVM-backed block
storage on controller nodes is:

- Controller-0 Installation
- Controller-0 and System Provisioning
- Controller-1 / Compute Host Installation
- Controller-1 Provisioning
- Compute Host Provisioning

All-in-one :: Duplex
--------------------

The software installation workflow for two combined controller / compute
nodes is:

- Controller-0 Installation and Provisioning
- Controller-1 Installation and Provisioning

All-in-one :: Simplex
---------------------

The software installation workflow for a single combined controller / compute
node is:

- Controller-0 Installation and Provisioning

Virtualization Environments
---------------------------

The available virtualization products where StarlingX has been deployed
are:

- VirtualBox
- Libvirt/QEMU

Directory Structure
-------------------

Deployment directory hosts a total of 3 directories and 18 files::

    $ tree -L 3 deployment/
    deployment/
    ├── libvirt
    │   ├── compute.xml
    │   ├── controller_allinone.xml
    │   ├── controller.xml
    │   ├── destroy_allinone.sh
    │   ├── destroy_standard_controller.sh
    │   ├── install_packages.sh
    │   ├── setup_allinone.sh
    │   └── setup_standard_controller.sh
    ├── provision
    │   ├── simplex_stage_1.sh
    │   └── simplex_stage_2.sh
    └── virtualbox
        ├── all_in_one.conf
        ├── serial_vm.sh
        ├── setup_vm.sh
        ├── standard_controller.conf
        ├── start_vm.sh
        └── stop_vm.sh

Directory: libvirt
~~~~~~~~~~~~~~~~~~

Deployment under Libvirt/QEMU uses a set of xml files to define the node
identity:

- Controller All-in-one
- Controller
- Compute

These nodes are used to create the virtual machines and the network interfaces
to setup the StarlingX system:

- Setup All-in-one

  - 2 Controllers

- Setup Standard Controller

  - 2 Controllers
  - 2 Computes

Directory: virtualbox
~~~~~~~~~~~~~~~~~~~~~

Deployment under VirtualBox uses a set of configuration files to define the
StarlingX system:

- All-in-one Configuration
- Standard Controller Configuration

These configurations files are used to create the virtual machines and the
network interfaces from a single script:

- Setup VM

Directory: provision
~~~~~~~~~~~~~~~~~~~~

A set of scripts are provided to automate the provisioning of data interfaces and
local storage resources for the compute function for StarlingX Duplex or Simplex.
