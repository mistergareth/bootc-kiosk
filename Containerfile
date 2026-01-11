# Base image: CentOS Stream 10 bootc (immutable image mode)
FROM quay.io/centos-bootc/centos-bootc:stream10

# Add official Google Chrome repo
RUN cat <<EOF > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

# Install required packages (minimal GNOME + tools)
RUN dnf install -y --setopt=install_weak_deps=False \
    gdm \
    gnome-shell \
    gnome-session-wayland-session \
    xorg-x11-server-Xwayland \
    mutter \
    gnome-control-center \
    adwaita-icon-theme \
    adwaita-cursor-theme \
    NetworkManager-wifi \
    firefox \
    google-chrome-stable \
    openssh-server \
    accountsservice \
    sudo \
    && dnf autoremove -y \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

# Create kiosk user "agent" (home will be /var/home/agent automatically)
# Add to wheel for sudo access (testing only)
# Set passwords reliably
# Preconfigure authorized SSH keys for secure access
RUN useradd -m agent \
    && usermod -aG wheel agent \
    && echo "agent" | passwd --stdin agent \
    && echo "redhat" | passwd --stdin root

# Configure SSH for testing (PasswordAuthentication, root login)
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# Set up SSH authorized_keys for agent and root via profile.d script (testing only, creates if missing on boot/upgrade)
# For reference: Use this public SSH key to enable secure access from laptop/host:
#       ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEmXUGcj4QO1+Q7Anhvot5iK7U5oxK5K0a+XxZ4ZI8X Laptop@DESKTOP-VFB0HOM
RUN mkdir -p /etc/profile.d \
    && cat <<'EOF' > /etc/profile.d/ssh-setup.sh
#!/bin/bash
# Create .ssh and authorized_keys if not exist (persists across upgrades)
for user_dir in /var/home/agent /var/roothome; do
    if [ ! -d "\$user_dir/.ssh" ]; then
        mkdir -p "\$user_dir/.ssh"
        chmod 700 "\$user_dir/.ssh"
	if [ grep -q "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEmXUGcj4QO1+Q7Anhvot5iK7U5oxK5K0a+XxZ4ZI8X Laptop@DESKTOP-VFB0HOM" "\$user_dir/.ssh/authorized_keys" ]; then
	    true
	else echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEmXUGcj4QO1+Q7Anhvot5iK7U5oxK5K0a+XxZ4ZI8X Laptop@DESKTOP-VFB0HOM" >> "\$user_dir/.ssh/authorized_keys"
        chmod 600 "\$user_dir/.ssh/authorized_keys"
	fi
    fi
done
chown -R agent:agent /var/home/agent/.ssh 2>/dev/null || true
chown -R root:root /var/roothome/.ssh 2>/dev/null || true
EOF 
    && chmod 755 /etc/profile.d/ssh-setup.sh

# Configure GDM: auto-login for agent + allow root graphical login (testing only)
RUN mkdir -p /etc/gdm \
    && cat <<EOF > /etc/gdm/custom.conf
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=agent

[security]
DisableRoot=false
EOF

# Set Chrome as default browser 
RUN mkdir -p /var/home/agent/.config \
    && cat <<EOF > /var/home/agent/.config/mimeapps.list
[Default Applications]
text/html=google-chrome.desktop
x-scheme-handler/http=google-chrome.desktop
x-scheme-handler/https=google-chrome.desktop
x-scheme-handler/about=google-chrome.desktop
x-scheme-handler/unknown=google-chrome.desktop
EOF 
    && chown -R agent:agent /var/home/agent/.config

# Set Chrome kiosk autostart in correct persistent location
RUN mkdir -p /var/home/agent/.config/autostart \
    && chown -R agent:agent /var/home/agent/.config \
    && cat <<EOF > /var/home/agent/.config/autostart/chrome-kiosk.desktop
[Desktop Entry]
Type=Application
Exec=google-chrome-stable --no-first-run --start-maximized --password-store=basic https://everythingbreaks.com/
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Chrome Kiosk
EOF

# Suppress Chrome first-run prompts (default browser + usage stats)
RUN mkdir -p /var/home/agent/.config/google-chrome \
    && touch /var/home/agent/.config/google-chrome/"First Run" \
    && chown -R agent:agent /var/home/agent/.config

# Make --password-store=basic the default option to Chrome's global settings 
# (will ensure this for all Chrome launches, including manual)
RUN sed -i '/^Exec=/s/$/ --password-store=basic/' /usr/share/applications/google-chrome.desktop

# Set "chrome" short-name alias to start browser if needed
RUN echo "alias chrome=/opt/google/chrome/google-chrome --password-store=basic" >> ~agent/.bash_profile

# Set graphical target + enable SSH
RUN systemctl set-default graphical.target \
    && systemctl enable sshd

# Drop a version and date file for testing and validation
RUN touch /usr/share/kiosk-upgraded-alpha9 && echo "Upgraded on $(date)" > /etc/kiosk-version
