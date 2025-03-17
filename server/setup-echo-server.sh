#!/bin/bash
#
# Echo Server Setup Script
# This script installs and configures an echo server using xinetd on Ubuntu
# It also optionally opens the required firewall ports
#

# Exit on error
set -e

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# Log functions
log_info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    echo "Please run with sudo or as root user"
    exit 1
fi

# Print banner
echo -e "${BOLD}=========================================${RESET}"
echo -e "${BOLD}     Echo Server Setup Script v1.0      ${RESET}"
echo -e "${BOLD}=========================================${RESET}"
echo ""

# Function to install xinetd
install_xinetd() {
    log_info "Updating package lists..."
    apt-get update

    log_info "Installing xinetd..."
    apt-get install -y xinetd
}

# Function to configure echo service
configure_echo_service() {
    local config_file="/etc/xinetd.d/echo"
    
    log_info "Creating echo service configuration..."
    cat > "$config_file" << 'EOF'
# Echo service configuration
service echo
{
    disable         = no
    type            = INTERNAL
    id              = echo-stream
    socket_type     = stream
    protocol        = tcp
    user            = root
    wait            = no
    log_type        = SYSLOG daemon info
    log_on_success  = HOST PID
    log_on_failure  = HOST
}

service echo
{
    disable         = no
    type            = INTERNAL
    id              = echo-dgram
    socket_type     = dgram
    protocol        = udp
    user            = root
    wait            = yes
    log_type        = SYSLOG daemon info
    log_on_success  = HOST PID
    log_on_failure  = HOST
}
EOF

    chmod 644 "$config_file"
    log_info "Echo service configuration created at $config_file"
}

# Function to update /etc/services if needed
update_services_file() {
    local services_file="/etc/services"
    
    if ! grep -q "^echo" "$services_file"; then
        log_info "Adding echo service to $services_file..."
        echo "# Echo service" >> "$services_file"
        echo "echo            7/tcp" >> "$services_file"
        echo "echo            7/udp" >> "$services_file"
    else
        log_info "Echo service already defined in $services_file"
    fi
}

# Function to configure firewall
configure_firewall() {
    if command -v ufw &> /dev/null; then
        log_info "Firewall (ufw) detected"
        read -p "Do you want to open port 7 in the firewall? (y/n): " open_firewall
        
        if [[ "$open_firewall" =~ ^[Yy]$ ]]; then
            log_info "Opening TCP port 7 in firewall..."
            ufw allow 7/tcp
            
            log_info "Opening UDP port 7 in firewall..."
            ufw allow 7/udp
            
            log_info "Firewall rules added for echo service"
        else
            log_warn "Firewall ports not opened. Make sure port 7 is accessible if needed."
        fi
    else
        log_warn "UFW firewall not detected. If you have a different firewall, please open port 7 manually."
    fi
}

# Function to restart and enable xinetd
restart_xinetd() {
    log_info "Restarting xinetd service..."
    systemctl restart xinetd
    
    log_info "Enabling xinetd to start on boot..."
    systemctl enable xinetd
    
    # Check if service is running
    if systemctl is-active --quiet xinetd; then
        log_info "xinetd service is running"
    else
        log_error "xinetd service failed to start"
        exit 1
    fi
}

# Function to display service status
show_status() {
    echo ""
    echo -e "${BOLD}=========================================${RESET}"
    echo -e "${BOLD}         Echo Server Status              ${RESET}"
    echo -e "${BOLD}=========================================${RESET}"
    
    echo ""
    log_info "xinetd status:"
    systemctl status xinetd --no-pager
    
    echo ""
    log_info "Listening ports:"
    ss -tuln | grep ":7 "
    
    echo ""
    log_info "Echo server setup complete!"
    echo ""
    echo "The echo server is now running on port 7 (TCP and UDP)"
    echo "You can test it with: telnet localhost 7"
    echo "                  or: echo 'test' | nc localhost 7"
    echo ""
}

# Main execution flow
main() {
    log_info "Starting echo server setup..."
    
    install_xinetd
    configure_echo_service
    update_services_file
    configure_firewall
    restart_xinetd
    show_status
    
    log_info "Setup completed successfully!"
}

# Run the main function
main

exit 0
