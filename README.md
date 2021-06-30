# WireGuard Deployment Script

## Design

* Server
  * Traefik ingress
    * Let's Encrypt
  * Nginx - Private subnet (10.13.13.0/24)
  * Wiregaurd
  * Keycloak
    * Front Facing
    * Secret?
* Client

## Considerations

* Docker all the things
* Key rotation
* Vault or AWS Store is not needed.

## Links : 

* https://wirein.dockr.life
* https://keycloak.dockr.life

## How to

### Setup

`./wirescale.sh setup`

### Run

`./wirescale.sh login`
`./wirescale.sh logout`

### Kill

`./wirescale.sh kill`
