# syntax=docker/dockerfile:1

# Multi-stage Dockerfile for building Whisparr from source
# Stage 1: Build stage - compiles Whisparr from source
# Stage 2: Runtime stage - minimal image with just the built application

#===============================================================================
# STAGE 1: BUILD (using Debian for better compatibility)
#===============================================================================
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    nodejs \
    npm \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Copy the source code
COPY . .

# Increase file descriptor limits and build the backend for linux-musl-x64 (Alpine)
# Using --disable-parallel to avoid "too many open files" error
RUN echo "Building Whisparr backend..." && \
    dotnet restore src/Whisparr.sln --disable-parallel && \
    dotnet msbuild -restore src/Whisparr.sln \
        -p:SelfContained=True \
        -p:Configuration=Release \
        -p:Platform=Posix \
        -p:RuntimeIdentifiers=linux-musl-x64 \
        -t:PublishAllRids \
        -maxcpucount:1

# Build the frontend
RUN echo "Building Whisparr frontend..." && \
    yarn install --frozen-lockfile --network-timeout 120000 && \
    yarn run build --env production

# Package the application
RUN echo "Packaging Whisparr..." && \
    mkdir -p /app/whisparr && \
    cp -r _output/net8.0/linux-musl-x64/publish/* /app/whisparr/ && \
    cp -r _output/UI /app/whisparr/ && \
    cp LICENSE /app/whisparr/ && \
    rm -f /app/whisparr/Whisparr.Windows.* && \
    rm -rf /app/whisparr/Whisparr.Update

#===============================================================================
# STAGE 2: RUNTIME
#===============================================================================
FROM mcr.microsoft.com/dotnet/runtime-deps:8.0-alpine

# Labels
LABEL maintainer="custom-build"
LABEL org.opencontainers.image.description="Whisparr - Built from source with custom fixes"

# Install runtime dependencies
RUN apk add --no-cache \
    icu-libs \
    sqlite-libs \
    tzdata

# Environment settings
ENV XDG_CONFIG_HOME="/config/xdg" \
    WHISPARR_BRANCH="custom" \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# Create user and directories
RUN addgroup -g 1000 whisparr && \
    adduser -u 1000 -G whisparr -h /config -D whisparr && \
    mkdir -p /app/whisparr /config && \
    chown -R whisparr:whisparr /app /config

# Copy built application from builder stage
COPY --from=builder --chown=whisparr:whisparr /app/whisparr /app/whisparr

# Create package info
RUN echo -e "UpdateMethod=docker\nBranch=custom\nPackageVersion=custom-build\nPackageAuthor=local" > /app/whisparr/package_info

# Switch to non-root user
USER whisparr

WORKDIR /app/whisparr

# Expose port
EXPOSE 6969

# Volume for config
VOLUME /config

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:6969/ping || exit 1

# Entry point
ENTRYPOINT ["./Whisparr", "-nobrowser", "-data=/config"]
