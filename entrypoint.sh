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
  echo "Queue Bull Redis URL: ${QUEUE_BULL_REDIS_URL:-$REDIS_URL}"
  
  # Critical ioredis SSL configuration for Heroku Redis
  export QUEUE_BULL_REDIS_TLS="true"
  export QUEUE_BULL_REDIS_TLS_REJECT_UNAUTHORIZED="false"
  
  # Additional ioredis-specific SSL settings
  export QUEUE_BULL_REDIS_TLS_CHECK_SERVER_IDENTITY="false"
  export QUEUE_BULL_REDIS_TLS_SERVERNAME=""
  export QUEUE_BULL_REDIS_TLS_CA=""
  export QUEUE_BULL_REDIS_TLS_CERT=""
  export QUEUE_BULL_REDIS_TLS_KEY=""
  
  # Connection timeout settings
  export QUEUE_BULL_REDIS_CONNECT_TIMEOUT="30000"
  export QUEUE_BULL_REDIS_COMMAND_TIMEOUT="30000"
  export QUEUE_BULL_REDIS_LAZY_CONNECT="true"
  
  echo "Redis SSL configuration applied for ioredis compatibility"
else
  echo "REDIS_URL not set, queue mode may fail."
fi

# Debug: Show all arguments and environment
echo "DEBUG: Script arguments: \$0='$0' \$1='$1' \$2='$2' \$#='$#'"
echo "DEBUG: All arguments: $@"
echo "DEBUG: DYNO_TYPE='$DYNO_TYPE'"
echo "DEBUG: DYNO='$DYNO'"

# Determine command based on environment variables or arguments
if [ -n "$1" ]; then
  CMD="$1"
  echo "Command received from argument: '$CMD'"
elif [ "$DYNO_TYPE" = "worker" ]; then
  CMD="worker"
  echo "Command determined from DYNO_TYPE: '$CMD'"
elif echo "$DYNO" | grep -q "worker"; then
  CMD="worker"
  echo "Command determined from DYNO name: '$CMD'"
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