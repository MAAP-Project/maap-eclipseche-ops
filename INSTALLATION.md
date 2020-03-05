# Steps to install the MAAP ADE on a newly provisioned EC2 instance

This guide assumes that the core MAAP systems are configured and operational:
- [CAS service integrated with URS](https://github.com/MAAP-Project/maap-auth-cas)
- [CMR](https://github.com/MAAP-Project/maap-cmr)
- [CORE API](https://github.com/MAAP-Project/maap-api-nasa)
- DPS
- MAS

### 1) Install Eclipse Che and its dependencies

Follow the [Setup Commands document](setup-commands.md) script to install Eclipse Che and configure the host server. NOTE: prior to starting this step, a DNS name for the host server must be configured in order for Che to set up its required SSL certificates.

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

### 4) Test

To validate the install, navigate to the Che login page, sign in using MAAP, and create a workspace using a MAAP Stack. Verify that the new workspace loads with no errors.
