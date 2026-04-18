


resource "proxmox_virtual_environment_container" "coolify_lxc" {
  description = "Managed by Terraform - Coolify PaaS"
  node_name   = "pro" # Matching your node_name

  # Note: You must have this Ubuntu template downloaded to your local storage
  operating_system {
    template_file_id = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
    type             = "ubuntu"
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 8192 # 8GB RAM is the sweet spot for Coolify + Builders
    swap      = 2048
  }

  disk {
    datastore_id = "local-lvm"
    size         = 50 # 50GB for containers and images
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "coolify-server"

    ip_config {
      ipv4 {
        # Giving it the next logical static IP in your subnet
        address = "192.168.5.31/24"
        gateway = "192.168.5.1"
      }
    }

    user_account {
      # Use your existing SSH key variable for access
      keys = [var.ssh_public_key]
    }
  }

  # CRITICAL: These features allow Docker to run securely inside the LXC
  features {
    nesting = true
    #keyctl  = true
  }

  unprivileged = true
}
