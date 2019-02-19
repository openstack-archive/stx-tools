Pybox
-----
Pybox is a prototype for a python-based vbox installer.

Requirements
-------------

Pybox requires python3, virtualbox, paramiko, pexpect and python3-serial in
order to operate:

sudo apt-get install python3
sudo python3 -m pip install paramiko
sudo python3 -m pip install streamexpect

Sample Usage
------------

./install_vbox.py --setup-type AIO-SX --iso-location "/home/myousaf/bootimage.iso" --labname test --install-mode serial
--config-files-dir /home/myousaf/pybox/configs/aio-sx/ --config-controller-ini /home/myousaf/pybox/configs/aio-sx/TiS_config.ini_centos --vboxnet-name vboxnet0 --controller0-ip 10.10.10.8 --ini-oam-cidr '10.10.10.0/24'

Assumptions
-----------
You have setup vbox networking as required, in order to transfer files to the virtual machines, i.e. NAT network, vboxnet, bridge.

To Fix
------
lab_setup.sh file will need tweaking
