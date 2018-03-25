# How to dockerise a lightning app on ubuntu 16.04

## Prerequisits

* disk space of at least 200G for docker images and blockchain data
* user with sudo privileges
* docker
* coffee :)

## 1. Install docker
To install docker on your machine, please follow [this guide](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-16-04). Make sure you don't forget
to add your user to the docker group using by using this command:
 
 `sudo usermod -aG docker ${USER}` 

## 2. Create a docker swarm
This guide relies on docker stacks. To use docker stacks we need to put your docker daemon
into swarm mode. The following command will do this:

`docker swarm init`

find out more about this command [here](https://docs.docker.com/engine/reference/commandline/swarm_init/).

## 3. Create your lightning app stack
Your lightning app stack will contain three docker services

1) bitcoind
2) lnd
3) your_lightning_app

... TODO: continue ...

