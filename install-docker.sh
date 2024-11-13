#!/bin/bash

# Function to print messages with colors
print_status() {
    local color=$1
    local message=$2
    case $color in
        "green") echo -e "\e[32m$message\e[0m" ;;
        "red") echo -e "\e[31m$message\e[0m" ;;
        "yellow") echo -e "\e[33m$message\e[0m" ;;
    esac
}

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        print_status "green" "✔ $1 successful"
    else
        print_status "red" "✘ $1 failed"
        exit 1
    fi
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    print_status "red" "Please run this script as root or with sudo"
    exit 1
fi

print_status "yellow" "Starting Docker installation process..."

# Remove old versions
print_status "yellow" "Removing old Docker packages if they exist..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y $pkg &>/dev/null
done
check_status "Removal of old packages"

# Update package index
print_status "yellow" "Updating package index..."
apt-get update
check_status "Package index update"

# Install prerequisites
print_status "yellow" "Installing prerequisites..."
apt-get install -y ca-certificates curl
check_status "Prerequisites installation"

# Setup Docker repository
print_status "yellow" "Setting up Docker repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
check_status "Docker GPG key setup"

# Add Docker repository
print_status "yellow" "Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null
check_status "Docker repository addition"

# Update package index again
elseint_status "yellow" "Updating package index with Docker repository..."
apt-get update
check_status "Package index update with Docker repository"

# Install Docker
print_status "yellow" "Installing Docker packages..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
check_status "Docker installation"

sudo usermod -aG docker $USER
echo "User $USER added to the docker group. Please log out and log back in for changes to take effect."

# Verify installation
print_status "yellow" "Verifying Docker installation..."
if docker run hello-world &>/dev/null; then
    print_status "green" "✔ Docker installation verified successfully!"
    print_status "green" "Docker has been successfully installed and is running properly."
else
    print_status "red" "✘ Docker verification failed. Please check the system logs for more details."
    exit 1
fi
