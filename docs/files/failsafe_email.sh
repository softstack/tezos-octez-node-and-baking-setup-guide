#!/bin/bash

LOG_FILE="/var/log/tezos-monitor.log"
POSTMARK_API_TOKEN=<POSTMARK_API_TOKEN>

log() {
    local message="$(date): $1"
    echo "$message"
    if ! echo "$message" >> "$LOG_FILE" 2>/dev/null; then
        echo "Failed to write to log file: $LOG_FILE" >&2
        echo "Ensure the script has write permissions to this file and its parent directory" >&2
    fi
}

send_email() {
    local subject="$1"
    local body="$2"
    
    response=$(curl -s -X POST "https://api.postmarkapp.com/email" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -H "X-Postmark-Server-Token: $POSTMARK_API_TOKEN" \
      -d '{
        "From": "<SENDER_EMAIL>",
        "To": "<TO_EMAIL>",
        "Subject": "'"$subject"'",
        "TextBody": "'"$body"'",
        "MessageStream": "outbound"
      }')
      echo "Postmark API response: $response"
}

send_email "Test Subject" "This is a test email body"

# Test log file writability at the start
if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "Cannot write to log file: $LOG_FILE" >&2
    echo "Please ensure this script has the necessary permissions" >&2
    echo "You might need to run: sudo touch $LOG_FILE && sudo chmod 666 $LOG_FILE" >&2
    exit 1
fi

log "Tezos monitor script started"

is_node_bootstrapped() {
    if octez-client rpc get /chains/main/is_bootstrapped | grep -q "true"; then
        return 0
    else
        return 1
    fi
}

is_baker_running() {
    local status=$(systemctl is-active octez-baker.service)
    local full_status=$(systemctl status octez-baker.service | grep 'Active:' | sed -e 's/^[[:space:]]*//')

    log "Baker full status: $full_status"

    if [ "$status" = "active" ]; then
        log "Baker is running"
        return 0
    else
        log "Baker is not running"
        return 1
    fi
}

restart_node() {
    log "Restarting Tezos node"
    sudo systemctl restart octez-node.service
    sleep 60  # Wait for node to start
}

restart_baker() {
    log "Restarting Tezos baker"
    sudo systemctl restart octez-baker.service
}

# Main loop
while true; do
    if ! is_node_bootstrapped; then
        log "Node is not bootstrapped"
        send_email "Tezos Node Not Bootstrapped" "The Tezos node is not bootstrapped. Attempting to restart."
        restart_node

        # Wait for node to bootstrap (max 30 minutes)
        for i in {1..30}; do
            if is_node_bootstrapped; then
                log "Node is now bootstrapped"
                send_email "Tezos Node Bootstrapped" "The Tezos node has successfully bootstrapped after restart."
                break
            fi
            sleep 60
        done

        if ! is_node_bootstrapped; then
            log "Node failed to bootstrap after 30 minutes"
            send_email "Tezos Node Bootstrap Failed" "The Tezos node failed to bootstrap after 30 minutes of attempts."
        fi
    else
        log "Node is bootstrapped and running"
        send_email "Test" "Node is running"

        # Check baker status
        if is_baker_running; then
            log "Baker check completed"
            send_email "Test" "Baker is running"

        else
            log "Baker is not running. Attempting to restart."
            send_email "Tezos Baker Not Running" "The Tezos baker is not running. Attempting to restart."
            restart_baker
            sleep 30  # Wait for baker to start
            if is_baker_running; then
                log "Baker successfully restarted"
                send_email "Tezos Baker Restarted" "The Tezos baker has been successfully restarted."
            else
                log "Failed to restart baker"
                send_email "Tezos Baker Restart Failed" "Failed to restart the Tezos baker after attempt."
            fi
        fi
    fi

    log "Sleeping for 60 minutes before next check"
    sleep 3600 
done