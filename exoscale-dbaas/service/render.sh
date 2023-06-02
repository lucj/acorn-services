#!/bin/sh
set -o pipefail

if [ "$ACORN_EVENT" = "delete" ]; then
  echo "-> removing termination protection of the ${NAME} / ${ZONE} database"
  exo dbaas update ${NAME} -z ${ZONE} --termination-protection=false 2>&1
  if [ $? -ne 0 ]; then echo "cannot remove termination protection"; fi

  echo "-> deleting database ${NAME} / ${ZONE}"
  exo dbaas delete ${NAME} -z ${ZONE} --force 2>&1
  if [ $? -ne 0 ]; then echo "cannot delete database"; fi

  exit 0
fi

# Create a database if none already exists with this name in the same zone
exo dbaas show ${NAME} -z ${ZONE} 2>&1
if [ $? -eq 0 ]; then
  echo "database already exists"
else
  echo "-> about to create a ${TYPE} database named ${NAME} on plan ${PLAN} in zone ${ZONE}"
  echo exo dbaas create ${TYPE} ${PLAN} ${NAME} -z ${ZONE}
  exo dbaas create ${TYPE} ${PLAN} ${NAME} -z ${ZONE} 2>&1

  # Make sure cluster was created correctly
  if [ $? -ne 0 ]; then
    echo "database cannot be created"
    exit 1
  fi
fi

# Get Database URI
DB_URI=$(exo dbaas show ${NAME} -z ${ZONE} --uri)

# Allow database network access from everywhere (should be limited to set of ip in real world)
set -- "--${TYPE}-ip-filter" "0.0.0.0/0"
exo dbaas update ${NAME} -z ${ZONE} "$@"

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
  secrets: ["db-creds"]
  data: {
    proto: "${DB_PROTO}"
    port: "${DB_PORT}"
  }
}
secrets: "db-creds": {
  data: {
    username: "${DB_USER}"
    password: "${DB_PASS}"
  }
}
EOF