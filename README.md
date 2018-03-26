# How to dockerise a lightning app on ubuntu 16.04

## Intended setup

![LAPP docker stack](https://github.com/schulterklopfer/howto_dockerise_a_lapp/raw/master/lapp_stack.png "LAPP docker stack")

## Prerequisits

* free disk space of at least 200G for docker images and blockchain data
* user with sudo privileges
* docker
* git
* coffee :)

## 1. Install docker
To install docker on your machine, please follow [this guide](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-16-04). Make sure you don't forget
to add your user to the docker group using by using this command:
 
 `sudo usermod -aG docker ${USER}` 

## 2. Create a docker swarm
This guide relies on docker stacks. To use docker stacks we need to put your docker daemon
into swarm mode. Swarm mode is very useful to distribute this setup across several physical hosts.
The following command will do this:

`docker swarm init`

find out more about this command [here](https://docs.docker.com/engine/reference/commandline/swarm_init/).

## 3. Create your lightning app stack
Your lightning app stack will contain three docker services

1) bitcoind
2) lnd
3) your_lightning_app

You will find all the required files to build the images needed for the stack in the templates folder.
You will also find a base image for your lightning app and an example of how to use it.
To build and register the needed images with docker do the following:

```
git clone https://github.com/schulterklopfer/howto_dockerise_a_lapp.git 
cd howto_dockerise_a_lapp
cd template/images
./build.sh
```

This will call `docker build` in the respective folder and tag the resulting images accordingly.
* bitcoind will have the tag 'bitcoind:latest'
* lnd will have the tag 'lnd:0.4-beta'
* lapp_base will have the tag 'lapp_base:latest'

From now on you can use those images with docker to run containers based on those images.
If you run `docker image list` you will find your newly built images in the resulting list.
```
REPOSITORY    TAG         IMAGE ID        CREATED            SIZE
bitcoind      latest      7a460845b7c9    17 seconds ago    141MB
lapp_base     latest      ac4c49f95459    17 seconds ago    1.07GB
lnd           0.4-beta    7c12bc05cee0    17 seconds ago    1.07GB
```

Of course you need to dockerise your own lightning app as well. This is done by creating a
`Dockerfile` containing the commands to build an image with your application installed.
Basically the Dockerfile contains all the steps you would also do on your local development machine.

If you use `lapp_base:latest` as your base image, you will have access to `lncli` inside
your application container at runtime later. 
If you don't need that, you can use whichever base image you like.

`lapp_base:latest` is based on `lnd:0.4-beta` which is based on [`golang:1.10`](https://hub.docker.com/_/golang/) which is base on an ubuntu linux distribution.


A Dockerfile for a simple nodejs lightning app would look something like this:

```
FROM lapp_base:latest

RUN apt-get update && apt-get install -y python-software-properties curl
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get update && apt-get install -y nodejs

RUN mkdir -p /opt/local/app
WORKDIR /opt/local/app

ADD ./ .

RUN npm i

CMD lncli --rpcserver lnd:10009 getinfo && npm start
```
You might want to add a `.dockerignore` file to your project, so your build context
is not polluted with data you don't need.
For a nodejs application this file would look something like this:
```
# .dockerignore
Dockerfile
node_modules
package-lock.json
```
Now we have everything we need to configure and run our bitcoin stack containing your
lightning app.

