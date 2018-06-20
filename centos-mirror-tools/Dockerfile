## mirror download container

FROM centos:7.4.1708

WORKDIR /localdisk

#ENV http_proxy	"http://your.actual_http_proxy.com:your_port"
#ENV https_proxy "https://your.actual_https_proxy.com:your_port"
#ENV ftp_proxy "http://your.actual_ftp_proxy.com:your_port"

#RUN echo "proxy=$http_proxy" >> /etc/yum.conf && \
#    echo -e "export http_proxy=$http_proxy\nexport https_proxy=$https_proxy\n\
#export ftp_proxy=$ftp_proxy" >> /root/.bashrc

RUN yum install -y epel-release sudo vim-enhanced net-tools \
        /usr/bin/yumdownloader rpm-build rpm-sign deltarpm wget bind \
        bind-utils && rm /etc/yum.repos.d/CentOS-Sources.repo \
        /etc/yum.repos.d/epel.repo

COPY StarlingX.repo /etc/yum.repos.d
COPY rpm-gpg-keys/* /etc/pki/rpm-gpg/

RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY*

ENTRYPOINT ["/bin/bash"]
