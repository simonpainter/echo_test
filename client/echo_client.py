#!/usr/bin/env python3
import socket
import time
import argparse
import statistics
import sys
import os
from datetime import datetime


def print_stats(host, port, sent_count, received_count, rtt_times_us):
    loss = (sent_count - received_count) / sent_count * 100 if sent_count > 0 else 0
    print(f"\n--- {host}:{port} echo statistics ---")
    print(f"{sent_count} packets transmitted, {received_count} received, "
          f"{loss:.1f}% packet loss")
    if rtt_times_us:
        avg = statistics.mean(rtt_times_us)
        stddev = statistics.stdev(rtt_times_us) if len(rtt_times_us) > 1 else 0.0
        print(f"rtt min/avg/max/stddev = "
              f"{min(rtt_times_us):.3f}/{avg:.3f}/{max(rtt_times_us):.3f}/{stddev:.3f} μs")


def main():
    parser = argparse.ArgumentParser(description='TCP Echo Client with precise timing measurements')
    parser.add_argument('host', help='Echo server hostname or IP address')
    parser.add_argument('port', type=int, help='Echo server port')
    parser.add_argument('--size', type=int, default=64, help='Size of payload in bytes (default: 64)')
    parser.add_argument('--frequency', type=float, default=1.0,
                        help='Interval between packets in seconds (default: 1.0)')
    parser.add_argument('--count', type=int, default=0,
                        help='Number of packets to send (default: 0, meaning infinite)')
    parser.add_argument('--timeout', type=float, default=5.0,
                        help='Socket timeout in seconds (default: 5.0)')
    parser.add_argument('--csv', type=str, default=None,
                        help='Optional path to save timing data as CSV')
    args = parser.parse_args()

    # Build the payload from a repeating printable pattern
    pattern = b'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    if args.size <= len(pattern):
        payload = pattern[:args.size]
    else:
        payload = pattern * (args.size // len(pattern)) + pattern[:args.size % len(pattern)]

    csv_file = None
    if args.csv:
        csv_dir = os.path.dirname(args.csv)
        if csv_dir:
            os.makedirs(csv_dir, exist_ok=True)
        csv_file = open(args.csv, 'w')
        csv_file.write("packet_num,timestamp,send_time_ns,receive_time_ns,rtt_us\n")

    sent_count = 0
    received_count = 0
    rtt_times_us = []
    sock = None

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(args.timeout)

        print(f"ECHO {args.host}:{args.port} ({args.size} bytes of data)")
        sock.connect((args.host, args.port))

        # Send one unrecorded warmup packet so that TCP session setup,
        # ARP resolution, and kernel state are all complete before timing starts.
        sock.sendall(payload)
        warmup = b''
        while len(warmup) < args.size:
            chunk = sock.recv(args.size - len(warmup))
            if not chunk:
                raise ConnectionError("Connection closed by server")
            warmup += chunk

        packet_num = 1
        while args.count == 0 or packet_num <= args.count:
            ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
            start_ns = time.time_ns()

            sock.sendall(payload)
            sent_count += 1

            received_data = b''
            while len(received_data) < args.size:
                chunk = sock.recv(args.size - len(received_data))
                if not chunk:
                    raise ConnectionError("Connection closed by server")
                received_data += chunk

            end_ns = time.time_ns()
            rtt_us = (end_ns - start_ns) / 1000
            rtt_times_us.append(rtt_us)
            received_count += 1

            print(f"{args.size} bytes from {args.host}:{args.port}: seq={packet_num} time={rtt_us:.3f} μs")

            if csv_file:
                csv_file.write(f"{packet_num},{ts},{start_ns},{end_ns},{rtt_us:.3f}\n")
                csv_file.flush()

            packet_num += 1
            if args.count == 0 or packet_num <= args.count:
                time.sleep(args.frequency)

    except KeyboardInterrupt:
        pass
    except socket.timeout:
        print(f"ERROR: socket timeout — server not responding", file=sys.stderr)
    except ConnectionError as e:
        print(f"ERROR: {e}", file=sys.stderr)
    except socket.error as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    finally:
        print_stats(args.host, args.port, sent_count, received_count, rtt_times_us)
        if sock:
            sock.close()
        if csv_file:
            csv_file.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())