# Base image: CentOS Stream 10 bootc (immutable image mode)
FROM quay.io/centos-bootc/centos-bootc:stream10

# Install minimal GNOME desktop components individually + browsers + tools
# Core: GDM, shell, session, Wayland/Xwayland support
# Additional: Settings, themes, fonts, etc. for complete experience
# SSH + OpenSCAP for hardening
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
    openssh-server #\
#    openscap-scanner \
#    scap-security-guide

# Fix for a base OS image quirk where /home may be a file, not a dir
RUN rm -f /home && mkdir -p /home && chown root:root /home && chmod 755 /home

##------ The DISA STIG hardening removes GDM and bunch of other ------##
##       stuff that breaks functionality we need.
##
## Apply DISA STIG security hardening profile using OpenSCAP
## SELinux in enforcing mode + broad system hardening
## Note: May conflict with root SSH password login — test and adjust if needed
#RUN oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig \
#    --remediate \
#    /usr/share/xml/scap/ssg/content/ssg-cs10-ds.xml

## Remove OpenSCAP tools after remediation to keep image lightweight
#RUN dnf remove -y openscap-scanner scap-security-guide && \

# Add official Google Chrome repository and install latest stable version)
RUN cat <<EOF > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF && \
    # Install google-chrome-stable
    dnf install -y --setopt=install_weak_deps=False google-chrome-stable


# Create the kiosk user "agent" with home directory
# Set a basic password for agent (required for GDM auto-login to work reliably)
# Use "agent" here – change to something stronger if desired
RUN useradd -m agent && echo "agent:agent" | chpasswd

# Configure auto-login for "agent" user in GDM
RUN mkdir -p /etc/gdm && \
    cat <<EOF > /etc/gdm/custom.conf
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=agent

# testing only! Remove this section for production image
[security]
DisableRoot=false
EOF

##---- Keeping this as an example if needed to do separately ----##
## Enable root login at GDM graphical screen (testing only!)
#RUN sed -i '/^\[security\]/a DisableRoot=false' /etc/gdm/custom.conf || \
#    echo "[security]\nDisableRoot=false" >> /etc/gdm/custom.conf

# Set Chrome browser to autostart in kiosk mode as "agent" user
RUN mkdir -p /home/agent/.config/autostart && \
    chown -R agent:agent /home/agent/.config && \
    cat <<EOF > /home/agent/.config/autostart/chrome-kiosk.desktop
[Desktop Entry]
Type=Application
Exec=google-chrome-stable --kiosk https://everythingbreaks.com/
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Chrome Kiosk
EOF

# Ensure system boots to graphical interface (GNOME on Wayland)
RUN systemctl set-default graphical.target

# Enable SSH server for remote access during testing
RUN systemctl enable sshd

# Clean up any left over dnf junk files after installs to reduce image size
RUN dnf autoremove -y && \
    dnf clean all && \
    rm -rf /var/cache/dnf/*

# Set root password to "redhat" (testing only! STIG will override in production)
RUN echo "root:redhat" | chpasswd

# Allow root login over SSH with password (testing only — STIG may override)
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# After deployment, run `sestatus` (should show Enforcing)
# and `oscap xccdf eval --profile stig` for a compliance report.

