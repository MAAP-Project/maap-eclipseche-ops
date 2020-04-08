INSTANCE=`sudo microk8s.docker ps | grep k8s_nginx | awk '{print $1;}'`
SSL_CERT_PREFIX=`sudo microk8s.docker inspect $INSTANCE | grep Merged | awk -F'"' '{print $4;}'`
SSL_CERT_PATH=$SSL_CERT_PREFIX/ingress-controller/ssl/default-che-tls.pem

LINKNAME=nginxssl.pem
#rm $LINKNAME
ln -s $SSL_CERT_PATH $LINKNAME
