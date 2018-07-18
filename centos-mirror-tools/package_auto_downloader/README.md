# Package auto downloader

This program will search in Google for an rpm package and attempt to download it.
The program can be run directly on your workstation or it can be run using a container.

### How to execute:
##### Requirements
* Node.JS version 10.5.0
* npm version 6.1.0

_* It is highly recommended to use a tool like nvm (https://github.com/creationix/nvm)
to manage your node/npm environment instead of installing node with your package manager._

_* The above requirements can be ignored if you want to run it using Docker_

##### Build and execute steps:
* Building

```$ npm i```
* Executing

```$ node index.js -p <package name> [-n <number of Google pages to search>]```

* Getting help

```$ node index.js --help```


##### Building and executing using Docker
* Building

```docker build -t <give your image a name>:<give your image a tag> .```
  > Example: \
  > ```$ docker build -t pack_down:1 .```
* Executing

```docker run -ti -v <where you want your files downloaded>:/var/opt/app/downloads> <your image name>:<your image tag> <full package name>```
  > Example: \
  > ```$ docker run --rm -ti -v ${PWD}/downloads:/var/opt/app/downloads pack_down:1 bash-4.2.46-30.el7.x86_64.rpm -n 100```
 * Debugging the container:

```$ docker run -ti --entrypoint /bin/ash -v <where you want your files downloaded>:/var/opt/app/downloads> <your image name>:<your image tag>```
  > Example: \
  > ```$ docker run --rm -ti --entrypoint /bin/ash -v ${PWD}/downloads:/var/opt/app/downloads pack_down:1```

_Note: You can optionally add -d run on dettached mode or --rm option if you want your container to be removed after completion_
