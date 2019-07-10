# TL;DR

Our application platform begins with this foundation: 
* a [cognito](https://aws.amazon.com/cognito/) [user pool](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools.html) that manages client authentication as an [identity provider](https://en.wikipedia.org/wiki/Identity_provider)
* an [api gateway](https://aws.amazon.com/api-gateway/) that mediates client access to our API
* an [S3 bucket]() behind a [cloudformation CDN]() that efficienly serves static assets (fonts, images, javascript, css, html, ...) to clients

## API Gateway

An [api gateway](https://aws.amazon.com/api-gateway/) decouples several concerns from the developers and operators of an API.

* edge connection management
    - TLS, HTTP2
    - CDN
    - CORS, CSRF
    - application firewall - injection attacks, circuit breakers - ddos attacks
* autoscaling and failover
* logging and monitoring
* authentication
* authorization
* deployment management - canaries, versioning

Cloud version of an application server - ingress to a service mesh.
