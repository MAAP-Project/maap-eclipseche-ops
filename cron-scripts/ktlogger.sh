#!/bin/bash

# Append kubetop log
printf "\n" >> /tmp/kubetop.log 2>&1 && date >> /tmp/kubetop.log 2>&1 && /snap/bin/kubectl top pods --all-namespaces >> /tmp/kubetop.log 2>&1

# Parse raw log data
/tmp/ktparser.sh /tmp/kubetop.log > /tmp/kubetop.csv

# Send parsed data to s3
/usr/local/bin/aws s3 cp /tmp/kubetop.csv s3://maap-logging/ade-usage/ --only-show-errors
