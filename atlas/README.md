## Purpose

This folder defines an Acorn service which allows to create a Mongo Atlas cluster on the fly. 

In this very early version each cluster created by the service has the following characteristics, they are currently hardcoded but will soon become service's arguments:

- cloud provider: AWS 
- region: EU_WEST_1
- tier: M0

Notes:
- only one M0 cluster can be created in each Atlas project
- for cluster other than M0 tier billing information needs to be provided in Atlas

## Prerequisites

To use this service you need to have an Atlas Mongo account, to create an organization and a project within this one.

Note: this example uses an organization named *Techwhale* containing the project *webhooks*

Next create a public / private api key pair at the organization level

![Organization api keys](./images/organization-api-keys.png)

Next get the project ID

![Getting project ID](./images/project-id.png)

For this demo I set those 3 values in the following environment variables:

- MONGODB_ATLAS_PUBLIC_API_KEY
- MONGODB_ATLAS_PRIVATE_API_KEY
- MONGODB_ATLAS_PROJECT_ID

We will use these environment variables in the next part.

## Definition of the service

The [Acornfile](./service/Acornfile) defining the service contains 3 top level keys:
- service (*atlas*)
- job (*create-mongo-atlas-service*)
- secrets (*internal-db-creds*, *db-creds* and *atlas-creds*)

The *atlas* service is generated by the job *create-mongo-atlas-service*. This job contains all the logic to create an Atlas cluster. Behind the hood the cluster's generation process is done in a container built with this [Dockerfile](./service/Dockerfile). This container calls [render.sh](./service/render.sh) to create the Atlas cluster and a database user. 

The *internal-db-creds* secret is used to generated username / password on the file, those ones are provided to the job via environment variable so it can create db user.

The *db-creds* secret is generated by the job *create-mongo-atlas-service*, it contains the credentials of the db user.

The *atlas-creds* secret defines an external secret containing the credentials to connect to the Atlas account. This secret must exist in the Acorn project before the service can be used.

## Running the service

The service can be called directly from the above Acornfile.

First we need to create the secret *atlas-creds* providing the public and private keys as well as the Atlas project ID we want the MongoDB cluster to be created in.

Note: the following example uses environment variables already defined in the current shell 

```
acorn secrets create \
  --type opaque \
  --data public_key=$MONGODB_ATLAS_PUBLIC_API_KEY \
  --data private_key=$MONGODB_ATLAS_PRIVATE_API_KEY \
  --data project_id=$MONGODB_ATLAS_PROJECT_ID \
  atlas-creds
```

Next we run the Acorn:

```
acorn run -n atlas .
```

In a few tens of seconds a new Atlas cluster will be up and running.

![Cluster created](./images/cluster-created.png)

Running the service directly was just a test to ensure a cluster is actually created from this service.

Then we can delete the application, this will also delete the associated Atlas cluster:

```
acorn rm atlas --all --force
```

Note: Also, from the Atlas dashboard, we make sure to delete the cluster as we will create a new one in a next section.

## Publishing the service

The idea is not to run the service from its own Acornfile but to reference the service by its name from other Acorns. For this purpose we first need to build the image of the service (as we would do for a standard Acorn application):

```
VERSION=v...
acorn build -t docker.io/lucj/acorn-atlas-service:$VERSION -t docker.io/lucj/acorn-atlas-service:latest .
```

Next we push the image to an OCI registry (Docker Hub in this example):

```
acorn push docker.io/lucj/acorn-atlas-service:$VERSION
acorn push docker.io/lucj/acorn-atlas-service:latest
```

![Acorn image available in the Docker Hub](./images/dockerhub.png)

Once the image is in the registry it can be used by other applications.

## Using the service

As we have done when running the service from its own Acornfile, we need to create a secret containing the atlas api keys (this secret will allow the job to connect to the Atlas account).

Notes:
- the following example uses environment variables already defined in the current shell 
- if you have already created the secret in the previous step there is no need to run the command once again

```
acorn secrets create \
  --type opaque \
  --data public_key=$MONGODB_ATLAS_PUBLIC_API_KEY \
  --data private_key=$MONGODB_ATLAS_PRIVATE_API_KEY \
  --data project_id=$MONGODB_ATLAS_PROJECT_ID \
  atlas-creds
```

### Using the Atlas service with a simple container

The following Acornfile defines 2 items:
- a reference to the *atlas* service
- a container named *app* using this service

The container only tries to connect to the database using the MONGODB_URL provided in the env variable, this one is created from the service's properties: 

```
services: atlas: {
    image: "docker.io/lucj/acorn-atlas-service"
}

containers: app: {
  image: "mongo:6.0.5"
  entrypoint: ["/bin/sh", "-c", "/check-db.sh"]
  env: {
    MONGODB_URI: "@{services.atlas.data.proto}://@{services.atlas.secrets.db-creds.username}:@{services.atlas.secrets.db-creds.password}@@{services.atlas.address}"
  }
  files: "/check-db.sh": """
    echo "Will try to connect to [${MONGODB_URI}]"
    while true; do
      echo "=> testing DB connection..."
      mongosh --eval "db.adminCommand('ping')" ${MONGODB_URI} 
      if [ $? -eq 0 ]; then
        break
      else
        sleep 5
      fi
    done
    echo "connected to the DB"
    sleep 3600
  """
}
```

This simple application can be run with the following command:

```
acorn run -n app
```

From Atlas dashboard we could see a MongoDB cluster was automatically created.

Also, from the *app* container logs we can see the connection was successfull after the second attempt:

```
# acorn logs app
app-9b6876cbb-49x88: Will try to connect to [mongodb+srv://l4rcsrbw:wk9d5cgfkxf7hk8d@test.9flmpis.mongodb.net]
app-9b6876cbb-49x88: => testing DB connection...
app-9b6876cbb-49x88: Current Mongosh Log ID:    646a6d1bfaedda3a9caa08a1
app-9b6876cbb-49x88: Connecting to:             mongodb+srv://<credentials>@test.9flmpis.mongodb.net/?appName=mongosh+1.8.2
app-9b6876cbb-49x88: MongoServerError: bad auth : Authentication failed.
app-9b6876cbb-49x88: => testing DB connection...
app-9b6876cbb-49x88: Current Mongosh Log ID:    646a6d21847e03e28677ceab
app-9b6876cbb-49x88: Connecting to:             mongodb+srv://<credentials>@test.9flmpis.mongodb.net/?appName=mongosh+1.8.2
app-9b6876cbb-49x88: Using MongoDB:             6.0.6
app-9b6876cbb-49x88: Using Mongosh:             1.8.2
app-9b6876cbb-49x88: 
app-9b6876cbb-49x88: For mongosh info see: https://docs.mongodb.com/mongodb-shell/
app-9b6876cbb-49x88: 
app-9b6876cbb-49x88: 
app-9b6876cbb-49x88: To help improve our products, anonymous usage data is collected and sent to MongoDB periodically (https://www.mongodb.com/legal/privacy-policy).
app-9b6876cbb-49x88: You can opt-out by running the disableTelemetry() command.
app-9b6876cbb-49x88: 
app-9b6876cbb-49x88: { ok: 1 }
```

We've seen all to use a service right from a (simple) application container. In the next part we will use in a more interesting application. Before going to the next part, we delete the Acorn app and remove the Atlas cluster from the dashboard (as we've done previously).

### Using the atlas service with a microservice application

[https://webhooks.app/](https://webhooks.app/) is a microservice application which purpose is to provide a webhook (HTTP POST endpoint) on the fly, it is mainly dedicated to tests and demos. The source code is available in GitLab [https://gitlab.com/web-hook](https://gitlab.com/web-hook), each time a change is done in one of the microservices the application is build and pushed to the Docker Hub as an Acorn image in [https://hub.docker.com/r/lucj/webhooksapp/tags](https://hub.docker.com/r/lucj/webhooksapp/tags).

The Acornfile used to build the Acorn image of the Webhooks application ([https://gitlab.com/web-hook/config/-/blob/main/apps/acorn/Acornfile](https://gitlab.com/web-hook/config/-/blob/main/apps/acorn/Acornfile)) now makes reference to the Atlas service. 

In order to run the app and ensure it uses a MongoDB Atlas cluster created on the fly, we just need to use the *--atlas* flag as follows:

```
$ acorn run -n webhook lucj/webhooksapp --atlas
webhook
STATUS: ENDPOINTS[] HEALTHY[] UPTODATE[] 
STATUS: ENDPOINTS[] HEALTHY[0] UPTODATE[0] [defined: waiting on missing secrets [atlas]]
STATUS: ENDPOINTS[] HEALTHY[0/1] UPTODATE[1] [defined: waiting on missing secrets [atlas]] [containers: api pending create; nats ContainerCreating; swagger pending create; wss pending create; www pending create]
STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[0/1] UPTODATE[1] [defined: waiting on missing secrets [atlas]] [containers: api pending create; nats ContainerCreating; swagger pending create; wss pending create; www pending create]
STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[1] UPTODATE[1] [defined: waiting on missing secrets [atlas]]
STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[1] UPTODATE[1] pending
STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[1/3] UPTODATE[3] [containers: api ContainerCreating; swagger pending create; wss ContainerCreating; www pending create]
STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[1/3] UPTODATE[3] [containers: api is not ready; swagger pending create; wss ContainerCreating; www pending create]
STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[2/3] UPTODATE[3] [containers: api is not ready; swagger pending create; www pending create]
STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[3] UPTODATE[3] pending
STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[3/5] UPTODATE[5] [containers: swagger ContainerCreating; www ContainerCreating]
STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[3/5] UPTODATE[5] [containers: swagger is not ready; www ContainerCreating]
STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[4/5] UPTODATE[5] [containers: www ContainerCreating]

┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
| STATUS: ENDPOINTS[http://default-webhook-a1a950fb.11jp51.alpha.on-acorn.io => default:8080] HEALTHY[5] UPTODATE[5] OK |
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

The Atlas cluster is correctly created (this can be verified from the Atlas dashboard) and a HTTP endpoint is returned after a few tens of seconds. Using this endpoint we can access the application and verify it's working fine sending a dummy payload.

![Webhooks app](./images/webhooks-1.png)

![Webhooks app](./images/webhooks-2.png)

## Status

This service is currently a WIP...