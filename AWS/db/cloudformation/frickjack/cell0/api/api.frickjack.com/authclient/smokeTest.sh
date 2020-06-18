#!/bin/bash

DOMAIN="${1:-beta-api}"
LITTLE_AUTHN_BASE="${LITTLE_AUTHN_BASE:-https://${DOMAIN}.frickjack.com/authn}" npx jasmine code/node_modules/@littleware/little-authn/commonjs/bin/oidcClient/spec/authUxSpec.js
