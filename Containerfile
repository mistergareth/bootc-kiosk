# Base image for CentOS Stream 10 bootc
FROM quay.io/centos-bootc/centos-bootc:stream10

# Install necessary packages: GNOME group for graphical desktop, browsers, SSH for testing
RUN dnf install -y --setopt=install_weak_deps=False \
    @server-with-gui \
    firefox \
    openssh-server && \
    # Add Google Chrome repo and install stable version
    cat <<EOF > /etc/yum.repos.d/google-chrome.repo \
[google-chrome] \
name=google-chrome - stable \
baseurl=http://dl.google.com/linux/chrome/rpm/stable/\$basearch \
enabled=1 \
gpgcheck=1 \
gpgkey=https://dl.google.com/linux/linux_signing_key.pub \
EOF && \
    dnf install -y --setopt=install_weak_deps=False google-chrome-stable && \
    # Clean up to reduce image size
    dnf autoremove -y && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Create kiosk user "agent"
RUN useradd -m agent

# Configure auto-login for "agent" user in GDM
RUN mkdir -p /etc/gdm && \
    echo "[daemon]" >> /etc/gdm/custom.conf && \
    echo "AutomaticLoginEnable=True" >> /etc/gdm/custom.conf && \
    echo "AutomaticLogin=agent" >> /etc/gdm/custom.conf

# Set up auto-start for Chrome in kiosk mode as "agent"
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


# Boot to graphical target
RUN systemctl set-default graphical.target

# Allow root SSH login with password for testing
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Further hardening (optional: allow/deny hosts, domains, disable shell, etc.)
# Apply DISA STIG hardening (SELinux remains enforcing; removes tools after)
RUN oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig \
	--remediate /usr/share/xml/scap/ssg/content/ssg-cs10-ds.xml && \
    dnf remove -y openscap-scanner scap-security-guide && \
    dnf clean all

# Enable SSHD for testing
RUN systemctl enable sshd

# Root password "redhat" + allow root login (testing only! STIG may override)
RUN echo "redhat" | passwd --stdin root && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config


# After deployment, run `sestatus` (should show Enforcing) 
# and `oscap xccdf eval --profile stig` for compliance report.

