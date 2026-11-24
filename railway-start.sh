#!/bin/sh
# Railway start script for Poznote.
#  1. Listen on Railway's PORT.
#  2. Size php-fpm workers, the PHP memory limit and nginx workers to the
#     service's memory and CPU limits (Railway hosts show 48 CPUs).
#  3. Run upstream's init script (data folders, permissions, service token).
#  4. On the first boot only, replace upstream's default admin
#     (admin_change_me / admin) with POZNOTE_ADMIN_USERNAME and
#     POZNOTE_ADMIN_PASSWORD, before the web server accepts a request.
#  5. Run supervisord (nginx, php-fpm, workers) and exit non-zero when it or
#     one of its core programs stops, so Railway's ON_FAILURE policy restarts it.
set -eu

export POZNOTE_LISTEN_PORT="${PORT:-8080}"

# Memory available to this service (cgroup v2, then v1), in MB.
mem_mb=""
if [ -r /sys/fs/cgroup/memory.max ]; then
    raw="$(cat /sys/fs/cgroup/memory.max)"
    [ "$raw" != "max" ] && mem_mb=$((raw / 1048576))
elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    raw="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)"
    [ "$raw" -lt 1099511627776 ] && mem_mb=$((raw / 1048576))
fi
if [ -n "$mem_mb" ] && [ "$mem_mb" -gt 0 ]; then
    if [ -z "${POZNOTE_PHP_FPM_MAX_CHILDREN:-}" ]; then
        children=$(( (mem_mb - 150) / 60 ))
        [ "$children" -lt 3 ] && children=3
        [ "$children" -gt 10 ] && children=10
        export POZNOTE_PHP_FPM_MAX_CHILDREN="$children"
    fi
    if [ -z "${POZNOTE_PHP_MEMORY_LIMIT:-}" ]; then
        php_mem=$(( mem_mb / 3 ))
        [ "$php_mem" -lt 128 ] && php_mem=128
        [ "$php_mem" -gt 512 ] && php_mem=512
        export POZNOTE_PHP_MEMORY_LIMIT="$php_mem"
    fi
    echo "railway: ${mem_mb} MB memory, php-fpm max_children=${POZNOTE_PHP_FPM_MAX_CHILDREN:-default}, memory_limit=${POZNOTE_PHP_MEMORY_LIMIT:-default}M"
fi

# nginx's "worker_processes auto" starts one worker per host CPU (48 on
# Railway hosts, whatever the service's limit). Use the cgroup CPU quota.
cpus=""
if [ -r /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max || true
    if [ "${quota:-max}" != "max" ] && [ "${period:-0}" -gt 0 ]; then
        cpus=$(( (quota + period - 1) / period ))
    fi
fi
[ -z "$cpus" ] && cpus="$(nproc 2>/dev/null || echo 2)"
[ "$cpus" -lt 1 ] && cpus=1
[ "$cpus" -gt 4 ] && cpus=4
NGINX_WORKERS="${POZNOTE_NGINX_WORKERS:-$cpus}"
sed -i "s/^worker_processes .*;/worker_processes ${NGINX_WORKERS};/" /etc/nginx/nginx.conf
grep -q "^worker_processes ${NGINX_WORKERS};" /etc/nginx/nginx.conf || { echo "ERROR: could not set nginx worker_processes" >&2; exit 1; }
echo "railway: nginx worker_processes=${NGINX_WORKERS}"

/usr/local/bin/init.sh

if [ -z "${POZNOTE_ADMIN_PASSWORD:-}" ]; then
    echo "ERROR: POZNOTE_ADMIN_PASSWORD is empty. Set it (the template generates one) and redeploy." >&2
    exit 1
fi
# Run as the PHP user so master.db stays owned by www-data.
su -p -s /bin/sh www-data -c "php /usr/local/lib/railway-bootstrap-admin.php"

SUPERVISOR_CONF=/etc/supervisor/conf.d/supervisord.conf
/usr/bin/supervisord -c "$SUPERVISOR_CONF" &
sup_pid=$!

stop() {
    kill -TERM "$sup_pid" 2>/dev/null || true
    wait "$sup_pid" 2>/dev/null || true
    exit 0
}
trap stop TERM INT

# Upstream's supervisord stays up (and exits 0) when nginx or php-fpm dies.
# Poll instead of `wait -n` (BusyBox), and fail loudly so Railway restarts us.
sleep 5
while :; do
    if ! kill -0 "$sup_pid" 2>/dev/null; then
        echo "railway: supervisord exited, stopping the container" >&2
        exit 1
    fi
    bad="$(supervisorctl -c "$SUPERVISOR_CONF" status nginx php-fpm 2>/dev/null | grep -E 'FATAL|EXITED|BACKOFF|STOPPED' || true)"
    if [ -n "$bad" ]; then
        echo "railway: core process down: $bad" >&2
        kill -TERM "$sup_pid" 2>/dev/null || true
        exit 1
    fi
    sleep 10 &
    wait $! || true
done
