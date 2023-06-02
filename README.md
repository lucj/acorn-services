## Purposes

This repository demonstrates the creation and usage of Acorn's *Services*, a new feature available in Acorn 0.7

## Services

There are currently 3 Services defined in this repository:

- the [MongoDB Atlas Cluster Service](./atlas/README.md) triggers the creation of MongoDB cluster managed by Atlas
- the [NATS / NGS Service](./ngs/README.md) triggers the creation of a NGS user for appication using NATS (for instance as a PubSub component) 
- the [Exoscale Redis DBaaS](./exoscale-dbaas/README.md) triggers the creation of a *Redis* / *Postgres* or *MySQL* database

## Status

Content of this repo is currently a WIP:
- Services might not need fully functional yet
- additional arguments will be added to the exising Services
- additional Services will be added too