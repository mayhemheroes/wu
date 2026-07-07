# syntax=docker/dockerfile:1.7
#
# wu commit-image Dockerfile — Rust compiler fuzzed via an in-memory libFuzzer target.
# Builds ON TOP of ghcr.io/mayhemheroes/base, adding a pinned Rust nightly toolchain + cargo-fuzz.
#
# Build (from repo root, on the `mayhem` branch):
#   DOCKER_BUILDKIT=1 docker build -f mayhem/Dockerfile \
#       --build-arg COMMIT=$(git rev-parse HEAD) -t wu-commit:test .

FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
ARG SOURCE_DATE_EPOCH
# Base exports SANITIZER_FLAGS (ASan+UBSan, halting); Rust uses RUSTFLAGS -Zsanitizer=address instead.
ARG SANITIZER_FLAGS
ARG MAYHEM_JOBS=

ARG RUST_TOOLCHAIN=nightly-2025-01-15
ARG CARGO_FUZZ_VERSION=0.12.0

ENV RUSTUP_HOME=/opt/toolchains/rust/rustup \
    CARGO_HOME=/opt/toolchains/rust/cargo \
    PATH=/opt/toolchains/rust/cargo/bin:${PATH} \
    WU_HOME=/tmp/wu-home

USER root
RUN set -eux; \
    install -d /opt/toolchains/rust /tmp/wu-home; \
    apt-get update && apt-get install -y --no-install-recommends \
        libssl-dev libgit2-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --profile minimal --default-toolchain "$RUST_TOOLCHAIN"; \
    rustup component add rust-src --toolchain "$RUST_TOOLCHAIN"; \
    cargo install cargo-fuzz --version "$CARGO_FUZZ_VERSION" --locked; \
    chown -R 2000:2000 /opt/toolchains/rust /tmp/wu-home; \
    rustc --version; cargo --version; cargo fuzz --version
USER mayhem

WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
