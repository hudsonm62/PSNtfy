# Dockerfile for Dev Container
## Installs PowerShell, Node.js, and Python
#FROM mcr.microsoft.com/powershell:7.5-debian-bookworm
FROM mcr.microsoft.com/dotnet/sdk:9.0-bookworm-slim

# setup non root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG NODE_VERSION=24.x

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN \
    apt-get update && apt-get -y install --no-install-recommends \
        git sudo wget \
        python3 python3-pip python3-venv \
    #
    # Install Node from Nodesource
    && wget -qO- https://deb.nodesource.com/setup_${NODE_VERSION} | bash - \
    && apt-get -y install --no-install-recommends nodejs \
    && npm install -g npm@latest \
    #
    # cleanup
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    #
    # Create a non-root user to use -- https://aka.ms/vscode-remote/containers/non-root-user
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd -s /bin/bash --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
    # Add sudo support for the non-root user
    && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    #
    # Activate venv
    && python3 -m venv /opt/venv \
    && chown -R ${USER_UID}:${USER_GID} /opt/venv \
    #
    # Setup PowerShell
    && pwsh -Command "Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'" \
    && pwsh -Command "Install-Module -Name 'Pester' -Scope 'AllUsers' -Force -MaximumVersion '5.7.1'" \
    && pwsh -Command "Install-Module -Name 'PSake' -Scope 'AllUsers' -Force"

ENV PATH="/opt/venv/bin:$PATH"
ENV POWERSHELL_TELEMETRY_OPTOUT=1
