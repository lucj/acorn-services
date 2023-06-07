#!/bin/sh
# set -eo pipefail

if [ "$ACORN_EVENT" = "delete" ]; then
  nsc delete user -n myuser --rm-nkey --rm-creds
  exit 0
fi

# Setup account profile
nsc load --profile "nsc://synadia?secret=${NGS_KEY}"

# Create a new user in the current account
echo nsc add user myuser --allow-sub "_INBOX.>" --allow-pub "ngs.echo" --allow-pubsub "$PUBSUB"
result=$(nsc add user myuser --allow-sub "_INBOX.>" --allow-pub "ngs.echo" --allow-pubsub "$PUBSUB" )
if [ $? -ne 0 ]; then
  echo $result
  exit 1
fi

# Get path towards credentials file
OPERATOR=$(nsc env 2>&1 | grep "Current Operator" | awk -F '|' '{print $4}' | xargs)
ACCOUNT=$(nsc env 2>&1 | grep "Current Account" | awk -F '|' '{print $4}' | xargs)
CREDS=~/.local/share/nats/nsc/keys/creds/$OPERATOR/$ACCOUNT/myuser.creds

# Create Acornfile containing service and secret
cat > /run/secrets/output<<EOF
services: ngs: {
  address: "connect.ngs.global"
  secrets: ["user-creds"]
}
secrets: "user-creds": {
  data: {
    creds: """
    $(cat ${CREDS} | sed 's/\(.*\)/    \1/')
    """
  }
}
EOF