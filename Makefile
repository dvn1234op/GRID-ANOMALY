.PHONY: help up down clean-docker run-subset run-full dashboard pipeline-status

help:
	@echo "⚡ Grid Anomaly Detection & Load Forecasting"
	@echo ""
	@echo "Available commands:"
	@echo "  make up              - Start the Hadoop/Hive/Spark Docker cluster"
	@echo "  make down            - Stop and remove the Docker cluster"
	@echo "  make run-subset      - Run the full pipeline on a 400-household subset (~10 mins)"
	@echo "  make run-full        - Run the pipeline on the full 10GB dataset (1-2 hours)"
	@echo "  make dashboard       - Launch the interactive Streamlit dashboard"
	@echo "  make clean-docker    - Remove containers, volumes, and networks (Fresh start)"

up:
	docker-compose -f docker/docker-compose.yml up -d
	@echo "Cluster is starting. Wait ~45s for Hive Metastore to initialize."

down:
	docker-compose -f docker/docker-compose.yml down

clean-docker:
	docker-compose -f docker/docker-compose.yml down -v

run-subset:
	./scripts/run_pipeline.sh --subset

run-full:
	./scripts/run_pipeline.sh --full

dashboard:
	python3 -m pip install streamlit
	streamlit run app.py
