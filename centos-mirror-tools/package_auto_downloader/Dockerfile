FROM mhart/alpine-node:10.6.0

ENV http_proxy	"http://proxy-chain.intel.com:911"
ENV https_proxy "http://proxy-chain.intel.com:912"
ENV ftp_proxy "http://proxy-chain.intel.com:911"

WORKDIR /var/opt/app/
COPY . .
RUN echo -e "export http_proxy=$http_proxy\n\
export https_proxy=$https_proxy\n\
export ftp_proxy=$ftp_proxy" >> ~/.profile && \
npm config set https-proxy $https_proxy && \
npm config set proxy $http_proxy

RUN npm i

ENTRYPOINT ["node", "index.js", "-p"]
