# Poznote for Railway: the official image, pinned by version and digest.
# Upstream: https://github.com/timothepoznanski/Poznote (MIT)
FROM ghcr.io/timothepoznanski/poznote:6.158.2@sha256:a3dbe7576f2ac29318a6bfca5adff380aec3a501e201059e1f95c15bdef1e494

# Upstream's compose file sets this; the data directory is the Railway volume.
ENV SQLITE_DATABASE=/var/www/html/data/database/poznote.db

COPY railway-start.sh /usr/local/bin/railway-start.sh
COPY railway-bootstrap-admin.php /usr/local/lib/railway-bootstrap-admin.php
RUN chmod 755 /usr/local/bin/railway-start.sh \
    && chmod 644 /usr/local/lib/railway-bootstrap-admin.php

EXPOSE 8080
CMD ["/usr/local/bin/railway-start.sh"]
