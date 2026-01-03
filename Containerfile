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
RUN useradd -m agent \
    && usermod -aG wheel agent \
    && echo "agent" | passwd --stdin agent \
    && echo "redhat" | passwd --stdin root

# Configure GDM: auto-login for agent + allow root graphical login (testing only)
RUN mkdir -p /etc/gdm \
    && cat <<EOF > /etc/gdm/custom.conf
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=agent

[security]
DisableRoot=false
EOF

# Set Chrome kiosk autostart in correct persistent location
RUN mkdir -p /var/home/agent/.config/autostart \
    && chown -R agent:agent /var/home/agent/.config \
    && cat <<EOF > /var/home/agent/.config/autostart/chrome-kiosk.desktop
[Desktop Entry]
Type=Application
Exec=google-chrome-stable --kiosk https://everythingbreaks.com/
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Chrome Kiosk
EOF

# Set graphical target + enable SSH
RUN systemctl set-default graphical.target \
    && systemctl enable sshd

# Explicitly allow password authentication + root login over SSH (testing only)
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

