#!/usr/bin/env bash

# This script backups the Ecilpse Che postgres database running in the pod into a file on EFS
# This database contains info for Che workspaces as well as the keycloak

NAMESPACE=$(/snap/bin/microk8s.kubectl get pods -A | grep postgres | tr -s ' ' | cut -f 1 -d ' ')
POD=$(/snap/bin/microk8s.kubectl get pods -A | grep postgres | tr -s ' ' | cut -f 2 -d ' ')
DATETIME=$(date +"%s")

BACKUPFILE="/efs/postgres_backups/$POD-$NAMESPACE-$DATETIME.sql.gz"

$(/snap/bin/microk8s.kubectl exec -it -n $NAMESPACE $POD -- pg_dumpall | gzip -c > $BACKUPFILE)
