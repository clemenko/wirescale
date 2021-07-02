# WireGuard Deployment Script

"A script for building 2 vms for testing Keycloak and Wireguard."

## Design

## Requirements

Create automation using ~~terraform~~ **bash** that sets up a demo environment with the following capabilities:

* An nginx service that is only reachable by users connected using WireGuard.
* A public deployment of Keycloak to authenticate users by username/password and holds
WireGuard secrets needed to connect to the server hosting nginx.
* A script that accepts username/password and authenticates with keycloak, retrieves the
secrets, and locally configures WireGuard.
* Use Vault or AWS secrets store to store and distribute secrets.
* The tool can work on either Linux or Mac, whatever is more convenient. Provide easy to use README and getting started guides.

### Basics

* Server
  * Traefik ingress - Let's Encrypt all the things
  * Public Flask - handle OIDC and secret
  * Wiregaurd
    * Private Nginx - Private subnet (10.13.13.0/24)
  * Keycloak
* Client

### Idea

The english, the `wirescale.sh` script has two uses. First one is for setting up two VMs, server and client. The client vm will use the `./wirescale.sh login` for retrieving the wireguard peer config. The server will deploy everything with docker. We are using [Traefik.io](traefik.io) for ingress. There is a public facing Flask application for serving out the peer config as a base64 encoded string. There is an `/api` endpoint for the client side to use. Then there is an [Nginx](https://nginx.com/) container serving out a private page over a [Wireguard](https://www.wireguard.com/) container. And finally [Keycloak](https://www.keycloak.org/) for OIDC authentication.

## Considerations

* Docker all the things
* TLS all the things
* Key rotation
* Installing dependencies
* Vault - needs to be setup. I find it a little redundant to use a "secret" to retrieve a "secret".

## Links

* https://in.dockr.life - Traefik
* https://key.dockr.life - Keycloak
* https://flask.dockr.life - Flask

## How to

### Setup

```bash
# the script assumes Digital Ocean for VM and DNS.
# Check the script to change any values.

# build the two vms
./wirescale.sh up
```

### Run on Client

```bash
# ssh to the client.dockr.life

# login
./wirescale.sh login

# curl private site
curl private.site 

# logout
./wirescale.sh logout
```

### Kill

```bash
# desctroy the two vms
./wirescale.sh kill
```

## TODO

Things I would like to do.

* Add Vault
* Containerize client
