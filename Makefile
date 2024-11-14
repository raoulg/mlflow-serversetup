# Colors for output
GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[0;33m
NC := \033[0m # No Color

# Default shell
SHELL := /bin/bash

# Mark these targets as not corresponding to files
.PHONY: health logs clean config up down check-docker check-dependencies

# Variables
DOCKER_PORTS := 5000 5001 5002 5003 5004
REQUIRED_BINARIES := curl docker docker-compose python3

# Check if docker and dependencies are installed
check-dependencies:
	@for bin in $(REQUIRED_BINARIES); do \
		if ! command -v $$bin >/dev/null 2>&1; then \
			echo -e "$(RED)Error: $$bin is not installed$(NC)"; \
			exit 1; \
		fi \
	done
	@echo -e "$(GREEN)All required dependencies are installed$(NC)"

check-docker:
	@if ! command -v docker >/dev/null 2>&1; then \
		echo -e "$(YELLOW)Docker not installed. Running install script...$(NC)"; \
		sudo ./install-docker.sh; \
	elif ! systemctl is-active --quiet docker; then \
		echo -e "$(YELLOW)Docker installed but not running. Starting Docker...$(NC)"; \
		sudo systemctl start docker; \
	else \
		echo -e "$(GREEN)Docker is installed and running$(NC)"; \
	fi

health: check-dependencies
	@echo -e "$(YELLOW)Checking services health...$(NC)"
	@for port in $(DOCKER_PORTS); do \
		status=$$(curl -s http://localhost:$$port/health); \
		echo -e "Health check status (port $$port): $(GREEN)$$status$(NC)"; \
	done
	@echo -e "\n$(YELLOW)Docker containers:$(NC)"
	@sudo docker ps

logs: check-dependencies
	@echo -e "$(YELLOW)Tailing docker compose logs...$(NC)"
	@sudo docker compose logs -f

clean: check-dependencies
	@echo -e "$(YELLOW)Cleaning up containers and volumes...$(NC)"
	@sudo docker compose down -v
	@sudo rm -rf mlflow_artifacts postgres_data
	@echo -e "$(GREEN)Cleanup complete$(NC)"

config: check-dependencies check-docker
	@echo -e "$(YELLOW)Configuring environment...$(NC)"
	@python mlflow_config.py && ./setup.sh
	@echo -e "$(GREEN)Configuration complete$(NC)"

up: check-dependencies check-docker
	@echo -e "$(YELLOW)Starting containers...$(NC)"
	@sudo docker compose up -d
	@echo -e "$(GREEN)Containers started$(NC)"

down: check-dependencies
	@echo -e "$(YELLOW)Stopping containers...$(NC)"
	@sudo docker compose down -v
	@echo -e "$(GREEN)Containers stopped$(NC)"
