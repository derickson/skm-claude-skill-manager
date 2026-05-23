#!/usr/bin/env bash
# Shared helpers for hermes-dispatch scripts.
# Sourced by sibling scripts; not meant to be executed directly.

# Host alias to use for SSH. Override with HERMES_SSH_HOST.
HERMES_SSH_HOST="${HERMES_SSH_HOST:-hermes}"

# SSH options applied to every call:
#   BatchMode=yes  → never prompt; fail fast if key auth doesn't work.
#   ConnectTimeout → don't hang forever on a dead host.
HERMES_SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)

# hermes_ssh <remote-command-string>
# Run a command on the hermes host. The argument is passed as a single
# shell-string to ssh (so the caller is responsible for quoting).
hermes_ssh() {
  ssh "${HERMES_SSH_OPTS[@]}" "$HERMES_SSH_HOST" "$1"
}

# hermes_sha256 <string>
# Stable hash used for idempotency keys. macOS doesn't ship sha256sum, so
# prefer shasum -a 256 and fall back to openssl.
hermes_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  else
    printf '%s' "$1" | openssl dgst -sha256 | awk '{print $NF}'
  fi
}
