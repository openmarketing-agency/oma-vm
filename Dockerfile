ARG OMA_AGENT_IMAGE
FROM docker.io/oven/bun:1.4.4 AS bun

FROM ${OMA_AGENT_IMAGE} AS agent
USER root

FROM agent AS playbook-build
COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun
WORKDIR /opt/oma
COPY oma/runtime/installer/package.json oma/runtime/installer/bun.lock ./installer/
RUN cd installer && bun install --frozen-lockfile --production
COPY oma/runtime/installer/src ./installer/src
COPY oma/runtime/installer/schemas ./installer/schemas
COPY playbooks ./playbooks
COPY skills ./skills
COPY prepare-seed.sh oma-soul.md ./
RUN install -d -o hermes -g hermes -m 0700 /opt/oma/seed
USER hermes
RUN --network=none bash /opt/oma/prepare-seed.sh

FROM agent
# The base's /usr/bin/tini is a dispatcher to s6. Use the Debian init binary.
RUN apt-get update && apt-get install -y --no-install-recommends \
        tini docker.io docker-cli docker-compose iptables kmod \
    && usermod -aG docker hermes \
    && rm -rf /var/lib/apt/lists/*
COPY omactl/bin/omactl /usr/local/bin/omactl
COPY omactl/catalog /opt/omactl/catalog
COPY --from=playbook-build /opt/oma/playbooks /opt/oma/playbooks
COPY --from=playbook-build /opt/oma/skills /opt/oma/skills
COPY --from=playbook-build --chown=hermes:hermes /opt/oma/seed /opt/oma/seed
COPY bootstrap.py start.sh /opt/oma/

ARG OMA_AGENT_IMAGE
ARG OMACTL_TAG
ARG OMA_SOURCE_COMMIT
ARG OMA_VM_VERSION
LABEL org.opencontainers.image.source="https://github.com/openmarketing-agency/oma-vm" \
      org.opencontainers.image.version="$OMA_VM_VERSION" \
      org.opencontainers.image.base.name="$OMA_AGENT_IMAGE" \
      agency.openmarketing.omactl.version="$OMACTL_TAG" \
      agency.openmarketing.playbooks.revision="$OMA_SOURCE_COMMIT"
ENV HOME=/opt/data HERMES_HOME=/opt/data HERMES_DIR=/opt/hermes PYTHONPATH=/opt/hermes \
    GATEWAY_MULTIPLEX_PROFILES=true HERMES_DASHBOARD=1 \
    HERMES_DASHBOARD_HOST=0.0.0.0 HERMES_DASHBOARD_PORT=9119
WORKDIR /opt/oma
EXPOSE 8642 9119
ENTRYPOINT ["/usr/bin/tini", "-s", "-g", "--", "/bin/bash", "/opt/oma/start.sh"]
CMD []
