## mirror download container

FROM centos:7.4.1708

#ENV http_proxy	"http://your.actual_http_proxy.com:your_port"
#ENV https_proxy "https://your.actual_https_proxy.com:your_port"
#ENV ftp_proxy "http://your.actual_ftp_proxy.com:your_port"

#RUN echo "proxy=http://your-proxy.com:port" >> /etc/yum.conf

RUN yum install -y epel-release sudo vim-enhanced net-tools
RUN yum install -y /usr/bin/yumdownloader rpm-build rpm-sign deltarpm wget bind bind-utils

RUN rm /etc/yum.repos.d/CentOS-Sources.repo && \
    rm /etc/yum.repos.d/epel.repo

COPY StarlingX.repo /etc/yum.repos.d
COPY rpm-gpg-keys/* /etc/pki/rpm-gpg/

RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY*

WORKDIR /localdisk
