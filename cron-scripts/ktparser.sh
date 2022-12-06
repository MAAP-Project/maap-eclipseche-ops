#!/bin/bash

count=1
dt=""
declare -A workspaces

while IFS= read -r line; do
    ((count++))
    
    if [[ $line == *"UTC 20"* ]]; then
        # Found a date marker; store and continue to next line
        dt=$(date +'%Y-%m-%d %H:%M:%S' -d "$line")
        continue
    fi

    if [[ -z "${line}" || $line == "NAMESPACE"* || $line == *"ServiceUnavailable"* ]]; then
        continue
    fi

    linearray=($line)
    namespace=${linearray[0]}

    # Omit any non-workspace entries
    if [[ $namespace != *"-che" || $namespace == "eclipse-che" ]]; then
        continue
    fi

    if [[ -v workspaces[$namespace] ]]; then
        # If no values have changed from the previous log entry, omit this entry from the output
        if [[ ${workspaces[$namespace]} == $line ]]; then
            continue
        else
            # New value(s) found; add entry
            workspaces[$namespace]=$line
        fi
    else
        workspaces[$namespace]=$line
    fi

    username=${namespace//-che/""} 
    workspace=${linearray[1]}
    cpu=${linearray[2]//m/""}
    memory=${linearray[3]//Mi/""}

    echo "$username,$workspace,$cpu,$memory,$dt"

done < $1
