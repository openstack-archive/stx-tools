#!/usr/bin/python3
import getpass
import os
import time
import streamexpect
from consts.timeout import HostTimeout
from consts import env
from utils import kpi
from utils import serial
from helper import host_helper, vboxmanage
from utils.install_log import LOG

def update_platform_cpus(stream, hostname, cpu_num=5):
    LOG.info("Allocating {} CPUs for use by the {} platform.".format(cpu_num, hostname))
    serial.send_bytes(stream, "\nsource /etc/nova/openrc; system host-cpu-modify "
                      "{} -f platform -p0 {}".format(hostname, cpu_num, prompt='keystone', timeout=300))

def set_dns(stream, dns_ip):
    #serial.send_bytes(stream, "source /etc/nova/openrc", prompt='keystone')
    LOG.info("Configuring DNS to {}.".format(dns_ip))
    serial.send_bytes(stream, "source /etc/nova/openrc; system dns-modify "
                      "nameservers={}".format(dns_ip), prompt='keystone')


def config_controller(stream, config_file=None, password='Li69nux*', kubernetes=False):
    """
    Configure controller-0 using optional arguments
    """
    args = ''
    if config_file:
        args += '--config-file ' + config_file + ' '
    if kubernetes:
        args += '--kubernetes '

    serial.send_bytes(stream, "sudo config_controller {}".format(args), expect_prompt=False)
    host_helper.check_password(stream, password=password)
    ret = serial.expect_bytes(stream, "unlock controller to proceed.", timeout=HostTimeout.LAB_CONFIG)
    if ret != 0:
        LOG.info("Configuration failed. Exiting installer.")
        raise Exception("Configcontroller failed")

