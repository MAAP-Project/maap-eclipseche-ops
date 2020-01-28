/snap/bin/microk8s.docker ps -f status=running -f name=workspace --format "{{.ID}}: {{.Command}}" | grep -v "/pause" | awk -F: '{print $1}' | while read -r line ; do
    /snap/bin/microk8s.docker inspect $line | jq -r '.[0]["Name"]';
    /snap/bin/microk8s.docker inspect $line | jq -r '.[0]["GraphDriver"]["Data"]["UpperDir"]';
done
