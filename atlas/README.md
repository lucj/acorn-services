## Purpose

This service creates a Mongo Atlas cluster. In this very early version the cluster has the following characteristics:
- cloud provider: AWS 
- region: EU_WEST_1
- tier: M0

The definition of the service is defined in *Acornfile*, details will be provided soon...

## Running the service

First provide your own Atlas API keys and project_ID in the *api-keys* secrets within the Acornfile:

```
"api-keys": {
        type: "opaque"
        data: {
            public_key: "ATLAS_ORG_PUBLIC_KEY"
            private_key: "ATLAS_ORG_PRIVATE_KEY"
            project_id: "ATLAS_PROJECT_ID"
        }
    }
```

Next run the Acorn to test things out:

```
acorn run -n atlas .
```

In a few tens of seconds a new Atlas cluster will be up and running.

## Publishing the service

```
acorn build -t docker.io/lucj/acorn-atlas-service:v0.1.0 .
acorn push docker.io/lucj/acorn-atlas-service:v0.1.0
```

## Using the service

Creation of a secret containing the atlas api keys

```
acorn secrets create \
  --type opaque \
  --data public_key=$ATLAS_ORG_PUBLIC_KEY \
  --data private_key=$ATLAS_ORG_PRIVATE_KEY \
  --data project_id=$ATLAS_PROJECT_ID \
  atlas-credentials
```

Definition of an Acorn using the atlas service. To keep think simple for now, we just use the following Acorn definition (content of *Acornfile-client*) which uses the above service and set the atlas cluster endpoint in an env var of an nginx container.

Note: this Acorn is a very temporary one just to make sure the whole process (service creation and service usage is right):

```
containers: app: {
    image: "nginx:1.22"
    env: {
      ALTLAS_CLUSTER_URL: "@{services.mongo.address}"
    }
    ports: publish: "80/http"
}

services: mongo: {
    image: "docker.io/lucj/acorn-atlas-service:v0.1.0"
}
```

We can then run this Acorn linking the secret:

```
acorn run -n demo -s atlas-credentials:api-keys -f Acornfile-client .
```