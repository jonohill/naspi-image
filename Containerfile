FROM quay.io/almalinuxorg/almalinux-bootc-rpi:10 AS base

# Build stage for ZFS packages
# (not published for arm64)
FROM base AS zfs-builder

RUN dnf install -y \
        epel-release \
        rpm-build \
        rpmdevtools

RUN mkdir -p /tmp/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

RUN cd /tmp && \
    curl -O http://download.zfsonlinux.org/epel/10/SRPMS/zfs-dkms-2.2.8-1.el10.src.rpm && \
    curl -O http://download.zfsonlinux.org/epel/10/SRPMS/zfs-2.2.8-1.el10.src.rpm && \
    rpm -ivh --define "_topdir /tmp/rpmbuild" zfs-dkms-2.2.8-1.el10.src.rpm && \
    rpm -ivh --define "_topdir /tmp/rpmbuild" zfs-2.2.8-1.el10.src.rpm

RUN dnf builddep -y \
        /tmp/rpmbuild/SPECS/zfs-dkms.spec \
        /tmp/rpmbuild/SPECS/zfs.spec

RUN rpmbuild --define "_topdir /tmp/rpmbuild" -bb /tmp/rpmbuild/SPECS/zfs-dkms.spec && \
    rpmbuild --define "_topdir /tmp/rpmbuild" -bb /tmp/rpmbuild/SPECS/zfs.spec

# Final stage
FROM base

# Copy files first
COPY root/ /

RUN dnf install -y \
        epel-release \
        gettext \
    git \
    jq

# Install correct kernel headers
RUN if rpm -q raspberrypi2-kernel4 &> /dev/null; then \
        dnf install -y raspberrypi2-kernel4-devel; \
    else \
        dnf install -y kernel-devel; \
    fi

# Build kernel module for zfs
RUN \
    --mount=from=zfs-builder,source=/tmp/rpmbuild/RPMS,target=/zfs-rpms \
    export KERNEL_VERSION="$(ls /usr/lib/modules)" && \
    echo "Kernel version: $KERNEL_VERSION" && \
    dnf install -y /zfs-rpms/noarch/zfs-dkms-*.rpm && \
    dkms autoinstall -k "$KERNEL_VERSION" && \
    dnf install -y \
        /zfs-rpms/aarch64/libnvpair3-*.rpm \
        /zfs-rpms/aarch64/libuutil3-*.rpm \
        /zfs-rpms/aarch64/libzfs5-*.rpm \
        /zfs-rpms/aarch64/libzpool5-*.rpm \
        /zfs-rpms/aarch64/zfs-*.rpm \
        /zfs-rpms/noarch/python3-pyzfs-*.rpm \
        /zfs-rpms/noarch/zfs-dracut-*.rpm

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
RUN envsubst '$NASPI_REPO' < /usr/local/sbin/download_secrets.sh > /tmp/download_secrets.sh && \
    mv /tmp/download_secrets.sh /usr/local/sbin/download_secrets.sh && \
    chmod +x /usr/local/sbin/download_secrets.sh
