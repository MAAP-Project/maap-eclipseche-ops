#!/bin/bash

# File the last day of log data
mv /tmp/kubetop.csv /tmp/kubelogs/kubetop_$(date +'\%d-\%m-\%Y').csv

# Clear active log
rm /tmp/kubetop.log

# Send parsed data to s3
/usr/local/bin/aws s3 cp /tmp/kubelogs/kubetop_$(date +'\%d-\%m-\%Y').csv s3://maap-logging/ade-usage/ --only-show-errors
