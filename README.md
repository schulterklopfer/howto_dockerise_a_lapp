# How to dockerise a lightning app on ubuntu 16.04

## Alternative 1: Using docker swarm and stacks

### Intended setup

![LAPP docker stack](https://github.com/schulterklopfer/howto_dockerise_a_lapp/raw/master/graphs/stack.png "LAPP docker stack")

### Prerequisits

* free disk space of at least 200G for docker images and blockchain data
* user with sudo privileges
* docker
* git
* coffee :)

### 1. Install docker
To install docker on your machine, please follow [this guide](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-16-04). Make sure you don't forget
to add your user to the docker group by using this command:
 
```bash
sudo usermod -aG docker ${USER}
``` 

### 2. Create a docker swarm (you might want to skip this, when using alternative 2 described later)
This guide relies on docker stacks. To use docker stacks we need to put your docker daemon
into swarm mode. Swarm mode is very useful to distribute this setup across several physical hosts.
The following command will initialise your docker daemon for swarm mode:

```bash
docker swarm init
```

find out more about this command [here](https://docs.docker.com/engine/reference/commandline/swarm_init/).

### 3. Create your docker images
Your lightning app stack will contain three docker services

1) bitcoind
2) lnd
3) your_lightning_app

You will find all the required files to build the images needed for the stack in the templates folder.
You will also find a base image for your lightning app and an example of how to use it.
To build and register the needed images with docker do the following:

```bash
git clone https://github.com/schulterklopfer/howto_dockerise_a_lapp.git 
cd howto_dockerise_a_lapp
cd template/images
./build.sh
```

This will call `docker build` in the respective folder and tag the resulting images accordingly.

```bash
#!/bin/bash

# will always build a container with the latest release of bitcoind
docker build bitcoind -t bitcoind:latest && \
# will build lnd 0.5 beta and cherry pick some commits to support communication over docker containers
docker build lnd -t lnd:0.5-beta -t lnd:latest && \
# will build a base image containing the lncli command
docker build lapp_base -t lapp_base:latest 
```

* bitcoind will have the tag 'bitcoind:latest'
* lnd will have the tag 'lnd:0.5-beta' and 'lnd:latest'
* lapp_base will have the tag 'lapp_base:latest'

From now on you can use those images with docker to run containers based on those images.
If you run `docker image list` you will find your newly built images in the resulting list.
```
REPOSITORY    TAG         IMAGE ID        CREATED            SIZE
bitcoind      latest      7a460845b7c9    17 seconds ago    141MB
lapp_base     latest      ac4c49f95459    17 seconds ago    1.07GB
lnd           0.5-beta  7c12bc05cee0    17 seconds ago    1.07GB
lnd           latest      7c12bc05cee0    17 seconds ago    1.07GB

```

Of course you need to dockerise your own lightning app as well. This is done by creating a
`Dockerfile` containing the commands to build an image with your application installed.
Basically the Dockerfile contains all the steps you would also do on your local development machine.

If you use `lapp_base:latest` as your base image, you will have access to `lncli` inside
your application container at runtime later. 
If you don't need that, you can use whichever base image you like.

`lapp_base:latest` is based on `lnd:latest` which is based on [`golang:1.10`](https://hub.docker.com/_/golang/) which is base on an ubuntu linux distribution.


A Dockerfile for creating an image which would run the awesome nodejs lightning network explorer
from [https://graph.lndexplorer.com/](https://graph.lndexplorer.com/) would look something like this:

```dockerfile
FROM lapp_base:latest

RUN apt-get update && apt-get install -y python-software-properties curl git
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get update && apt-get install -y nodejs

RUN mkdir -p /opt/app

WORKDIR /opt/app
RUN git clone https://github.com/altangent/lightning-viz.git src

WORKDIR /opt/app/src/

RUN npm i
RUN npm run build

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
To build your image containing your lightning enabled application you simply have to run
the following command from the directory the `Dockerfile` is located:

`docker build . -t lapp:latest`

This will execute the steps from `Dockerfile` and tag the resulting image with `lapp:latest`.
You can use whatever tag you like, for example `awesome_app:v0.1-alpha` as long as it matches the tag in the configuration file
for your stack deployment. This topic will be covered later.

Now we have everything we need to configure and run our bitcoin stack containing your
lightning app.

### 4. Run your lightning app stack (you might want to skip this, when using alternative 2 described later)

To tell docker what containers we want to run from which image, we will need to write a configuration
file containing all the information to run the containers. This information includes for example services
we want to start, volumes to mount into the docker container, ports to make accessible to the host and such.

Typically those files are in `yaml` format.

For our case, we need to run three containers. 
* One using the bitcoind:latest image
* One using the lnd:latest image
* One using your application, in this case lapp:latest

The configuration file for this would look like this:

```yaml
version: '3.4'
services:
  bitcoin:
    image: bitcoind:latest
    # always restart after container died
    restart: always
    ports:
      # forward container port 8333 to port 8333 on host
      - 8333:8333 
    volumes:
      # mount the volume containing bitcoin.conf and the blockchain data 
      # on the host to /bitcoin/.bitcoin in the container
      - /your/directory/docker/volumes/bitcoin/bitcoind:/bitcoin/.bitcoin
  lnd:
    image: lnd:latest
    # always restart after container died
    restart: always
    ports:
      # forward container port 9735 to port 9735 on host
      - 9735:9735
      # forward container port 10009 to port 10009 on host
      # Only necessary if your want to use lncli from the docker host.
      # You will need to link /your/home/directory/docker/volumes/bitcoin/lnd to $HOME/.lnd
      # and copy lncli binary from the lnd container using the 'docker copy' command
      # This is useful, since you are able to unlock the wallet directly from the host
      # without needing to log into your lnd container at every startup
      - 10009:10009
    volumes:
      # mount the volume containing lnd.conf and lnd data 
      # on the host to /root/.lnd in the container
      - /your/directory/docker/volumes/bitcoin/lnd:/root/.lnd
  # Your lightning enabled app goes here
  lapp:
    image: lapp:latest
    restart: always
    ports:
      # forward container port 8000 to port 80 on host
      - 80:8000
    volumes:
      # mount the volume containing lnd.conf and lnd data 
      # on the host to /root/.lnd in the container
      - /your/directory/docker/volumes/bitcoin/lnd:/root/.lnd
    environment:
      # set an environment variable to tell the container on which 
      # host lnd runs on
      LND_HOST: lnd

``` 

If we built all the images without error and we have tagged the images correctly, we should be able to
startup the stack like this:

```bash
docker stack deploy -c lapp.yaml lapp
```

To stop the stack again use:

```bash
docker stack rm lapp
```

To list all services type:

```bash
docker stack list
```

To display the output of a certain service use:

```bash
docker stack logs -t lapp_bitcoin
docker stack logs -t lapp_lnd
docker stack logs -t lapp_lapp
```

## Alternative 2: Using docker-compose

### Intended setup

![LAPP docker stack](https://github.com/schulterklopfer/howto_dockerise_a_lapp/raw/master/graphs/compose.png "LAPP docker stack")

### Prerequisits

In addition to the things you need specified in the first section of this HOWTO you will need the following 
* python 
* docker-compose (`pip install docker-compose`)

### Why?

In a single server setup, where no vertical scaling is needed its sometimes easier to run the docker containers
outside of the swarm. For example if your server has more than one network interface and you want to bind a port
exposed by a docker container to a specific interface, you will need to run the container outside swarm mode. Docker
swarm distributes containers across several machines, so binding to a specific interface on a specific machine
makes no sense and does not work.

An example for this would be running lnd, bitcoind and some lapp on one interface and c-lightning, bitcoind and 
[btcpayserver](https://github.com/btcpayserver) on another one. Doing it this way will allow you to use the default 
ports of the lightning network nodes on each interface without having to worry about port collisions.

### Whats different?

The main difference between running the containers directly vs. running them in swarm mode is, that you will not
have an internal swarm networks with name resolving. This means we will need to link the containers together, so
they are able to resolve each other and connect to the services the other containers are providing. The rest will
stay pretty much the same, except starting the whole thing up.

### Ok. Now what?

Follow the steps 1 to 3 of the previous section. If you only want to run your containers with docker-compose, then
just skip step 2 of the previous section.

### 4. Run your lightning app containers (using docker-compose)

To tell docker what containers we want to run from which images, we will need to write a configuration
file containing all the information to create the containers. This information includes volumes to mount
into the docker container, ports to make accessible to the host and such.

Typically those files are in `yaml` format.

For our case, we need to run three containers. 
* One using the bitcoind:latest image
* One using the lnd:latest image
* One using your application, in this case lapp:latest

The configuration file for the docker-compose command is quite similar to 
the one for running everything inside a stack, except the `links` sections and
the `version` of the language specification we use for the docker-compose file.

```yaml
version: '2.0'
services:
  bitcoin:
    image: bitcoind:latest
    # always restart after container died
    restart: always
    ports:
      # forward container port 8333 to port 8333 on host
      - 8333:8333
    volumes:
      # mount the volume containing bitcoin.conf and the blockchain data
      # on the host to /bitcoin/.bitcoin in the container
      - /your/directory/docker/volumes/bitcoin/bitcoind:/bitcoin/.bitcoin
  lnd:
    depends_on:
      - bitcoin
    image: lnd:latest
    # always restart after container died
    restart: always
    ports:
      # forward container port 9735 to port 9735 on host
      - 9735:9735
      # forward container port 10009 to port 10009 on host
      # Only necessary if your want to use lncli from the docker host.
      # You will need to link /your/home/directory/docker/volumes/bitcoin/lnd to $HOME/.lnd
      # and copy lncli binary from the lnd container using the 'docker copy' command
      # This is useful, since you are able to unlock the wallet directly from the host
      # without needing to log into your lnd container at every startup
      - 10009:10009
    volumes:
      # mount the volume containing lnd.conf and lnd data
      # on the host to /root/.lnd in the container
      - /your/directory/docker/volumes/bitcoin/lnd:/root/.lnd
    # link bitcoin container into this container so lnd can connect to the services running inside the bitcoin container
    links:
      - bitcoin
  # Your lightning enabled app goes here
  lapp:
    depends_on:
      - lnd
    image: lapp:latest
    restart: always
    ports:
      # forward container port 8000 to port 80 on host
      - 80:8000
    volumes:
      # mount the volume containing lnd.conf and lnd data
      # on the host to /root/.lnd in the container
      - /your/directory/docker/volumes/bitcoin/lnd:/root/.lnd
    environment:
      # set an environment variable to tell the container on which
      # host lnd runs on
      LND_HOST: lnd
    # link lnd container into this container so lapp can connect to the services running inside the lnd container
    links:
      - lnd
``` 

startup all the needed containers by using the following command.

```bash
cd template/docker-compose/lapp/ 
docker-compose up
```

To stop the containers again use:

```bash
docker-compose down
```

To list all services type:

```bash
docker-compose ps
```
which will give you an output something like that:

```
      Name                     Command               State                              Ports                            
-------------------------------------------------------------------------------------------------------------------------
bitcoin_bitcoin_1   docker-entrypoint.sh btc_o ...   Up      18332/tcp, 18333/tcp, 8332/tcp, 8333->8333/tcp
bitcoin_lnd_1       lnd                              Up      127.0.0.1:10009->10009/tcp, 9735->9735/tcp    
bitcoin_lapp_1      /bin/sh -c lncli --rpcserv ...   Up      10009/tcp, 80->8000/tcp, 9735/tcp           
```


To display the output of a certain service use:

```bash
docker-compose logs
```


----

Do you like this small guide or found some errors?
Then [send me an email](mailto:howto_lapp@skp.rocks) 

Also checkout my [sonification of the bitcoin blockchain](http://bitcoinradio.skp.rocks/)

Thanks for reading. :-D

*SKP*
