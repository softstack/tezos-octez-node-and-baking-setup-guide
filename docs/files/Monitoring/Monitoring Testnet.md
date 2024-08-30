This is the monitoring setup on testnet

## Monitoring
Monitoring Tools Overview

	1.	Netdata: Provides real-time performance monitoring and alerting. It’s easy to set up and offers detailed visualizations of hardware metrics.
	2.	Prometheus: Collects and stores time-series data from Netdata, and can be queried by Grafana.
	3.	Grafana: Used for creating dashboards and visualizing data collected by Prometheus or other data sources.

Considerations for using Cloudwatch?

Using CloudWatch:

Pros:

	•	Centralized monitoring and logging.
	•	Integration with other AWS services.
	•	Scalable and managed by AWS.

Cons:
	•	Cost: CloudWatch charges based on data ingested, stored, and retrieved.
	•	Potential additional cost for high-volume data and metrics.

Storing on EC2 Machine:

Pros:

	•	Cost-effective: Avoids CloudWatch costs.
	•	Complete control over data storage and access.

Cons: 
	•	Management overhead: Need to handle log rotation, storage limits, and backups.
	•	Less integration with AWS monitoring tools.

For longterm logging and to avoid Cloudwatch to save costs, store logs on ec2 machine with logrotate

### Setup netdata

1. Install

wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && sh /tmp/netdata-kickstart.sh

2. Add shell script for collection. Copy code from [Step 2 in this tutorial](https://opentezos.com/node-baking/deploy-a-node/monitor-a-node/)

3. Add metrics to node run command (depending on your installation either in CLI, docker or in system service )

    octez-node run --rpc-addr 127.0.0.1:8732 --log-output tezos.log --metrics-addr=:9091

4. Check if netdata is running
    sudo systemctl status netdata

### Add custom metrics
0. Install

    sudo apt-get install jq

1. Add custom script

    sudo nano /usr/libexec/netdata/charts.d/octez.sh

2. Add this

```
#!/bin/bash

octez_update_every=10
octez_priority=90000

octez_check() {
    which octez-client >/dev/null 2>&1 || return 1
    return 0
}

octez_get() {
    local data=$(curl -s http://localhost:8732/monitor/metrics)
    echo "octez_version:$data"
    echo "octez_validator_chain_is_bootsrtapped:$(echo $data | jq .is_bootstrapped)"
    echo "octez_p2p_connections_outgoing:$(echo $data | jq .connections.outgoing)"
    echo "octez_validator_chain_last_finished_request_completion_timestamp:$(echo $data | jq .last_finished_request_completion_timestamp)"
    echo "octez_p2p_peers_accepted:$(echo $data | jq .peers.accepted)"
    echo "octez_p2p_connections_active:$(echo $data | jq .connections.active)"
    echo "octez_store_invalid_blocks:$(echo $data | jq .invalid_blocks)"
    echo "octez_validator_chain_head_round:$(echo $data | jq .head.round)"
    echo "ocaml_gc_allocated_bytes:$(echo $data | jq .gc.allocated_bytes)"
    echo "octez_mempool_pending_applied:$(echo $data | jq .mempool.pending_applied)"

    # Collect average CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | \
                      sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | \
                      awk '{print 100 - $1}')
    echo "average_cpu_usage:$cpu_usage"

    # Collect average RAM usage
    local ram_usage=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2 }')
    echo "average_ram_usage:$ram_usage"

    # Collect network inbound and outbound traffic
    local net_dev=$(cat /proc/net/dev | grep 'eth0' | awk '{print $2 " " $10}')
    local net_in=$(echo $net_dev | awk '{print $1}')
    local net_out=$(echo $net_dev | awk '{print $2}')
    echo "network_inbound:$net_in"
    echo "network_outbound:$net_out"
}

case "$1" in
    get)
        octez_get
        ;;
    check)
        octez_check
        ;;
    *)
        echo "Usage: $0 {get|check}"
        exit 1
        ;;
esac
```

3. Make script executable

    sudo chmod +x /usr/libexec/netdata/charts.d/octez.sh

4. Edit netdata config to use that script and add 

    sudo ./edit-config netdata.conf

```
[plugins]
    charts.d = yes

[plugin:charts.d]
    # Load the custom script for Octez
    update every = 10
    command options = octez
```

5. Add this to charts.d.conf:

    sudo nano /etc/netdata/charts.d.conf
    
```
octez="yes"
```

6. Edit tezos-ghostnet/config.json

```
{ "data-dir": "/home/ubuntu/tezos-ghostnet",
  "p2p":
    { "bootstrap-peers":
        [ "ghostnet.teztnets.com", "ghostnet.tzinit.org",
          "ghostnet.tzboot.net", "ghostnet.boot.ecadinfra.com",
          "ghostnet.stakenow.de:9733" ], "listen-addr": "[::]:9732" },
  "shell": { "history_mode": "rolling" }, "network": "ghostnet",
  "metrics_addr": [ "127.0.0.1:9091" ] }
```

**Note**: Normally the rpc settings would be expected here but the config init doesnt add it and if added manually it doesnt work anymore:
```
"rpc": {
    "listen-addrs": ["127.0.0.1:8732"],
    "acl": [
      {
        "address": "127.0.0.1",
        "blacklist": []
      },
      {
        "address": "::1",
        "blacklist": []
      }
    ]
  },
```

5. Restart netdata

    sudo systemctl restart netdata
    sudo service netdata restart
    sudo journalctl -u netdata


### Prometheus and Grafana

For a more comprehensive setup using Prometheus and Grafana, you can start with the following:

1. **Install Prometheus**:
   ```sh
   wget https://github.com/prometheus/prometheus/releases/download/v2.32.1/prometheus-2.32.1.linux-amd64.tar.gz
   tar xvfz prometheus-2.32.1.linux-amd64.tar.gz
   cd prometheus-2.32.1.linux-amd64
   ./prometheus --config.file=prometheus.yml
   ```

2. **Install Grafana**:
   ```sh
   sudo apt-get install -y adduser libfontconfig1
   wget https://dl.grafana.com/oss/release/grafana_8.3.3_amd64.deb
   sudo dpkg -i grafana_8.3.3_amd64.deb
   sudo systemctl start grafana-server
   sudo systemctl enable grafana-server
   ```

3. **Configure Prometheus to scrape metrics**:
   Add your targets in `prometheus.yml`:
   ```yaml
   scrape_configs:
     - job_name: 'node'
       static_configs:
         - targets: ['localhost:9090']
   ```

4. **Access Grafana**:
   Open your browser and navigate to `http://<your-ec2-instance-ip>:3000`, then configure Grafana to use Prometheus as a data source.

