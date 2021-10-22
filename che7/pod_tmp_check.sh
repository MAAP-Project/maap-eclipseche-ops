while read -r pod
do
        user=(${pod//-/ })
        echo $pod && kubectl exec -n $pod -c s3fs  /bin/ash -- du -h /scratch/$user;
done < <(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{@.metadata.namespace}{" "}{@.metadata.name}{"\n"}{end}' | grep -v "eclipse-che" | grep -- -che)
