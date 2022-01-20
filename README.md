# MAAP Eclipse Che Operations Guide

This guide is intended to provide an operational template for configuring and deploying the MAAP ADE.

## Prerequisites

Before running a MAAP Eclipse Che environment, the following core MAAP services must be operational:

- [CAS service integrated with URS](https://github.com/MAAP-Project/maap-auth-cas)
- [CMR](https://github.com/MAAP-Project/maap-cmr)
- [CORE API](https://github.com/MAAP-Project/maap-api-nasa)
- [DPS](https://github.com/MAAP-Project/maap-dps-packer-templates)
- [MAS](https://github.com/MAAP-Project/maap-mas-gitlab)

**Host environment**: these instructions have been tested on EC2 VMs running Ubuntu version >= 18.04. 

### Installation Guide

[setup-commands-v7-microk8s.md](setup-commands-v7-microk8s.md)

### Restoring From Backup

[RESTORE.md](RESTORE.md)

### Restoring From Backup - Test Procedure

[RESTORE_TEST.md](RESTORE_TEST.md)
