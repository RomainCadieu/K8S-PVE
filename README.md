# K8S-PVE

K8S-PVE is an open source Kubernetes cluster deployment platform. Server provisionning is managed using Terraform with Proxmox as a target. Kubernetes cluster deployment is managed using Ansible to deploy the various software binaries, configuration files and cloud native applications required to operate.

## Solution design

The solution design carries the following requirements:

1. **On-premise provider**: Works similarly on any configuration
2. **Focused on modularity**: Change versions and softwares as you wish
3. **Public endpoint**: Leverage multiples servers stanting as edge gateway and allow the use of a single redudant Public IP address
8. **Converged Storage**: Persistent storage provided by cluster nodes

Solutions currently Work In Progress :

1. **Cloud provider agnostic**: Inter-compatibility with cloud networks and site to site configuration
2. **Networking privacy**: All intra-cluster communications are TLS encrypted, pod network is encrypted, Firewall is enabled by default.
2. **Cluster security**: Node security and RBAC are enabled by default
5. **Secure admin network**: Establish a private Mesh VPN between all servers
6. **Composable CRI**: Support various Container Runtime Interface plugins (for now Calico only)
7. **Composable CNI**: Support various Container Network Interface plugins (for now Calico only)
9. **API driven DNS**: DNS records are managed just-in-time during the deployment
10. **Stable**: Only leverage stable versions of software components

## Quick start

### Pre-requisits

Before starting check that following requirements are met:

* [ ] Setup the `terraform/terraform.tfvars` with your appropriate credentials and configuration using this [Example](./terraform/terraform.tfvars.example)
* [ ] Install the [required tools](./docs/prerequisits.md) (i.e. terraform, jq, etc.)
* [ ] Create the SSH key required to send commands to the servers.

### Server creation 

Once the requirements are met, use the following command lines instanciate the server and the appropriate dns records.

```bash
cd terrafrom/
terraform init
terraform plan
terraform apply
```

# Credits
This project used to be a new provider for [Kubernetes-Saltstack](https://github.com/fjudith/saltstack-kubernetes). So this project is vastly inspired by these projects:

* [Kubernetes-Saltstack](https://github.com/valentin2105/Kubernetes-Saltstack) from [@valentin2105](https://github.com/valentin2105)
* [hobby-kube](https://github.com/hobby-kube/provisionning)  from [@pstadler](https://github.com/pstadler)
* [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) from [@kelseyhightower](https://github.com/kelseyhightower)
* [Saltformula-Kubernetes](https://github.com/salt-formulas/salt-formula-kubernetes)
* [Kubernetes Icons](https://github.com/octo-technology/kubernetes-icons)
