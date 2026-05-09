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

The client connects to the echo server and measures round-trip time (RTT) with microsecond precision, displaying output in a style similar to `ping`. A warmup packet is sent silently after the TCP connection is established to settle ARP resolution and kernel state before timing begins.

```bash
python3 client/echo_client.py <host> <port> [options]
```

Required arguments:
- `host`: Echo server hostname or IP address
- `port`: Echo server port (typically 7)

Optional arguments:
- `--size SIZE`: Size of payload in bytes (default: 64)
- `--frequency FREQUENCY`: Interval between packets in seconds (default: 1.0)
- `--count COUNT`: Number of packets to send; 0 means infinite (default: 0)
- `--timeout TIMEOUT`: Socket timeout in seconds (default: 5.0)
- `--csv PATH`: Save precise timing data to a CSV file (optional)

Press **Ctrl+C** to stop an infinite run; a statistics summary is always printed on exit.

### Examples

Run a continuous test against a server at 10.0.0.1:
```bash
python3 client/echo_client.py 10.0.0.1 7
```

Send 100 packets of 1024 bytes at 0.5-second intervals:
```bash
python3 client/echo_client.py 10.0.0.1 7 --size 1024 --frequency 0.5 --count 100
```

Save timing data to a CSV file:
```bash
python3 client/echo_client.py 10.0.0.1 7 --count 60 --csv results/run1.csv
```

### Output

Each packet prints a single line and a summary is shown on exit:

```
ECHO 10.0.0.1:7 (64 bytes of data)
64 bytes from 10.0.0.1:7: seq=1 time=312.450 μs
64 bytes from 10.0.0.1:7: seq=2 time=298.112 μs
^C
--- 10.0.0.1:7 echo statistics ---
2 packets transmitted, 2 received, 0.0% packet loss
rtt min/avg/max/stddev = 298.112/305.281/312.450/10.139 μs
```

If `--csv` is specified the file contains these columns:
- `packet_num`: Sequential packet number
- `timestamp`: Human-readable timestamp
- `send_time_ns`: Send time in nanoseconds
- `receive_time_ns`: Receive time in nanoseconds
- `rtt_us`: Round-trip time in microseconds