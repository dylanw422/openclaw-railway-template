FROM node:22-bookworm

# Install system dependencies
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gosu \
    procps \
    python3 \
    build-essential \
  && rm -rf /var/lib/apt/lists/*

# 1. Enable pnpm globally first
RUN corepack enable

# 2. CACHEBUST: Change this value at build time to force a fresh git clone
#    This ensures you get the latest commit with zai/glm-5 support.
ARG CACHEBUST=1

# 3. Clone the latest code from GitHub
RUN git clone https://github.com/openclaw/openclaw.git /opt/openclaw

# 4. Build OpenClaw from source
WORKDIR /opt/openclaw
RUN pnpm install
RUN pnpm ui:build
RUN pnpm build

# 5. Make the 'openclaw' command available globally
#    This installs the binary to /usr/local/bin and the package to /usr/local/lib/node_modules
RUN npm link

# 6. Setup runtime directory
WORKDIR /app

# Copy entrypoint script
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

# 7. Create user and setup permissions
RUN useradd -m -s /bin/bash openclaw \
  && chown -R openclaw:openclaw /app \
  && mkdir -p /data && chown openclaw:openclaw /data \
  && mkdir -p /home/linuxbrew/.linuxbrew && chown -R openclaw:openclaw /home/linuxbrew

# 8. Install Homebrew (as non-root user)
USER openclaw
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Setup Homebrew Environment
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"

# 9. Runtime Environment Configuration
ENV PORT=8080
# Pointing to the globally installed version from Step 5
ENV OPENCLAW_ENTRY=/usr/local/lib/node_modules/openclaw/dist/entry.js

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:8080/setup/healthz || exit 1

USER root
ENTRYPOINT ["./entrypoint.sh"]
