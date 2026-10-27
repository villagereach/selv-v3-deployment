ARG ALLOY_VERSION=v1.12.2
FROM grafana/alloy:${ALLOY_VERSION}
# Loaded as one config from the directory: the package's config.alloy
# (vendored, see PACKAGE_VERSION) plus the SELV additions.
COPY config.alloy selv.alloy /etc/alloy/
