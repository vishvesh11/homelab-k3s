# K3s Distributed Cluster Setup with Headscale

A complete guide and infrastructure-as-code for setting up a distributed K3s Kubernetes cluster connected via Headscale (self-hosted WireGuard VPN mesh). This setup demonstrates a hybrid infrastructure spanning cloud and on-premises nodes.

## 📋 Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Setup Instructions](#setup-instructions)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│         Headscale VPN Mesh              │
│    (Self-hosted WireGuard Network)      │
└─────────────────────────────────────────┘
    │                │                │
    ▼                ▼                ▼
┌──────────┐  ┌──────────┐    ┌──────────┐
│ OCI Node │  │ Ryzen VM │    │ LXC VMs  │
│(Master)  │  │(Worker)  │    │(Services)│
│          │  │          │    │          │
│Tailscale │  │Tailscale │    │Tailscale │
└──────────┘  └──────────┘    └──────────┘
     │             │                │
     └─────────────┴────────────────┘
              K3s Cluster
       (Flannel CNI over Tailscale)
```

### Components:

- **Master Node**: OCI Compute Instance (K3s Control Plane)
- **Worker Node**: Proxmox Ryzen VM (K3s Agent)
- **PaaS Node**: Proxmox LXC Container running Coolify
- **Analytics Node**: Proxmox LXC Container for Vision Analytics
- **Network**: Headscale-managed Tailscale VPN mesh network
- **Infrastructure**: Terraform-provisioned, Ansible-configured

## 📦 Prerequisites

### Required Tools:
- Terraform (1.12+)
- Ansible (2.9+)
- kubectl (1.19+)
- Proxmox VE host or alternative hypervisor
- OCI Cloud account (or alternative cloud provider)
- Headscale server (self-hosted or external)

### Infrastructure Requirements:
- OCI Free Tier account with one Compute instance
- Proxmox host with sufficient resources (recommended: 4+ cores, 16GB+ RAM)
- Network connectivity between all nodes
- Headscale instance pre-configured with your domain

### Credentials Needed:
- Proxmox API credentials
- Cloud provider credentials (OCI)
- Headscale API key and pre-auth keys
- SSH key pair for infrastructure access

## 📂 Project Structure

```
homelab-k3s/
├── README.md                          # This guide
├── .gitignore                         # Git ignore rules
├── terraform/                         # Infrastructure as Code
│   ├── main.tf                       # Main Terraform configuration
│   ├── variables.tf                  # Variable definitions
│   ├── terraform.tfvars.example      # Example variables (copy and fill)
│   ├── coolify.tf                    # Coolify LXC provisioning
│   ├── visual_recognition.tf         # Analytics container provisioning
│   └── terraform.tfstate             # Managed by Terraform (don't commit)
│
├── ansible/                           # Configuration Management
│   ├── inventory.yml                 # Ansible inventory (edit with your IPs)
│   ├── k3s.yml                       # K3s cluster deployment playbook
│   ├── mesh.yml                      # Headscale/Tailscale mesh setup
│   ├── coolify.yml                   # Coolify application setup
│   ├── mesh-node.yml                 # Individual node mesh config
│   └── steps.txt                     # Manual step reference
│
├── kube_files/                        # Kubernetes manifests
│   ├── argocd-*.yml                  # ArgoCD configuration and ingress
│   ├── coolify-*.yaml                # Coolify K8s resources
│   ├── headscale-*.yaml              # Headscale K8s setup
│   ├── cluster-issuer.yml            # Let's Encrypt cert issuer
│   ├── ghcr-secret.yml.example       # GitHub Container Registry auth
│   ├── cf-secret.yml.example         # Cloudflare API credentials
│   └── jackett-deployment.yaml       # Example media service
│
├── frigate/                           # Frigate Video Surveillance
│   ├── frigate.py                    # Python utilities
│   └── frigatconfig.yaml.example     # Frigate camera configuration
│
└── docs/                              # Additional documentation
    └── troubleshooting.md            # Common issues and solutions
```

## 🚀 Setup Instructions

### Phase 1: Prepare Configuration Files

1. **Copy example files and fill in your values:**
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   cp kube_files/ghcr-secret.yml.example kube_files/ghcr-secret.yml
   cp kube_files/cf-secret.yml.example kube_files/cf-secret.yml
   cp frigate/frigatconfig.yaml.example frigate/frigatconfig.yaml
   ```

2. **Update `terraform/terraform.tfvars`:**
   - Add your Proxmox API URL and token
   - Add your SSH public key
   - Configure cloud provider credentials

3. **Update `ansible/inventory.yml`:**
   - Replace Tailscale IPs with your actual IPs
   - Update SSH usernames for each node type
   - Adjust node hostnames as needed

4. **Configure Kubernetes secrets (`kube_files/*-secret.yml`):**
   - Add your Cloudflare API token
   - Add your GitHub Container Registry credentials
   - Update any service-specific credentials

### Phase 2: Provision Infrastructure with Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This will create:
- Proxmox LXC containers (Coolify, Vision Analytics)
- OCI Compute instance (if using OCI)
- Network configurations

### Phase 3: Set Up Headscale Mesh Network

1. **Configure Tailscale/Headscale on your nodes:**
   ```bash
   ansible-playbook -i ansible/inventory.yml ansible/mesh.yml
   ```

2. **Verify mesh connectivity:**
   ```bash
   # SSH into each node and verify Tailscale IP
   ip addr show tailscale0
   ping <tailscale-ip-of-other-node>
   ```

### Phase 4: Deploy K3s Cluster

1. **Deploy K3s control plane and agents:**
   ```bash
   ansible-playbook -i ansible/inventory.yml ansible/k3s.yml
   ```

2. **Wait for cluster to be ready (2-3 minutes):**
   ```bash
   ansible master -i ansible/inventory.yml -b -a "sudo k3s kubectl get nodes"
   ```

3. **Retrieve kubeconfig:**
   ```bash
   ansible master -i ansible/inventory.yml -b -a "cat /etc/rancher/k3s/k3s.yaml"
   ```

4. **Save kubeconfig locally:**
   ```bash
   mkdir -p ~/.kube
   nano ~/.kube/config
   # Paste the contents, replace 127.0.0.1 with your master node's Tailscale IP
   chmod 600 ~/.kube/config
   ```

5. **Verify cluster:**
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

### Phase 5: Deploy Applications

1. **Deploy Coolify PaaS:**
   ```bash
   ansible-playbook -i ansible/inventory.yml ansible/coolify.yml
   kubectl apply -f kube_files/coolify-*.yaml
   ```

2. **Deploy ArgoCD (for GitOps):**
   ```bash
   kubectl apply -f kube_files/argocd-*.yml
   ```

3. **Deploy networking services:**
   ```bash
   kubectl apply -f kube_files/headscale-*.yaml
   kubectl apply -f kube_files/cluster-issuer.yml
   ```

4. **Deploy additional services:**
   ```bash
   kubectl apply -f kube_files/jackett-deployment.yaml
   ```

## ⚙️ Configuration

### Headscale Integration

Headscale provides a self-hosted alternative to Tailscale SaaS. This setup uses Headscale to create a WireGuard mesh network linking all cluster nodes.

**Key files:**
- `ansible/mesh.yml` - Configures Headscale/Tailscale on each node
- `ansible/mesh-node.yml` - Per-node mesh setup
- `kube_files/headscale-*.yaml` - Kubernetes Headscale deployment

### K3s Customization

Edit `ansible/k3s.yml` to customize:
- Flannel interface (currently uses Tailscale)
- TLS SANs (Subject Alternative Names)
- K3s version and additional arguments
- Node labels and taints

### CNI Configuration

This setup uses Flannel CNI running over Tailscale interfaces. This provides:
- Encrypted Pod-to-Pod communication
- VPN-level network isolation
- Simple mesh management

## 🔧 Troubleshooting

### Nodes not joining cluster

```bash
# Check node-token exists on master
ansible master -i ansible/inventory.yml -b -a "cat /var/lib/rancher/k3s/server/node-token"

# Check K3s agent logs on worker
ansible worker -i ansible/inventory.yml -b -a "journalctl -u k3s-agent -f"

# Verify network connectivity between nodes
ansible worker -i ansible/inventory.yml -b -a "ping -c 4 <master-ip>"
```

### Pods stuck in pending

```bash
# Check node resources
kubectl describe nodes

# Check flannel pods status
kubectl get pods -n kube-flannel

# Check CNI configuration
kubectl get cni -A
```

### Headscale/Tailscale connectivity issues

```bash
# Check Tailscale status on node
ansible master -i ansible/inventory.yml -b -a "tailscale status"

# View Tailscale routes
ansible master -i ansible/inventory.yml -b -a "ip route show table 52"
```

### TLS/Certificate issues

```bash
# Check kubelet certificates
ansible master -i ansible/inventory.yml -b -a "ls -la /etc/rancher/k3s/server/tls/"

# Check certificate expiry
kubectl get secret -A | grep tls
```

### K3s Service Uninstallation

If you need to completely remove K3s from nodes:

```bash
# Uninstall K3s server (master)
ansible master -i ansible/inventory.yml -b -a "sudo /usr/local/bin/k3s-uninstall.sh"

# Uninstall K3s agent (worker)
ansible worker -i ansible/inventory.yml -b -a "sudo /usr/local/bin/k3s-agent-uninstall.sh"
```

## 🧹 Cleanup

### Full cluster teardown:

```bash
# Kill any remaining K3s processes
ansible all -i ansible/inventory.yml -b -a "sudo killall k3s"

# Clean K3s state directories
ansible all -i ansible/inventory.yml -b -a "sudo rm -rf /etc/rancher/k3s"
ansible all -i ansible/inventory.yml -b -a "sudo rm -rf /var/lib/rancher/k3s"
ansible all -i ansible/inventory.yml -b -a "sudo rm -rf /var/lib/cni"
ansible all -i ansible/inventory.yml -b -a "sudo rm -rf /var/log/pods"
ansible all -i ansible/inventory.yml -b -a "sudo rm -rf /var/log/containers"

# Clean networking
ansible all -i ansible/inventory.yml -b -a "sudo ip link delete cni0"
ansible all -i ansible/inventory.yml -b -a "sudo ip link delete flannel.1"

# Destroy infrastructure (Terraform)
cd terraform
terraform destroy
```

## 📚 Additional Resources
- [V1 of my Config Using Raw wireguard] (https://github.com/vishvesh11/Distributed-K3s-Homelab-Cluster.git)
- [K3s Documentation](https://docs.k3s.io/)
- [Headscale Documentation](https://headscale.dev/)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [Flannel CNI](https://github.com/flannel-io/flannel)
- [Ansible Documentation](https://docs.ansible.com/)
- [Terraform Documentation](https://www.terraform.io/docs)


## 📝 License

This configuration is provided as-is for educational and reference purposes.

## 🤝 Contributing

Feel free to suggest improvements and optimizations!


npm install --legacy-peer-deps
npm install webpack@5.105.0 --save-dev --legacy-peer-deps