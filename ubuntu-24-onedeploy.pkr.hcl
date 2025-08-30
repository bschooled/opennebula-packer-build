packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "iso_url" {
  default = "file:///home/bschooley/onedeploy-packer/source-image/ubuntu-24.04.3-live-server-amd64.iso"
}

source "qemu" "custom_image" {
  iso_url              = "file:///home/bschooley/onedeploy-packer/source-image/ubuntu-24.04.3-live-server-amd64.iso"
  iso_checksum         = "none"
  output_directory     = "output"
  vm_name              = "ubuntu-24.04-onedeploy.qcow2"
  memory               = 4096
  cpus                 = 6
  accelerator          = "kvm"
  disk_size            = "60G"
  disk_interface       = "virtio"
  format               = "qcow2"
  efi_boot             = true
  efi_firmware_code   = "/usr/share/OVMF/OVMF_CODE_4M.fd"
  efi_firmware_vars   = "/usr/share/OVMF/OVMF_VARS_4M.fd"
  net_device           = "virtio-net"
  boot_wait            = "3s"
  http_directory       = "cloud-init"
  shutdown_command     = "echo 'packer' | sudo -S shutdown -P now"
  ssh_username         = "nebula"
  ssh_password         = "nebula"
  ssh_port             = 2222
  ssh_host             = "127.0.0.1"
  ssh_timeout          = "60m"
  skip_nat_mapping     = true
  headless             = false

  qemuargs = [
    ["-netdev", "user,id=net0,hostfwd=tcp::2222-:22"],
    ["-device", "virtio-net,netdev=net0"]
  ]

  boot_command = [
    "<wait2>e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=\"nocloud-net;s=http://{{.HTTPIP}}:{{.HTTPPort}}/\" ",
    "<f10>"
  ]
}

build {
  sources = ["source.qemu.custom_image"]

  provisioner "file" {
    source      = "cloud-init/service-scripts"
    destination = "/tmp"
  }
    provisioner "file" {
    source      = "cloud-init/onedeploy-configs"
    destination = "/tmp"
  }
  provisioner "shell" {
    script = "scripts/provision.sh"
    execute_command = "echo 'packer' | sudo -S sh '{{.Path}}'"
  }
}
