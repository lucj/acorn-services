## Purpose

This service creates a Mongo Atlas cluster. In this very early version the cluster has the following characteristics:
- cloud provider: AWS 
- region: EU_WEST_1
- tier: M0

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

Next run the Acorn:

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

TODO
