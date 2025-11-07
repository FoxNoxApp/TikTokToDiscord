# Dockerfile (simplified, single-stage runtime)

FROM oven/bun:1 AS release
WORKDIR /usr/src/app

# Root only to install OS libs Chrome needs
USER root
RUN apt-get update && apt-get install -y \
    ca-certificates fonts-liberation libasound2 libatk1.0-0 libatk-bridge2.0-0 \
    libc6 libcairo2 libcups2 libdbus-1-3 libdrm2 libexpat1 libgbm1 libglib2.0-0 \
    libgtk-3-0 libnss3 libnspr4 libpango-1.0-0 libx11-6 libx11-xcb1 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 libxrandr2 libxrender1 xdg-utils \
  && rm -rf /var/lib/apt/lists/*

# Switch to bun for app deps and browser install (ensures cache under /home/bun)
USER bun

# Copy app files and install deps (puppeteer)
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production
COPY . .

# Install Chrome managed by Puppeteer into bun user's cache
ENV PUPPETEER_PRODUCT=chrome
ENV PUPPETEER_CACHE_DIR=/home/bun/.cache/puppeteer
RUN bunx puppeteer browsers install chrome@stable

# Verify Chrome exists; fail build if not
RUN set -eux; \
  CHROME_PATH=$(find /home/bun/.cache/puppeteer -type f -path "*chrome/linux-*/chrome-linux64/chrome" | head -n1); \
  echo "Resolved CHROME_PATH=${CHROME_PATH}"; \
  test -x "$CHROME_PATH"

ENTRYPOINT [ "bun", "run", "index.js" ]
