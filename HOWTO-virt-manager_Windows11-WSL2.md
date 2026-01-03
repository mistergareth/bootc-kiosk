## How to run **virt-manager on Windows 11 via WSL2**

This doc provides steps to set up **virt-manager on Windows 11 via WSL2** for native **libvirt/QEMU/KVM** virtualization.

Yes, you can get a full **libvirt/QEMU/KVM** virtualization setup (with GUI management) without leaving Windows using WSL2.

Due to WSL2 integrations and design, **Ubuntu (or another Debian-based distro)** is strongly recommended for running **virt-manager** on **WSL2**. It's not strictly necessary, but it's by far the easiest and most reliable option regardless of your personal preferred distro family or which VMs you plan to use.

### **Why Ubuntu Is Best for virt-manager on Windows 11 WSL2**

* **WSL2 GUI support (WSLg)** works best with Debian/Ubuntu packages—virt-manager (a GTK-based app) and installs cleanly via apt with minimal issues.  
* Community guides, troubleshooting, and pre-built packages overwhelmingly focus on Ubuntu (e.g., sudo apt install virt-manager qemu-kvm libvirt-clients libvirt-daemon-system works out-of-the-box).  
* Ubuntu has excellent systemd integration in WSL2, which virt-manager/libvirt relies on.  
* Many users report font/UI glitches or dependency headaches with other distros in WSLg.

Ubuntu is the default WSL distro for a reason—it's the most polished for this use case.

### **Steps to Configure virt-manager**

Stick with **Ubuntu 22.04 or 24.04 LTS** from the Microsoft Store:

1. `wsl --install -d` Ubuntu (or search "Ubuntu" in Store).  
2. Update: sudo apt update && sudo apt upgrade  
3. Install virt-manager stack: `sudo apt install virt-manager qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils`  
4. Launch Virt-manager. It runs as a native Windows app via WSLg.

Your CentOS Stream bootc QCOW2 images will import directly and natively into virt-manager/QEMU.
No VirtualBox limitations (seamless mouse via virtio, better perf).

