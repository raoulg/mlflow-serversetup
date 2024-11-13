
logs:
	sudo docker compose logs -f

clean:
	sudo docker compose down -v
	sudo rm -rf mlflow_artifacts postgres_data

config:
	python mlflow_config.py

up:
	sudo docker compose up -d

down:
	sudo docker compose down -v


check:
	sudo docker ps
