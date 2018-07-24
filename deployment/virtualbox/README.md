# tic_vb

Here we provide kvm sample configurations &amp; scripts for TiC installation.

## Table of Contents
- [Assumptions](#assumptions)
- [Steps for multinode](#steps-for-multinode)
- [Steps for Simplex R5](#steps-for-simplex-r5)

## Assumption

1. Make sure you have at least 32G memory on your host PC.
2. VirturalBox and libvirt cannot run at the same time. Please close VirtualBox before running the libvirt creation scripts.

## Install libvirt

The configurations and scripts are tested on Ubuntu 16.04.3. Use of these configurations and scripts should have the following packages installed on the host OS:

- get tic_vb code:
   ```
   $ git clone https://github.intel.com/Madawaska/tic_vb
   ```

- install libvirt
   ```
   $ cd tic_vb/libvirt
   $ ./install_packages.sh
   ```

## Steps for multinode

1. create kvm for deployment:
The code to create kvms is under tic_vb/libvirt.
Config the controller/compute node memory size using controller.xml/compute.xml.
Config the disc size in setup_tic.sh, the sizes are hard coded like below:
   ```
   sudo qemu-img create -f qcow2 /var/lib/libvirt/images/controller-0-0.img 200G
   ```
You can modify the actual size for discs.
After all configurations done, please run the following script to create the kvms.
   ```
   $ ./setup_tic.sh
   ```

2. In the window of controller-0, please choose "Standard Controller - Graphic Console - Standard Security" to install the TiC.
Note: you may need to double click the controller-0 in the virt-manager window to open the kvm window.

3. After installation, please login with wrsroot/wrsroot. You're required to change the password for the first time login.

4. Applying controller configuration

   On the controller-0 node, run the following to configure controller-0. In this example, we accept all the default values.
   ```
   controller $ sudo config_controller
   ```
   Note: the default ip of the controller-0 node is 10.10.10.3.

5. Add remaining nodes into host inventory
You can get the MAC address of the compute node with the following cmd:
   ```
   $ virsh domiflist compute-0 | grep virbr2
   ```
On controller node, add the compute nodes as hosts, cmdline sample like below:
   ```
   controller $ source /etc/nova/openrc
   ~(keystone_admin)$ system host-add -n compute-0 -p compute -m 08:00:27:D3:B6:0A
      #               system host-add -n <node_name> -p compute -m <MAC>
   ```

6. Start compute nodes

Double click the compute nodes kvms in the virt-manager window.

Then click the run button.
Or run the following cmdline:
   ```
   $ sudo virsh start compute-0
   ```

   The compute nodes will install OS automatically through pxeboot. It may need several minutes to complete the installation, you can query the compute host installation status by `system host-show` or `system host-list` on controller-0 node:
   ```
   controller $ source /etc/nova/openrc
   ~(keystone_admin)$ system host-show compute-0 | grep install
   | install_output      | text                                 |
   | install_state       | installing                           |
   | install_state_info  | 712/1047                             |
   ~(keystone_admin)$ system host-list
   +----+--------------+-------------+----------------+-------------+--------------+
   | id | hostname     | personality | administrative | operational | availability |
   +----+--------------+-------------+----------------+-------------+--------------+
   | 1  | controller-0 | controller  | unlocked       | enabled     | available    |
   | 2  | compute-0    | compute     | locked         | disabled    | online       |
   +----+--------------+-------------+----------------+-------------+--------------+
   ```
   After the compute-0 have been successfully installed and rebooted, you'll find it's in online but locked status.

   If you have configured to have multiple compute nodes, you'll need to start each compute node.

7. Before doing the following steps, please check the controller status:
   ```
   controller $ source /etc/nova/openrc
   ~(keystone_admin)$ system host-list
   ```

   If the controller-0 is locked, please unlock the controller.
   ```
   controller $ source /etc/nova/openrc
   ~(keystone_admin)$ system host-unlock controller-0
   ```

   After the controller rebooted from the unlock operation, please check the nova services.
   If any of the services are in a wrong status (Status = "disabled", State = "down", Forced down = "True") like below, please manually enable those services with the ID in the first column. And then you may need to wait for a while for all the services enabled and started normally.
   ```
   controller $ source /etc/nova/openrc
   ~(keystone_admin)$ nova service-list
   +--------------------------------------+------------------+--------------+----------+----------+-------+----------------------------+-----------------+-------------+
   | Id                                   | Binary           | Host         | Zone     | Status   | State | Updated_at                 | Disabled Reason | Forced down |
   +--------------------------------------+------------------+--------------+----------+----------+-------+----------------------------+-----------------+-------------+
   | 48904e79-487c-4bae-9089-67b8f5dabeed | nova-compute     | r0-compute-0 | nova     | disabled | down  | 2018-04-28T01:00:38.306969 | -               | True        |
   | b860c694-3a49-4098-988d-264c073bedc7 | nova-compute     | r0-compute-1 | nova     | disabled | down  | 2018-04-28T01:00:38.361046 | -               | True        |
   | ded3fded-e1c3-4213-a5e5-118f3f9202a8 | nova-conductor   | controller-0 | internal | enabled  | up    | 2018-04-28T01:11:06.645148 | -               | False       |
   | 6d5f0632-6cab-4d48-8b81-5e9a75a59f29 | nova-consoleauth | controller-0 | internal | enabled  | up    | 2018-04-28T01:11:03.920276 | -               | False       |
   | 1b2ce94a-30b6-4569-92d9-5616196d8465 | nova-scheduler   | controller-0 | internal | enabled  | up    | 2018-04-28T01:11:04.731645 | -               | False       |
   +--------------------------------------+------------------+--------------+----------+----------+-------+----------------------------+-----------------+-------------+
   ~(keystone_admin)$ nova service-force-down --unset 48904e79-487c-4bae-9089-67b8f5dabeed
   ~(keystone_admin)$ nova service-force-down --unset b860c694-3a49-4098-988d-264c073bedc7
   ~(keystone_admin)$ nova service-enable 48904e79-487c-4bae-9089-67b8f5dabeed
   ~(keystone_admin)$ nova service-enable b860c694-3a49-4098-988d-264c073bedc7
   ```

   Or you can do it with the script:
   ```
   controller $ ./check_nova_services.sh
   ```


8. Provision compute nodes with network and storage, and unlock the compute node

   On host, copy the provision script to controller-0 node
   ```
   $ scp provisioning_scripts/provision_compute.sh wrsroot@10.10.10.3:~/
   ```
   On controller-0 node, run the provision script. This script will create the a provider network and provision each compute node with the provider network and local storage, and unlock the compute node. After unlock, the compute nodes will be rebooted. It may take some time to reboot the compute nodes and deploy configurations, please be patient. You could check compute nodes status with `system host-list` on controller-0 node or launch a browser on host to access horizon at http://10.10.10.2 to view the status.
   ```
   controller $ ./provision_compute.sh
   # be patient and wait for all compute nodes reboot after unlock
   ```
   Note: if you met an unlocking failure (error message like "Can not unlock a compute host without data interfaces."), please wait for a while (several minutes) and run the provisioning script again.

9. Proceed with normal openstack procedures to create VMs.


## Steps for Simplex

1. create kvm for deployment:
The code to create kvms is under tic_vb/libvirt.
Config the controller node memory size using controller_simplex.xml
Config the disc size in setup_tic_simplex.sh, the sizes are hard coded like below:
   ```
   sudo qemu-img create -f qcow2 /var/lib/libvirt/images/controller-0-0.img 600G
   ```
Note: Size of controller-0-0.img should be > 500G.
After all configurations done, please run the following script to create the kvms.
   ```
   $ ./setup_tic_simplex.sh
   ```

2. In the window of controller-0, please choose "All In One - Graphic Console - Standard Security" to install the TiC.
Note: you may need to double click the controller-0 in the virt-manager window to open the kvm window.

3. After installation, please login with wrsroot/wrsroot. You're required to change the password for the first time login.

4. Applying controller configuration

   On the controller-0 node, run the following to configure controller-0.
   ```
   controller $ sudo config_controller
   ```
   When asked for the system mode, choose 3 (simplex). For other settings just accept as default.
   Note: the default ip of the controller node will be 10.10.10.2, which is different with the multi-node mode.

5. no need.

6. no need.

7. same as multi-node.

8. Copy over the provisioning scripts and run stage1

On host, copy stage1 and stage2 scripts
   ```
   $ scp provisioning_scripts/provision_simplexR5_stage* wrsroot@10.10.10.XXX:
   ```
On controller-0, run stage1
   ```
   controller $ ./provision_simplexR5_stage1.sh
   ```
Wait for reboot. Watch rdesktop/vrde console to see when stage1 is done.
On controller-0, run stage2
   ```
   controller $ ./provision_simplexR5_stage2.sh
   ```

9. Proceed with normal openstack procedures to create VMs.


## Horizon

The wiki page [Access the Horizon Dashboard](https://securewiki.ith.intel.com/display/madawaska/Access+the+Horizon+Dashboard) provides detailed instructions for accessing the dashboard from your browser.

