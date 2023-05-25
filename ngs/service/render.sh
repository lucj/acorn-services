#!/bin/sh
# set -eo pipefail

echo $ACORN_EVENT

if [ "$ACORN_EVENT" = "delete" ]; then
  nsc delete user -n test --rm-nkey --rm-creds
  exit 0
fi

# Setup account profile
nsc load --profile "nsc://synadia?secret=${NGS_KEY}"

# Create a new user in the current account
result=$(nsc add user test --allow-sub "_INBOX.>" --allow-pub "ngs.echo")
if [ $? -ne 0 ]; then
  echo $result
  exit 1
fi

# Get path towards credentials file
OPERATOR=$(nsc env 2>&1 | grep "Current Operator" | awk -F '|' '{print $4}' | xargs)
ACCOUNT=$(nsc env 2>&1 | grep "Current Account" | awk -F '|' '{print $4}' | xargs)
CREDS=~/.local/share/nats/nsc/keys/creds/$OPERATOR/$ACCOUNT/test.creds
# CREDS=~/.nkeys/creds/$OPERATOR/$ACCOUNT/test.creds


# Create Acornfile containing service and secret
# cat > /tmp/output<<EOF
cat > /run/secrets/output<<EOF
services: ngs: {
  address: "connect.ngs.global"
  secrets: ["user-creds"]
}
secrets: "user-creds": {
  data: {
    creds: "$(cat ${CREDS})"
  }
}
EOF