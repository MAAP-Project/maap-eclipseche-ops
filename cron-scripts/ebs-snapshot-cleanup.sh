#!/bin/bash

VOLUME_ID=$1

if [ -z $VOLUME_ID ];
then
    echo "Usage $1: Define Volume Id of snapshots to cleanup"
    exit 1
fi

ct=0
MAX_SNAPSHOTS=7

for snapshot in $(/usr/local/bin/aws ec2 describe-snapshots --region us-west-2 --filters Name=volume-id,Values=$VOLUME_ID --query 'Snapshots[*].[StartTime,SnapshotId]' --output text | sort -r | sed 's/\"//g' | awk '{print $2}')
do
    if (( $ct >= $MAX_SNAPSHOTS ));
    then
        echo "Deleting snapshot --> $snapshot"
        /usr/local/bin/aws ec2 delete-snapshot --snapshot-id $snapshot --region us-west-2
    fi

    ((++ct))
done
