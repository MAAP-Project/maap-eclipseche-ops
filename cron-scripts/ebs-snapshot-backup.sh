#!/bin/bash

VOLUME_ID=$1

if [ -z $VOLUME_ID ];
then
    echo "Usage $1: Define Volume Id to snapshot"
    exit 1
fi

echo Creating snapshot for $volume $(/usr/local/bin/aws ec2 create-snapshot --region us-west-2 --volume-id $VOLUME_ID --description "www/api scheduled backup")