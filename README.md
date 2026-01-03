# bootc-kiosk

Containerfile for bootc images to build restricted kiosk-style OS disk images.

This project is for a Containerfile, based on CentOS 10, that can be used to 
create a bootable disk image (bootc) that is restricted in "kiosk" mode with 
only access to the browser for users to access their web-based tools but 
nothing else.

See the **HOWTO-virt-manager_Windows11-WSL2.md** document for steps to set up a
native Linux libvirt/QEMU/KVM environment for VM testing on Windows 11 via WSL2.
