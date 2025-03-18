# Echo Test

A tool for measuring TCP connection latency between hosts.

## Purpose

This repository contains a simple client-server setup for testing TCP connection latency between different hosts in cloud environments. It's designed to evaluate performance of long-lived TCP connections across various network scenarios.

## Components

- `client/echo_client.py`: Python client for sending test data and measuring response times
- `server/setup-echo-server.sh`: Script to set up and run the echo server

## Usage

### Server Setup

The echo server uses xinetd to provide a simple TCP echo service on port 7.

1. SSH into the target host and clone this repository
2. Run the setup script with root privileges:

```bash
cd server
sudo ./setup-echo-server.sh
```

The script will:
- Install xinetd
- Configure the echo service
- Update the services file if needed
- Configure the firewall (optional)
- Start and enable the xinetd service

### Client Usage

The client script sends data to the echo server and measures round-trip time (RTT) with microsecond precision.

```bash
python3 client/echo_client.py [host] [port] [options]
```

Required arguments:
- `host`: Echo server hostname or IP address
- `port`: Echo server port (typically 7)

Optional arguments:
- `--size SIZE`: Size of payload in bytes (default: 64)
- `--frequency FREQUENCY`: Frequency to send packets in seconds (default: 1.0)
- `--count COUNT`: Number of packets to send (default: 0, meaning infinite)
- `--timeout TIMEOUT`: Socket timeout in seconds (default: 5.0)
- `--log-dir LOG_DIR`: Directory to store log files (default: logs)

### Examples

Run a test with default settings to a server at 10.0.0.1:
```bash
python3 client/echo_client.py 10.0.0.1 7
```

Send 100 packets of 1024 bytes at 0.5-second intervals:
```bash
python3 client/echo_client.py 10.0.0.1 7 --size 1024 --frequency 0.5 --count 100
```

### Output & Logs

The client generates two output files:
1. A log file with general information (`logs/echo_client_TIMESTAMP.log`)
2. A CSV file with precise timing data (`logs/echo_client_TIMESTAMP_timings.csv`)

The CSV contains columns for:
- packet_num: Sequential packet number
- timestamp: Human-readable timestamp
- send_time_ns: Send time in nanoseconds
- receive_time_ns: Receive time in nanoseconds
- rtt_us: Round-trip time in microseconds