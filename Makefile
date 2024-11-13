
health:
	@echo "Health check status: $$(curl -s http://localhost:5000/health)"

logs:
	sudo docker compose logs -f

clean:
	sudo docker compose down -v
	sudo rm -rf mlflow_artifacts postgres_data

config:
	python mlflow_config.py && ./setup.sh && sudo install-docker.sh


up:
	sudo docker compose up -d

down:
	sudo docker compose down -v


check:
	sudo docker ps
