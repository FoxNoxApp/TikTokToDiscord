# Dockerfile

# Base for dependency install
FROM oven/bun:1 AS base
WORKDIR /usr/src/app

# Install dependencies into temp directory for build caching
FROM base AS install
RUN mkdir -p /temp/dev
COPY package.json bun.lock /temp/dev/
RUN cd /temp/dev && bun install --frozen-lockfile

# Production deps cache
RUN mkdir -p /temp/prod
COPY package.json bun.lock /temp/prod/
RUN cd /temp/prod && bun install --frozen-lockfile --production

# Prepare prerelease with dev node_modules and source
FROM base AS prerelease
COPY --from=install /temp/dev/node_modules node_modules
COPY . .

# Final runtime image
FROM oven/bun:1 AS release
WORKDIR /usr/src/app

# Install OS dependencies required by Chrome (Debian-based bun image)
USER root
RUN apt-get update && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libexpat1 \
    libgbm1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnss3 \
    libnspr4 \
    libpango-1.0-0 \
    libx11-6 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libxrender1 \
    xdg-utils \
  && rm -rf /var/lib/apt/lists/*

# Copy production deps and app
COPY --from=install /temp/prod/node_modules node_modules
COPY --from=prerelease /usr/src/app ./

# Create logs dir and set ownership
RUN mkdir -p /usr/src/app/log && chown -R bun:bun /usr/src/app

# Use bun user so Puppeteer installs Chrome to /home/bun/.cache/puppeteer
USER bun

# Ensure Puppeteer manages Chrome in the bun user's cache
ENV PUPPETEER_PRODUCT=chrome
ENV PUPPETEER_CACHE_DIR=/home/bun/.cache/puppeteer

# Install Chrome managed by Puppeteer (stable channel)
RUN bunx puppeteer browsers install chrome@stable

# Helpful env to avoid sandbox/dev-shm issues in containers (we pass flags in code too)
ENV PUPPETEER_SKIP_DOWNLOAD=false

# Start the app
ENTRYPOINT [ "bun", "run", "index.js" ]