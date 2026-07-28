#!/bin/bash

# Create the network only if it doesn't already exist
docker network inspect gateway_net >/dev/null 2>&1 || docker network create gateway_net
docker network inspect minikube_net >/dev/null 2>&1 || docker network create minikube_net
docker network inspect kafka_net >/dev/null 2>&1 || docker network create kafka_net
docker network inspect postgres_net >/dev/null 2>&1 || docker network create postgres_net
docker network inspect redis_net >/dev/null 2>&1 || docker network create redis_net