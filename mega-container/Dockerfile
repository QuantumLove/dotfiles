FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
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
    npm install -g opencode-ai @anthropic-ai/claude-code oh-my-opencode && \
    oh-my-opencode install --no-tui --claude=yes --gemini=no --copilot=no

COPY --chown=rafaelcarvalho:rafaelcarvalho entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
