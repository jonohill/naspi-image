FROM quay.io/almalinuxorg/almalinux-bootc-rpi:10-kitten

# Copy files first
COPY root/ /
COPY disks.txt /tmp/disks.txt
COPY generate-unlock-services.sh /tmp/generate-unlock-services.sh

RUN dnf install -y \
        btrfs-progs \
        gettext \
        git

# Download and install the latest version of age
RUN LATEST_VERSION=$(curl -s https://api.github.com/repos/FiloSottile/age/releases/latest | jq -r '.tag_name') && \
    curl -L "https://github.com/FiloSottile/age/releases/download/${LATEST_VERSION}/age-${LATEST_VERSION}-linux-arm64.tar.gz" -o /tmp/age.tar.gz && \
    tar -xzf /tmp/age.tar.gz -C /tmp && \
    mv /tmp/age/age /usr/local/bin/ && \
    mv /tmp/age/age-keygen /usr/local/bin/ && \
    chmod +x /usr/local/bin/age /usr/local/bin/age-keygen && \
    rm -rf /tmp/age.tar.gz /tmp/age

# Set default repo if not provided
ARG NASPI_REPO
ENV NASPI_REPO=${NASPI_REPO:-https://github.com/jonohill/naspi-image.git}

# Substitute environment variables in shell scripts
RUN envsubst '$NASPI_REPO' < /usr/local/bin/download_secrets.sh > /tmp/download_secrets.sh && \
    mv /tmp/download_secrets.sh /usr/local/bin/download_secrets.sh && \
    chmod +x /usr/local/bin/download_secrets.sh

# Generate unlock-all-disks.service based on disks.txt
RUN chmod +x /tmp/generate-unlock-services.sh && \
    cd /tmp && \
    ./generate-unlock-services.sh && \
    rm -f /tmp/disks.txt /tmp/generate-unlock-services.sh
