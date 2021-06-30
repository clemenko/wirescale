# WireGuard Deployment Script

## Design

* Server
  * Traefik ingress - Let's Encrypt all the things
  * Private Nginx - Private subnet (10.13.13.0/24)
  * Public Flask - handle OIDC and secret
  * Wiregaurd
  * Keycloak
* Client

## Considerations

* Docker all the things
* keycloak CA
* Key rotation
* Vault or AWS Store is not needed.

## Links

* https://wirein.dockr.life
* https://keycloak.dockr.life
* https://flask.dockr.life

## How to

### Setup

`./wirescale.sh setup`

### Run

`./wirescale.sh login`
`./wirescale.sh logout`

### Kill

`./wirescale.sh kill`
