FROM mhart/alpine-node:10.6.0

ENV http_proxy "your proxy"
ENV https_proxy "your proxy"
ENV ftp_proxy "your proxy"

WORKDIR /var/opt/app/
COPY . .
RUN echo -e "export http_proxy=$http_proxy\n\
export https_proxy=$https_proxy\n\
export ftp_proxy=$ftp_proxy" >> ~/.profile && \
npm config set https-proxy $https_proxy && \
npm config set proxy $http_proxy

RUN npm i

ENTRYPOINT ["node", "index.js", "-p"]
