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
    && echo "redhat" | passwd --stdin root \
    && mkdir -p /var/home/agent/.ssh \
    && mkdir -p /var/roothome/.ssh \
    && chown -R agent:agent /var/home/agent \
    && echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEmXUGcj4QO1+Q7Anhvot5iK7U5oxK5K0a+XxZ4ZI8X Laptop@DESKTOP-VFB0HOM" >> /var/home/agent/.ssh/authorized_keys \
    && echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEmXUGcj4QO1+Q7Anhvot5iK7U5oxK5K0a+XxZ4ZI8X Laptop@DESKTOP-VFB0HOM" >> /var/roothome/.ssh/authorized_keys \
    && chown 700 /var/roothome/.ssh /var/home/agent/.ssh \
    && chown 600 /var/home/agent/.ssh/authorized_keys /var/roothome/.ssh/authorized_keys

# Debug: Test if the SSH files were created since they are not showing up in image or failing during build.
# May be overridden later in process:
#RUN echo $(ls -la /var/home/agent/.ssh/ /var/roothome/.ssh/) || TRUE \
RUN ls -la /var/home/agent/.ssh/ /var/roothome/.ssh/ || true

RUN if [ -f /var/home/agent/.ssh/authorized_keys ] ; then echo "agent's authorized_keys file: "; cat /var/home/agent/.ssh/authorized_keys; \
       else echo "agent's authorized_keys file not found"; fi \
    && if [ -f /var/roothome/.ssh/authorized_keys ] ; then echo "root's authorized_keys file: "; cat /var/roothome/.ssh/authorized_keys; \
       else echo "root's authorized_keys file not found"; fi


# SSH key to enable secure access from laptop/host
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEmXUGcj4QO1+Q7Anhvot5iK7U5oxK5K0a+XxZ4ZI8X Laptop@DESKTOP-VFB0HOM

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
    && cat <<EOF > /var/home/agent/.config/autostart/chrome-kiosk.desktop
[Desktop Entry]
Type=Application
Exec=google-chrome-stable --no-first-run --start-maximized --password-store=basic https://everythingbreaks.com/
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Chrome Kiosk
EOF

# Set Chrome as default browser system-wide and for agent user
RUN cat <<EOF > /var/home/agent/.config/mimeapps.list 
[Default Applications]
text/html=google-chrome.desktop
x-scheme-handler/http=google-chrome.desktop
x-scheme-handler/https=google-chrome.desktop
x-scheme-handler/about=google-chrome.desktop
x-scheme-handler/unknown=google-chrome.desktop
EOF

# Suppress Chrome first-run prompts (default browser + usage stats)
RUN mkdir -p /var/home/agent/.config/google-chrome \
    && touch /var/home/agent/.config/google-chrome/"First Run" \
    && chown -R agent:agent /var/home/agent/.config

# Prevent Chrome from prompting users to create keyring passwords by adding 
# the --password-store=basic option to Chrome's global settings (will ensure
# this for all Chrome launches, including manual)
RUN sed -i '/^Exec=/s/$/ --password-store=basic/' /usr/share/applications/google-chrome.desktop

# Set "chrome" short-name alias to start browser if needed
RUN echo "alias chrome=/opt/google/chrome/google-chrome" >> ~agent/.bash_profile

# Set graphical target + enable SSH
RUN systemctl set-default graphical.target \
    && systemctl enable sshd

# Explicitly allow password authentication + root login over SSH (testing only)
RUN sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# Drop a version and date file for testing and validation
RUN touch /usr/share/kiosk-upgraded-alpha8 && echo "Upgraded on $(date)" > /etc/kiosk-version
