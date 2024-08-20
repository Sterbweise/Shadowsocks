# Use Rust Alpine image as the builder stage
FROM --platform=$BUILDPLATFORM rust:alpine3.20 AS builder

# Set maintainer label
LABEL maintainer="Sterbweise <contact@sterbweise.dev>"

# Set working directory
WORKDIR /opt/shadowsocks-rust

# Install necessary dependencies
RUN apk add --no-cache git curl wget build-base libressl-dev linux-headers jq

# Define environment variable to get the latest v2ray-plugin version
ENV GET_LATEST_VERSION="curl -s https://api.github.com/repos/shadowsocks/v2ray-plugin/releases/latest | jq -r .tag_name"

# Define URLs for v2ray-plugin and shadowsocks-rust
ENV V2RAY_URL="https://github.com/shadowsocks/v2ray-plugin/releases/download/\$(${GET_LATEST_VERSION})/v2ray-plugin-linux-amd64-\$(${GET_LATEST_VERSION}).tar.gz"
ENV SHADOWSOCKS_URL=https://github.com/shadowsocks/shadowsocks-rust.git

# Clone shadowsocks-rust repository
RUN git clone ${SHADOWSOCKS_URL} /tmp/shadowsocks-rust && \
    mv /tmp/shadowsocks-rust/* /opt/shadowsocks-rust/ && \
    rm -rf /tmp/shadowsocks-rust

# Download and extract v2ray-plugin
RUN wget $(eval echo $V2RAY_URL) && \
    tar -xzf v2ray-plugin-linux-amd64-*.tar.gz && \
    mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin && \
    rm v2ray-plugin-linux-amd64-*.tar.gz

# Build shadowsocks-rust with native CPU optimizations
RUN export RUSTFLAGS="-C target-cpu=native" && \
    cargo build --release && \
    strip target/release/ssserver


# Start a new stage for the final image
FROM alpine:3.20

# Copy built binaries from the builder stage
COPY --from=builder /opt/shadowsocks-rust/target/release/ssserver /usr/local/bin/
COPY --from=builder /usr/local/bin/v2ray-plugin /usr/local/bin/

# Set the default command to run shadowsocks server
CMD ["ssserver", "-c", "/opt/shadowsocks-rust/config/config.json"]