FROM mcr.microsoft.com/devcontainers/python:1-3.11-bullseye

# Remove the problematic Yarn repository that has expired GPG keys
RUN rm -f /etc/apt/sources.list.d/yarn.list 2>/dev/null || true
