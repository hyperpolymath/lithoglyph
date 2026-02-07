# SPDX-License-Identifier: PMPL-1.0-or-later
# Lithoglyph - Immutable Content-Addressable Database
# Multi-stage build for optimized production image

FROM docker.io/library/alpine:3.21 AS builder

# Install build dependencies
RUN apk add --no-cache \
    curl \
    xz \
    tar

# Install Zig 0.15.2
RUN curl -L https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz | tar -xJ -C /usr/local && \
    ln -s /usr/local/zig-linux-x86_64-0.15.2/zig /usr/local/bin/zig

WORKDIR /build

# Copy source files
COPY core-zig/ /build/core-zig/
COPY demo-server.zig /build/

# Build libbridge.so
WORKDIR /build/core-zig
RUN zig build-lib src/bridge.zig -dynamic -lc -O ReleaseFast

# Build demo-server
WORKDIR /build
RUN zig build-exe demo-server.zig -lc -O ReleaseFast

# Production stage
FROM docker.io/library/alpine:3.21

# Install runtime dependencies
RUN apk add --no-cache \
    libgcc \
    curl \
    ca-certificates

# Create non-root user
RUN addgroup -g 1000 lithoglyph && \
    adduser -D -u 1000 -G lithoglyph lithoglyph

# Create data directory
RUN mkdir -p /data/lithoglyph && \
    chown -R lithoglyph:lithoglyph /data/lithoglyph

WORKDIR /app

# Copy built binaries from builder
COPY --from=builder /build/demo-server /app/
COPY --from=builder /build/core-zig/libbridge.so /app/

# Set ownership
RUN chown -R lithoglyph:lithoglyph /app

# Switch to non-root user
USER lithoglyph

# Set library path
ENV LD_LIBRARY_PATH=/app

# Expose API port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run server
CMD ["/app/demo-server"]
