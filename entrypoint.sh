#!/bin/sh

# Check if port variable is set or go with default
if [ -z "${PORT+x}" ]; then
  echo "PORT variable not defined, leaving n8n to default port."
else
  export N8N_PORT="$PORT"
  echo "n8n will start on '$PORT'"
fi

# Regex function to parse URLs
parse_url() {
  eval $(echo "$1" | sed -e "s#^\(\(.*\)://\)\?\(\([^:@]*\)\(:\(.*\)\)\?@\)\?\([^/?]*\)\(/\(.*\)\)\?#${PREFIX:-URL_}SCHEME='\2' ${PREFIX:-URL_}USER='\4' ${PREFIX:-URL_}PASSWORD='\6' ${PREFIX:-URL_}HOSTPORT='\7' ${PREFIX:-URL_}DATABASE='\9'#")
}

# Parse DATABASE_URL for Postgres
PREFIX="N8N_DB_" parse_url "$DATABASE_URL"
echo "$N8N_DB_SCHEME://$N8N_DB_USER:$N8N_DB_PASSWORD@$N8N_DB_HOSTPORT/$N8N_DB_DATABASE"
# Separate host and port
N8N_DB_HOST="$(echo $N8N_DB_HOSTPORT | sed -e 's,:.*,,g')"
N8N_DB_PORT="$(echo $N8N_DB_HOSTPORT | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"

# Export Postgres env vars
export DB_TYPE=postgresdb
export DB_POSTGRESDB_HOST=$N8N_DB_HOST
export DB_POSTGRESDB_PORT=$N8N_DB_PORT
export DB_POSTGRESDB_DATABASE=$N8N_DB_DATABASE
export DB_POSTGRESDB_USER=$N8N_DB_USER
export DB_POSTGRESDB_PASSWORD=$N8N_DB_PASSWORD

# Parse REDIS_URL if set
if [ -n "${REDIS_URL+x}" ]; then
  PREFIX="N8N_REDIS_" parse_url "$REDIS_URL"
  export QUEUE_BULL_REDIS_URL="$REDIS_URL"
  # Set Redis SSL/TLS configuration for queue mode
  export QUEUE_BULL_REDIS_TLS_REJECT_UNAUTHORIZED="${N8N_REDIS_TLS_REJECT_UNAUTHORIZED:-false}"
  echo "Redis configured at $REDIS_URL"
else
  echo "REDIS_URL not set, queue mode may fail."
fi

# Determine command based on process type or argument
if [ -n "$1" ]; then
  CMD="$1"
else
  # Default to 'start' for web dyno if no argument
  CMD="start"
  echo "No command specified, defaulting to 'start' for web process."
fi

case "$CMD" in
  start)
    echo "Starting n8n web process"
    n8n start
    ;;
  worker)
    echo "Starting n8n worker process"
    n8n worker
    ;;
  *)
    echo "Unknown command: '$CMD'. Use 'start' or 'worker'."
    exit 1
    ;;
esac