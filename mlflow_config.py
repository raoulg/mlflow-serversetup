import os
import subprocess
import tomllib
from pathlib import Path
from string import Template


def _load_config() -> dict:
    config_path = Path("config.toml")
    if not config_path.exists():
        raise FileNotFoundError
    else:
        with config_path.open("rb") as f:
            return tomllib.load(f)


_config = _load_config()

TEAMS: list[str] = _config["teams"]["team_list"]
BASE_PORT: int = int(_config["server"]["base_port"])
LOCAL_DB_PASSWORD: str = _config["database"]["local_password"]


def generate_dockerfile():
    dockerfile_content = """FROM ghcr.io/mlflow/mlflow:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    python3-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install psycopg2-binary
RUN pip install --no-cache-dir psycopg2-binary

# Create directory for artifacts with proper permissions
RUN mkdir -p /mlflow/artifacts && \
    chmod 777 /mlflow/artifacts

EXPOSE 5000
"""
    with open("Dockerfile", "w") as f:
        f.write(dockerfile_content)
    print("Generated Dockerfile")


def generate_docker_compose():
    docker_compose_template = """services:
  db:
    image: postgres:14
    environment:
      - POSTGRES_PASSWORD=${LOCAL_DB_PASSWORD}
      - POSTGRES_USER=postgres
      - POSTGRES_DB=mlflow
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - mlflow-net

$mlflow_services

networks:
  mlflow-net:
    driver: bridge

volumes:
  postgres_data:
  mlflow_artifacts:
"""

    mlflow_service_template = """  mlflow-$team:
    build: .
    ports:
      - "$port:5000"
    environment:
      - MLFLOW_TRACKING_URI=postgresql://postgres:${LOCAL_DB_PASSWORD}@db:5432/mlflow
      - MLFLOW_ARTIFACT_ROOT=/mlflow/artifacts/$team
    volumes:
      - mlflow_artifacts:/mlflow/artifacts
    command: mlflow server --host 0.0.0.0 --port 5000
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl", "-f", "http://0.0.0.0:5000/health || exit 1"]
      interval: 30s
      timeout: 15s
      retries: 3
      start_period: 40s
    restart: unless-stopped
    networks:
      - mlflow-net

      """

    mlflow_services = []
    for i, team in enumerate(TEAMS):
        service = Template(mlflow_service_template).substitute(
            team=team,
            port=BASE_PORT + i,
            LOCAL_DB_PASSWORD=LOCAL_DB_PASSWORD,
        )
        mlflow_services.append(service)

    return Template(docker_compose_template).substitute(
        mlflow_services="\n".join(mlflow_services), LOCAL_DB_PASSWORD=LOCAL_DB_PASSWORD
    )


def generate_setup_script():
    # Create the team directories commands as a single string
    mkdir_commands = "\n".join(
        [
            f'mkdir -p "mlflow_artifacts/{team}"\nchmod 755 "mlflow_artifacts/{team}"'
            for team in TEAMS
        ]
    )

    setup_script = """#!/bin/bash

echo "Creating artifacts directory structure..."
mkdir -p mlflow_artifacts

# Create team directories
$mkdir_commands

# Create simple .env file
echo "LOCAL_DB_PASSWORD=$password" > .env

echo "Setup completed! You can now run: docker compose up -d"
"""
    return Template(setup_script).substitute(
        mkdir_commands=mkdir_commands, password=LOCAL_DB_PASSWORD
    )


def get_external_ip():
    try:
        # Using curl to get external IP
        result = subprocess.run(
            ["curl", "-s", "ifconfig.me"], capture_output=True, text=True
        )
        return result.stdout.strip()
    except Exception as e:
        print(f"Failed to get external IP: {e}")
        return "localhost"  # Fallback to localhost if failed


def main():
    # Generate Dockerfile first
    generate_dockerfile()

    # Create all files
    with open("docker-compose.yml", "w") as f:
        f.write(generate_docker_compose())
    print("Generated docker-compose.yml")

    with open("setup.sh", "w") as f:
        f.write(generate_setup_script())
    os.chmod("setup.sh", 0o755)
    print("Generated setup.sh")

    # Simplified README
    readme_content = """# MLflow Multi-Team Local Setup
## Team URLs

{}
"""

    connection_details = []
    external_ip = get_external_ip()
    for i, team in enumerate(TEAMS):
        port = BASE_PORT + i
        details = f"- {team}: http://{external_ip}:{port}"
        connection_details.append(details)

    with open("team_urls.md", "w") as f:
        f.write(readme_content.format("\n".join(connection_details)))
    print("Generated team_urls.md")


if __name__ == "__main__":
    main()
