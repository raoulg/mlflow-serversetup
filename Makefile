
health:
	@echo "Health check status: $$(curl -s http://localhost:5000/health)"
	@echo "Health check status: $$(curl -s http://localhost:5001/health)"
	@echo "Health check status: $$(curl -s http://localhost:5002/health)"
	@echo "Health check status: $$(curl -s http://localhost:5003/health)"
	@echo "Health check status: $$(curl -s http://localhost:5004/health)"
	sudo docker ps

logs:
	sudo docker compose logs -f

clean:
	sudo docker compose down -v
	sudo rm -rf mlflow_artifacts postgres_data

config:
	python mlflow_config.py && ./setup.sh && sudo ./install-docker.sh


up:
	sudo docker compose up -d

down:
	sudo docker compose down -v


