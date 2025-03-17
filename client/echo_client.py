#!/usr/bin/env python3
import socket
import time
import argparse
import statistics
import sys
import logging
import os
from datetime import datetime

def setup_logging(log_file):
    """Configure logging to both console and file"""
    # Create logger
    logger = logging.getLogger('echo_client')
    logger.setLevel(logging.INFO)
    
    # Create file handler
    file_handler = logging.FileHandler(log_file)
    file_handler.setLevel(logging.INFO)
    
    # Create console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    
    # Create formatter and add it to the handlers
    formatter = logging.Formatter('%(asctime)s.%(msecs)03d - %(levelname)s - %(message)s', 
                                 datefmt='%Y-%m-%d %H:%M:%S')
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    
    # Add handlers to logger
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    return logger

def main():
    parser = argparse.ArgumentParser(description='TCP Echo Client with precise timing measurements')
    parser.add_argument('host', help='Echo server hostname or IP address')
    parser.add_argument('port', type=int, help='Echo server port')
    parser.add_argument('--size', type=int, default=64, help='Size of payload in bytes (default: 64)')
    parser.add_argument('--frequency', type=float, default=1.0, 
                        help='Frequency to send packets in seconds (default: 1.0)')
    parser.add_argument('--count', type=int, default=0, 
                        help='Number of packets to send (default: 0, meaning infinite)')
    parser.add_argument('--timeout', type=float, default=5.0, 
                        help='Socket timeout in seconds (default: 5.0)')
    parser.add_argument('--log-dir', type=str, default='logs', 
                        help='Directory to store log files (default: logs)')
    args = parser.parse_args()

    # Create logs directory if it doesn't exist
    if not os.path.exists(args.log_dir):
        os.makedirs(args.log_dir)

    # Create unique filenames for this session
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(args.log_dir, f'echo_client_{timestamp}.log')
    csv_file = os.path.join(args.log_dir, f'echo_client_{timestamp}_timings.csv')
    
    # Setup logging
    logger = setup_logging(log_file)
    logger.info(f"Starting Echo Client - logging to {log_file}")
    logger.info(f"Precise timing data will be saved to {csv_file}")
    
    # Create the payload - use a pattern to make it identifiable
    payload = b'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    if args.size <= len(payload):
        payload = payload[:args.size]
    else:
        pattern = payload
        payload = pattern * (args.size // len(pattern)) + pattern[:args.size % len(pattern)]
    
    # Open CSV file for precise timing data
    with open(csv_file, 'w') as timing_file:
        # Write CSV header
        timing_file.write("packet_num,timestamp,send_time_ns,receive_time_ns,rtt_us\n")

        try:
            # Create TCP socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(args.timeout)
            
            # Connect to the server
            logger.info(f"Connecting to {args.host}:{args.port}...")
            sock.connect((args.host, args.port))
            logger.info(f"Connected to {args.host}:{args.port}")
            
            # Statistics
            sent_count = 0
            received_count = 0
            rtt_times_us = []  # RTT in microseconds
            
            try:
                packet_count = 1
                while args.count == 0 or packet_count <= args.count:
                    # Record start time and send data
                    logger.info(f"Sending packet #{packet_count} ({args.size} bytes)...")
                    
                    # Get precise timestamp before sending
                    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
                    start_time_ns = time.time_ns()  # Nanosecond precision
                    
                    # Send the data
                    sock.sendall(payload)
                    sent_count += 1
                    
                    # Receive response
                    received_data = b''
                    while len(received_data) < args.size:
                        chunk = sock.recv(args.size - len(received_data))
                        if not chunk:
                            raise ConnectionError("Connection closed by server")
                        received_data += chunk
                    
                    # Get precise time after receiving complete response
                    end_time_ns = time.time_ns()  # Nanosecond precision
                    
                    # Calculate RTT in microseconds
                    rtt_us = (end_time_ns - start_time_ns) / 1000  # Convert ns to μs
                    rtt_times_us.append(rtt_us)
                    received_count += 1
                    
                    # Display result
                    logger.info(f"Received response for packet #{packet_count} in {rtt_us:.3f} μs")
                    
                    # Write precise timing data to CSV
                    timing_file.write(f"{packet_count},{timestamp},{start_time_ns},{end_time_ns},{rtt_us:.3f}\n")
                    timing_file.flush()  # Ensure data is written immediately
                    
                    # Wait for next iteration
                    packet_count += 1
                    if args.count == 0 or packet_count <= args.count:
                        time.sleep(args.frequency)
                        
            except KeyboardInterrupt:
                logger.info("User interrupted - shutting down")
            except socket.timeout:
                logger.error("TCP CONNECTION DROP: Socket timeout - server not responding")
            except ConnectionError as e:
                logger.error(f"TCP CONNECTION DROP: {e}")
            except socket.error as e:
                logger.error(f"TCP CONNECTION DROP: Socket error: {e}")
            
        except socket.error as e:
            logger.error(f"Socket error during connection: {e}")
            return 1
        finally:
            # Print statistics
            if rtt_times_us:
                logger.info("\n--- Echo Client Statistics ---")
                logger.info(f"Packets: Sent = {sent_count}, Received = {received_count}, "
                      f"Lost = {sent_count - received_count} "
                      f"({(sent_count - received_count) / sent_count * 100 if sent_count > 0 else 0:.1f}% loss)")
                logger.info(f"RTT: Min = {min(rtt_times_us):.3f}μs, Max = {max(rtt_times_us):.3f}μs, "
                      f"Avg = {statistics.mean(rtt_times_us):.3f}μs")
                if len(rtt_times_us) > 1:
                    logger.info(f"     StdDev = {statistics.stdev(rtt_times_us):.3f}μs")
            
            # Close socket if it exists
            if 'sock' in locals():
                sock.close()
                logger.info("Connection closed")
            
            logger.info("Echo client terminated")
                
        return 0


if __name__ == "__main__":
    sys.exit(main())