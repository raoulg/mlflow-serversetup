RED := \033[0;31m
YELLOW := \033[0;33m
NC := \033[0m # No Color

# Default shell
SHELL := /bin/bash

# Mark these targets as not corresponding to files
.PHONY: help health logs clean config up down check-docker check-dependencies check-memory monitor-memory

# Variables
DOCKER_PORTS := 5000 5001 5002 5003 5004
REQUIRED_BINARIES := curl docker python3
MIN_AVAILABLE_MEMORY := 1024  # Minimum available memory in MB before warning

help:
	@echo -e "$(YELLOW)Available commands:$(NC)"
	@echo -e "  make help$(NC)         - Show this help message"
	@echo -e "  make up$(NC)           - Start all containers"
	@echo -e "  make down$(NC)         - Stop and remove all containers"
	@echo -e "  make health$(NC)       - Check health of all services and memory usage"
	@echo -e "  make logs$(NC)         - Show container logs"
	@echo -e "  make clean$(NC)        - Remove containers, volumes, and data"
	@echo -e "  make config$(NC)       - Configure environment and install dependencies"
	@echo -e "  make monitor-memory$(NC) - Monitor container resource usage"

check-docker:
	@if ! command -v sudo docker >/dev/null 2>&1; then \
		echo -e "$(YELLOW)Docker not installed. Running install script...$(NC)"; \
		sudo ./install-docker.sh; \
	elif ! systemctl is-active --quiet docker; then \
		echo -e "$(YELLOW)Docker installed but not running. Starting Docker...$(NC)"; \
		sudo systemctl start docker; \
	else \
		echo -e "$(GREEN)Docker is installed and running$(NC)"; \
	fi

# Check if docker and dependencies are installed
check-dependencies:
	@for bin in $(REQUIRED_BINARIES); do \
		if ! command -v $$bin >/dev/null 2>&1; then \
			echo -e "$(RED)Error: $$bin is not installed$(NC)"; \
			exit 1; \
		fi \
	done
	@echo -e "$(GREEN)All required dependencies are installed$(NC)"


check-memory:
	@total_mem=$$(free -m | awk '/^Mem:/{print $$2}'); \
	container_count=$$(sudo docker ps --format '{{.Names}}' | wc -l); \
	used_by_docker=$$(sudo docker stats --no-stream --format "{{.MemUsage}}" | head -n$$container_count | awk '{split($$1,a,".");print a[1]}' | sed 's/[^0-9]//g' | awk '{sum+=$$1}END{print sum}') || echo 0; \
	available_mem=$$(free -m | awk '/^Mem:/{print $$7}'); \
	echo -e "$(YELLOW)Memory Status:$(NC)"; \
	echo -e "Total System Memory: $(GREEN)$$total_mem MB$(NC)"; \
	echo -e "Available Memory: $(GREEN)$$available_mem MB$(NC)"; \
	echo -e "Memory Used by Docker: $(GREEN)$$used_by_docker MB$(NC)"; \
	if [ $$available_mem -lt $(MIN_AVAILABLE_MEMORY) ]; then \
		echo -e "$(YELLOW)Warning: Less than 1GB memory available. System might become unstable.$(NC)"; \
	fi

monitor-memory:
	@echo -e "$(YELLOW)Monitoring Docker container memory usage...$(NC)"
	@sudo sudo docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

health: check-dependencies
	@echo -e "$(YELLOW)Checking services health...$(NC)"
	@for port in $(DOCKER_PORTS); do \
		status=$$(curl -s http://localhost:$$port/health); \
		echo -e "Health check status (port $$port): $(GREEN)$$status$(NC)"; \
	done
	@echo -e "\n$(YELLOW)Docker containers:$(NC)"
	@sudo sudo docker ps
	@echo -e "\n$(YELLOW)Memory Status:$(NC)"
	@make check-memory

logs: check-dependencies
	@echo -e "$(YELLOW)Tailing docker compose logs...$(NC)"
	@sudo sudo docker compose logs -f

clean: check-dependencies
	@echo -e "$(YELLOW)Cleaning up containers and volumes...$(NC)"
	@sudo sudo docker compose down -v
	@sudo rm -rf mlflow_artifacts postgres_data
	@echo -e "$(GREEN)Cleanup complete$(NC)"

config: check-dependencies check-docker
	@echo -e "$(YELLOW)Configuring environment...$(NC)"
	@python mlflow_config.py && ./setup.sh
	@echo -e "$(GREEN)Configuration complete$(NC)"

up: check-dependencies check-docker check-memory
	@echo -e "$(YELLOW)Starting containers...$(NC)"
	@sudo sudo docker compose up -d
	@echo -e "$(GREEN)Containers started$(NC)"
	@make monitor-memory

down: check-dependencies
	@echo -e "$(YELLOW)Stopping containers...$(NC)"
	@sudo sudo docker compose down -v
	@echo -e "$(GREEN)Containers stopped$(NC)"
