# Use Bun base image
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

# Final image
FROM oven/bun:1 AS release
WORKDIR /usr/src/app

# Copy production deps and app
COPY --from=install /temp/prod/node_modules node_modules
COPY --from=prerelease /usr/src/app ./

# Create logs dir and set ownership
RUN mkdir -p /usr/src/app/log && chown -R bun:bun /usr/src/app

# Switch to bun user BEFORE installing browser so cache goes to /home/bun/.cache/puppeteer
USER bun

# Ensure puppeteer installs Chrome into bun user's cache
# If you're using puppeteer-core, add PUPPETEER_PRODUCT=chrome and use bunx puppeteer
ENV PUPPETEER_PRODUCT=chrome
RUN bunx puppeteer browsers install chrome@stable

# Helpful env to avoid sandbox issues in containers
ENV PUPPETEER_SKIP_DOWNLOAD=false

# Run the app
ENTRYPOINT [ "bun", "run", "index.js" ]
