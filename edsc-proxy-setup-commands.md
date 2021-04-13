# Installing the EDSC Proxy for ADE nodes

This provides a simple proxy to allow EDSC to be embedded into Jupyterlab as an iframe using the EDSC plugin in https://github.com/MAAP-Project/maap-jupyter-ide/tree/master/edsc_extension

Depending on how the ADE is deployed, whether it's single node or in a multi-node setup, this installation may need to occur on one or more nodes. As this is a stateless proxy (and EDSC is stateless itself), there's no issue with having multiple installations.

**This can only be installed after the ADE is properly installed**

```shell
sudo apt-get update
sudo apt-get -y dist-upgrade

mkdir kubessl
cd kubessl
wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/edsc-proxy/extractcert.sh
chmod 755 extractcert.sh
./extractcert.sh

sudo apt-get install apache2
sudo service apache2 stop
sudo a2enmod ssl rewrite proxy_http headers substitute
sudo a2dissite 000-default

# In /etc/apache2/ports.conf, disable port 80, change 443 to 30052

cd /etc/apache2
sudo wget https://raw.githubusercontent.com/certbot/certbot/master/certbot-apache/certbot_apache/_internal/tls_configs/current-options-ssl-apache.conf

cd /etc/apache2/sites-available
sudo wget https://raw.githubusercontent.com/MAAP-Project/maap-eclipseche-ops/master/edsc-proxy/edsc-proxy.conf

# rename edsc-proxy.conf to ade.<env>.maap-project.org-ssl.conf
# change the hostnames in the conf file to the correct environment 

sudo a2ensite ade.<env>.maap-project.org-ssl
sudo service apache2 start
```

Finally, for convenience, install the `extractcert.sh` as a cronjob so that the certificate is always up to date. Also schedule an `sudo service apache2 reload` to keep the certificate fresh.