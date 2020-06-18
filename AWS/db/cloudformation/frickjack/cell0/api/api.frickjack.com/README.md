# TL;DR

Parameterize and deploy the littleware api stack under the api.frickjack.com domain - see the [tempalte README](../../../../../../lib/cloudformation/cellSetup/api/README.md) for details.

## Overview

This folder contains subfolders defining cloudformation stacks for API gateways deployed under the api.frickjack.com and beta-api.frickjack.com domains.  The [OIDC authentication client](./authClient/README.md) is the first supported API, and includes the resources defining the gateway domains and domain mappings.
