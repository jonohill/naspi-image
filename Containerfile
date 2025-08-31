FROM quay.io/almalinuxorg/almalinux-bootc-rpi:10-kitten

# Copy files first
COPY root/ /
COPY disks.txt /tmp/disks.txt
COPY generate-unlock-services.sh /tmp/generate-unlock-services.sh

RUN dnf install -y \
        age \
        btrfs-progs \
        gettext

# Set default repo if not provided
ARG NASPI_REPO
ENV NASPI_REPO=${NASPI_REPO:-https://github.com/jonohill/naspi-image.git}

# Substitute environment variables in shell scripts
RUN envsubst < /usr/local/bin/download_secrets.sh > /tmp/download_secrets.sh && \
    mv /tmp/download_secrets.sh /usr/local/bin/download_secrets.sh && \
    chmod +x /usr/local/bin/download_secrets.sh

# Generate unlock-all-disks.service based on disks.txt
RUN chmod +x /tmp/generate-unlock-services.sh && \
    cd /tmp && \
    ./generate-unlock-services.sh && \
    rm -f /tmp/disks.txt /tmp/generate-unlock-services.sh
