terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true
}

resource "proxmox_virtual_environment_vm" "k3s_worker_ryzen" {
  name        = "k3s-worker-ryzen"
  description = "Managed by Terraform"
  node_name   = "pro" # Change to your Proxmox node name


  # Clone the template we built in Step 2
  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  # MEMORY BALLOONING MAGIC
  memory {
    dedicated = 48768 # Max RAM: 48GB
    floating  = 8192  # Min RAM: 8GB (Ballooning)
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 100 # 100GB storage for container images
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
  }

  # Cloud-Init Network and User setup
  initialization {
    ip_config {
      ipv4 {
        # Give this VM a Static IP on your local LAN!
        address = "192.168.5.30/24" # Change to an available IP
        gateway = "192.168.5.1"     # Your pfSense IP
      }
    }
    user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
    }
  }
}
