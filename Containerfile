# Base image: CentOS Stream 10 bootc (immutable image mode)
FROM quay.io/centos-bootc/centos-bootc:stream10

# Add official Google Chrome repo (separate layer to avoid heredoc parsing issues)
RUN cat <<EOF > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

# Install minimal GNOME desktop components + browsers + tools
RUN dnf install -y --setopt=install_weak_deps=False \
    gdm \
    gnome-shell \
    gnome-session-wayland-session \
    xorg-x11-server-Xwayland \
    mutter \
    gnome-control-center \
    gnome-console \
    adwaita-icon-theme \
    adwaita-cursor-theme \
    NetworkManager-wifi \
    firefox \
    google-chrome-stable \
    openssh-server \
    && dnf autoremove -y \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

# Fix for base image quirk: /home may exist as a file instead of a directory
RUN rm -f /home \
    && mkdir -p /home \
    && chown root:root /home \
    && chmod 755 /home

# Create kiosk user "agent" + set password (required for reliable GDM auto-login)
RUN useradd -m agent \
    && echo "agent:agent" | chpasswd \
    && echo "root:redhat" | chpasswd

# Configure GDM: auto-login for agent + allow root login at GDM (testing only)
RUN mkdir -p /etc/gdm \
    && cat <<EOF > /etc/gdm/custom.conf
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=agent

# testing only! Remove this section for production image
[security]
DisableRoot=false
EOF

# Set Chrome to autostart in kiosk mode for user "agent"
RUN mkdir -p /home/agent/.config/autostart \
    && chown -R agent:agent /home/agent/.config \
    && cat <<EOF > /home/agent/.config/autostart/chrome-kiosk.desktop
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

# Allow root login over SSH with password (testing only)
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Optional: If you later want to re-enable STIG hardening, uncomment below
# and test thoroughly – it often breaks graphical login / GDM
#
# RUN oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig \
#     --remediate \
#     /usr/share/xml/scap/ssg/content/ssg-cs10-ds.xml \
#     && dnf remove -y openscap-scanner scap-security-guide \
#     && dnf clean all

