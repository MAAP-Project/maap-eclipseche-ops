# Steps to install the MAAP ADE on a newly provisioned EC2 instance

This guide assumes that the core MAAP systems are configured and operational:
- [CAS service integrated with URS](https://github.com/MAAP-Project/maap-auth-cas)
- [CMR](https://github.com/MAAP-Project/maap-cmr)
- [CORE API](https://github.com/MAAP-Project/maap-api-nasa)
- DPS
- MAS

### 1) Install Eclipse Che and its dependencies

Follow the [Setup Commands document](setup-commands-v6.md) script to install Eclipse Che and configure the host server. NOTE: prior to starting this step, a DNS name for the host server must be configured in order for Che to set up its required SSL certificates.

### 2) Restart Keycloak and Che pods if necessary

Once Step 1 is complete, give Che a few minutes to start all of the system pods in the default namespace. The following command will provide the status of these pods: `microk8s.kubectl get pods`.

In the event that the Che and/or Keycloak pods are not fully operational after several minutes, delete the Keycloak pod and wait for a new Keycloak pod to fully start. Once a new Keycloak pod is online, delete the Che pod. After another minute, all pods should be fully operational.

These additional steps are the result of a [known issue in our version of Che](https://github.com/eclipse/che/issues/13838).

### 3) Configure Keycloak

By default, Keycloak is not configured to connect with any identity providers. For now, we use these manual steps to connect Keycloak to the MAAP CAS server:

- Navigate to `<new host name>/auth/admin/master/console/#/realms/che`
- Login with your admin credentials
- In the 'Realm Settings' tab, navigate to 'Themes', and change the Admin Console Theme to 'Keycloak Extended'
- Signout
- Login with your admin credentials again
- Navigate to Identity Providers
- Add provider CAS
- Configure CAS Provider
- After saving, create Attribute Mapper entries for email, firstName, lastName and proxyTicket

### 4) Login to the MAS docker registry

In order to pull MAAP-provisioned Docker images from Eclipse Che, we need to grant Docker access to the registry corresponding to the dev/ops environment where this ADE instance is running. For example: `microk8s.docker login registry.maap-project.org`

### 5) Import MAAP Stacks into Che

**TODO: automate this step as part of the Eclipse Che Docker image setup scripts**

For now, this is done by copying the existing list of MAAP stack raw configurations from another MAAP environment, and sharing the newly imported stacks to all Che users using these instructions: https://github.com/MAAP-Project/maap-jupyter-ide#creating-and-sharing-stacks

### 6) Test MAAP Stack(s)

To validate the install, navigate to the Che login page, sign in using MAAP, and create a workspace using a MAAP Stack. Verify that the new workspace loads with no errors.

### 7) Configure ESDC iframe proxy

The ESDC application is used within MAAP workspaces and must be setup using a reverse proxy to a running MAAP ESDC site.

- Install Apache: `sudo apt install apache2`
- Create a daily cron job that executes the [updatelink.sh](nginxssl/updatelink.sh) script
- Create a new Apache site listening on port `3052` using the [example config](apache/edsc_proxy.conf) as a guide
- Ensure the following Apache modules are installed: ssl, rewrite, proxy_http, headers, substitute


