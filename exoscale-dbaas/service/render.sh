#!/bin/sh
set -eo pipefail

echo $ACORN_EVENT

if [ "$ACORN_EVENT" = "delete" ]; then
  echo "-> removing termination protection of the ${NAME} / ${ZONE} database"
  exo dbaas update ${NAME} -z ${ZONE} --termination-protection=false

  echo "-> deleting database ${NAME} / ${ZONE}"
  exo dbaas delete ${NAME} -z ${ZONE} --force
  exit 0
fi

# Create a cluster in the current project
echo "-> about to create a ${TYPE} database named ${NAME} on plan ${PLAN} in zone ${ZONE}"
echo  exo dbaas create ${TYPE} ${PLAN} ${NAME} -z ${ZONE}
result=$(exo dbaas create ${TYPE} ${PLAN} ${NAME} -z ${ZONE})

# Make sure cluster was created correctly
if [ $? -ne 0 ]; then
  echo $result
  exit 1
fi

# Get Database URI
DB_URI=$(exo dbaas show ${NAME} -z ${ZONE} --uri)

# Allow database network access from everywhere (should be limited to set of ip in real world)
if [ "$TYPE" = "redis" ]; then exo dbaas update ${NAME} -z ${ZONE} --redis-ip-filter "0.0.0.0/0"; fi

# Extract proto / host / port / username / password from URI
DB_PROTO=$(echo $DB_URI | cut -d':' -f1)
DB_USER=$(echo $DB_URI | cut -d':' -f2 | cut -d'/' -f3)
DB_PASS=$(echo $DB_URI | cut -d'@' -f1 | cut -d':' -f3)
DB_HOST=$(echo $DB_URI | cut -d'@' -f2 | cut -d':' -f1)
DB_PORT=$(echo $DB_URI | cut -d'@' -f2 | cut -d':' -f2 | cut -d'/' -f1)

echo "PROTO:[${DB_PROTO}] - HOST:[${DB_HOST}] - PORT:[${DB_PORT}] - USER:[${DB_USER}] - PASS:[${DB_PASS}]" 

cat > /run/secrets/output<<EOF
services: "exo-dbaas": {
  address: "${DB_HOST}"
  ports: [${DB_PORT}]
  secrets: ["db-creds"]
  data: {
    proto: "${DB_PROTO}"
  }
}
secrets: "db-creds": {
  type: "basic"
  data: {
    username: "${DB_USER}"
    password: "${DB_PASS}"
  }
}
EOF