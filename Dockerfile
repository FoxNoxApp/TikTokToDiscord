# filename: Dockerfile

FROM oven/bun:1 AS release
WORKDIR /usr/src/app

# 1) Install OS dependencies Chrome needs (root)
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

# Ensure bun user owns the workspace to avoid EACCES
RUN mkdir -p /usr/src/app/log && chown -R bun:bun /usr/src/app

# 2) Switch to bun for app deps and browser install
USER bun

# Copy app manifest and install deps
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

# Copy the rest of the app
COPY . .

# 3) Install Chrome managed by Puppeteer into bun user's cache
ENV PUPPETEER_PRODUCT=chrome
ENV PUPPETEER_CACHE_DIR=/home/bun/.cache/puppeteer
RUN bunx puppeteer browsers install chrome@stable

# 4) Resolve Chrome path and set envs for runtime
# Also set a writable log path
ENV LOG_PATH=/usr/src/app/log/posts.json
RUN set -eux; \
  CHROME_PATH=$(find /home/bun/.cache/puppeteer -type f -path "*chrome/linux-*/chrome-linux64/chrome" | head -n1); \
  echo "Resolved CHROME_PATH=${CHROME_PATH}"; \
  test -x "$CHROME_PATH"; \
  printf "%s\n" "CHROME_PATH=${CHROME_PATH}" >> /home/bun/.chromepath

# Load CHROME_PATH at runtime
ENV CHROME_PATH_FILE=/home/bun/.chromepath

# 5) Default command
ENTRYPOINT [ "bun", "run", "index.js" ]