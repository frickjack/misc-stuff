# TL;DR

Management of ssh authorized keys.
Also ssh and gpg private keys and rotation.

## Details

Mechanism for delivering and rotating ssh public keys to different servers,
and for clients to download his/her current active keys.

### Ideas

* plug into policy engine to determine which users have access to which server roles

## Deliverables

* Standard: documentation, test plan, UX design
* web site
* api
* chef-recipe
* cli/sdk
