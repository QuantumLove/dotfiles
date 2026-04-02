FROM debian:bookworm-slim

# =============================================================================
# VERSIONS - Update these when upgrading tools
# =============================================================================
# helm:      3.15.4
# gh:        2.67.0
# lazygit:   0.44.1
# pulumi:    3.161.0
# docker:    24.0.7
# compose:   2.32.4
# buildx:    0.21.1
# =============================================================================

# =============================================================================
# ARCHITECTURE NAMING CONVENTIONS (lesson learned: each tool is different!)
# =============================================================================
# Tool            | Method                | arm64 value  | x86_64 value
# ----------------|----------------------|--------------|---------------
# dpkg            | dpkg --print-arch    | arm64        | amd64
# uname           | uname -m             | aarch64      | x86_64
# helm            | dpkg arch            | arm64        | amd64
# gh              | uname -> arm64       | arm64        | (no mapping)
# pulumi          | uname -> arm64/x64   | arm64        | x64
# aws cli         | uname (native)       | aarch64      | x86_64
# docker cli      | uname (native)       | aarch64      | x86_64
# docker-compose  | uname (native)       | aarch64      | x86_64
# docker-buildx   | uname -> arm64/amd64 | arm64        | amd64
# =============================================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    cron \
    curl \
    git \
    sudo \
    tmux \
    openssh-client \
    openssh-server \
    build-essential \
    libssl-dev \
    pkg-config \
    unzip \
    gnupg \
    jq \
    iptables \
    iproute2 \
    zstd \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Install Tailscale
RUN curl -fsSL https://tailscale.com/install.sh | sh

# 1Password CLI
RUN ARCH=$(dpkg --print-architecture) && \
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    gpg --dearmor -o /usr/share/keyrings/1password.gpg && \
    echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/1password.gpg] https://downloads.1password.com/linux/debian/${ARCH} stable main" > \
    /etc/apt/sources.list.d/1password.list && \
    apt-get update && apt-get install -y 1password-cli && \
    rm -rf /var/lib/apt/lists/*

RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin && \
    curl https://mise.run | sh && \
    mv ~/.local/bin/mise /usr/local/bin/mise

# helm and gh - direct install (asdf plugins broken, aqua needs GitHub token)
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL https://get.helm.sh/helm-v3.15.4-linux-${ARCH}.tar.gz | tar xz -C /tmp && \
    mv /tmp/linux-${ARCH}/helm /usr/local/bin/helm && \
    rm -rf /tmp/linux-${ARCH}

RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi && \
    curl -fsSL https://github.com/cli/cli/releases/download/v2.67.0/gh_2.67.0_linux_${ARCH}.tar.gz | tar xz -C /tmp && \
    mv /tmp/gh_2.67.0_linux_${ARCH}/bin/gh /usr/local/bin/gh && \
    rm -rf /tmp/gh_*

# Lazygit
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; elif [ "$ARCH" = "x86_64" ]; then ARCH="x86_64"; fi && \
    curl -fsSL https://github.com/jesseduffield/lazygit/releases/download/v0.44.1/lazygit_0.44.1_Linux_${ARCH}.tar.gz | tar xz -C /tmp && \
    mv /tmp/lazygit /usr/local/bin/lazygit && \
    rm -rf /tmp/lazygit*

# Pulumi CLI
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; else ARCH="x64"; fi && \
    curl -fsSL https://get.pulumi.com/releases/sdk/pulumi-v3.161.0-linux-${ARCH}.tar.gz | tar xz -C /tmp && \
    mv /tmp/pulumi/* /usr/local/bin/ && \
    rm -rf /tmp/pulumi

# AWS CLI
RUN ARCH=$(uname -m) && \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    sudo /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# Docker CLI (for building images via Pulumi docker-build provider)
RUN ARCH=$(uname -m) && \
    curl -fsSL "https://download.docker.com/linux/static/stable/${ARCH}/docker-24.0.7.tgz" | tar xz -C /tmp && \
    mv /tmp/docker/docker /usr/local/bin/ && \
    rm -rf /tmp/docker

# Docker Compose plugin
RUN ARCH=$(uname -m) && \
    mkdir -p /usr/local/lib/docker/cli-plugins && \
    curl -fsSL "https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-${ARCH}" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Docker Buildx plugin (uses arm64/amd64 naming, NOT aarch64/x86_64)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; elif [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi && \
    curl -fsSL "https://github.com/docker/buildx/releases/download/v0.21.1/buildx-v0.21.1.linux-${ARCH}" \
      -o /usr/local/lib/docker/cli-plugins/docker-buildx && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# Verify Docker CLI plugins are working (fail fast at build time, not runtime)
RUN docker compose version && docker buildx version

# OSC 52 clipboard wrapper (enables copy from container to host terminal)
# OpenCode/xclip/xsel use this to send clipboard data via terminal escape sequences
RUN printf '%s\n' '#!/bin/bash' \
    '# OSC 52 clipboard wrapper - sends clipboard to host via terminal' \
    'data=$(cat | base64 | tr -d "\\n")' \
    'if [ -e /dev/tty ]; then' \
    '    printf "\\e]52;c;%s\\a" "$data" > /dev/tty' \
    'else' \
    '    printf "\\e]52;c;%s\\a" "$data"' \
    'fi' > /usr/local/bin/osc52-clipboard && \
    chmod +x /usr/local/bin/osc52-clipboard && \
    ln -sf /usr/local/bin/osc52-clipboard /usr/local/bin/xclip && \
    ln -sf /usr/local/bin/osc52-clipboard /usr/local/bin/xsel

# UID 501 matches macOS host user for SSH socket permissions
# Username matches Tailscale identity local-part for Tailscale SSH
RUN useradd -m -s /bin/bash -u 501 rafaelcarvalho && \
    echo 'rafaelcarvalho ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    usermod -aG docker rafaelcarvalho 2>/dev/null || true

USER rafaelcarvalho
WORKDIR /home/rafaelcarvalho

ENV MISE_DATA_DIR="/home/rafaelcarvalho/.local/share/mise" \
    MISE_CONFIG_DIR="/home/rafaelcarvalho/.config/mise" \
    PATH="/home/rafaelcarvalho/.local/share/mise/shims:$PATH" \
    MISE_YES=true

COPY --chown=rafaelcarvalho:rafaelcarvalho .config/mise/config.toml .config/mise/
RUN mise trust -a && mise install && \
    npm install -g yarn opencode-ai @anthropic-ai/claude-code oh-my-opencode @googleworkspace/cli && \
    oh-my-opencode install --no-tui --claude=yes --gemini=no --copilot=no

COPY --chown=rafaelcarvalho:rafaelcarvalho entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
