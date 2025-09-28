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

# Configure Redis for queue mode
if [ -n "${REDIS_URL+x}" ]; then
  echo "Redis URL found: $REDIS_URL"
  
  # Parse Redis URL to extract host and port (required by n8n)
  PREFIX="REDIS_" parse_url "$REDIS_URL"
  REDIS_HOST="$(echo $REDIS_HOSTPORT | sed -e 's,:.*,,g')"
  REDIS_PORT="$(echo $REDIS_HOSTPORT | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
  
  # Set Redis connection variables (n8n expects these specific variables)
  export QUEUE_BULL_REDIS_HOST="$REDIS_HOST"
  export QUEUE_BULL_REDIS_PORT="$REDIS_PORT"
  export QUEUE_BULL_REDIS_PASSWORD="$REDIS_PASSWORD"
  export QUEUE_BULL_REDIS_URL="${REDIS_URL}"
  
  echo "Parsed Redis connection:"
  echo "  Host: $REDIS_HOST"
  echo "  Port: $REDIS_PORT"
  echo "  Password: [REDACTED]"
  
  # Critical ioredis SSL configuration for Heroku Redis
  export QUEUE_BULL_REDIS_TLS="true"
  export QUEUE_BULL_REDIS_TLS_REJECT_UNAUTHORIZED="false"
  
  # Additional ioredis-specific SSL settings for Docker compatibility
  export QUEUE_BULL_REDIS_TLS_CHECK_SERVER_IDENTITY="false"
  export QUEUE_BULL_REDIS_TLS_SERVERNAME=""
  export QUEUE_BULL_REDIS_TLS_CA=""
  export QUEUE_BULL_REDIS_TLS_CERT=""
  export QUEUE_BULL_REDIS_TLS_KEY=""
  
  # Heroku-recommended ioredis configuration for n8n
  export QUEUE_BULL_REDIS_CONNECT_TIMEOUT="60000"
  export QUEUE_BULL_REDIS_COMMAND_TIMEOUT="60000"
  export QUEUE_BULL_REDIS_LAZY_CONNECT="true"
  export QUEUE_BULL_REDIS_MAX_RETRIES_PER_REQUEST="3"
  export QUEUE_BULL_REDIS_RETRY_DELAY_ON_FAILURE="2000"
  
  # Core n8n Redis configuration following Heroku best practices
  export N8N_REDIS_URL="${REDIS_URL}"
  export N8N_REDIS_SSL="true"
  export N8N_REDIS_TLS_REJECT_UNAUTHORIZED="false"
  
  # Ensure queue mode is enabled with proper Redis URL
  export EXECUTIONS_MODE="queue"
  export QUEUE_BULL_REDIS_URL="${REDIS_URL}"
  
  # Additional debugging and connection settings
  echo "DEBUG: Final Redis configuration:"
  echo "  REDIS_URL: ${REDIS_URL}"
  echo "  QUEUE_BULL_REDIS_HOST: ${QUEUE_BULL_REDIS_HOST}"
  echo "  QUEUE_BULL_REDIS_PORT: ${QUEUE_BULL_REDIS_PORT}"
  echo "  QUEUE_BULL_REDIS_URL: ${QUEUE_BULL_REDIS_URL}"
  echo "  N8N_REDIS_URL: ${N8N_REDIS_URL}"
  echo "  EXECUTIONS_MODE: ${EXECUTIONS_MODE}"
  
  echo "Redis SSL configuration applied for ioredis compatibility"
else
  echo "REDIS_URL not set, queue mode may fail."
fi

# Debug: Show all arguments and environment
echo "DEBUG: Script arguments: \$0='$0' \$1='$1' \$2='$2' \$#='$#'"
echo "DEBUG: All arguments: $@"
echo "DEBUG: DYNO_TYPE='$DYNO_TYPE'"
echo "DEBUG: DYNO='$DYNO'"

# Determine command based on DYNO environment variable (most reliable on Heroku)
if echo "$DYNO" | grep -q "worker"; then
  CMD="worker"
  echo "Command determined from DYNO name: '$CMD' (DYNO=$DYNO)"
elif echo "$DYNO" | grep -q "web"; then
  CMD="start"
  echo "Command determined from DYNO name: '$CMD' (DYNO=$DYNO)"
elif [ "$DYNO_TYPE" = "worker" ]; then
  CMD="worker"
  echo "Command determined from DYNO_TYPE: '$CMD'"
elif [ -n "$1" ] && [ "$1" != "/bin/sh" ] && [ "$1" != "-c" ]; then
  CMD="$1"
  echo "Command received from argument: '$CMD'"
else
  # Default to 'start' for web dyno
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