# Bakta Docker Environment and Testing Makefile

# Configuration
IMAGE_NAME = bakta-test
CONTAINER_NAME = bakta-container
DB_DIR = $(PWD)/data/db
TEST_DIR = $(PWD)/data/test
OUTPUT_DIR = $(PWD)/data/output
SAMPLE_GENOME = test_genome.fasta

# Docker settings
DOCKER_RUN = docker run --rm -v $(DB_DIR):/data/db -v $(TEST_DIR):/data/test -v $(OUTPUT_DIR):/data/output --entrypoint="" $(IMAGE_NAME)

.PHONY: all help build clean test test-quick test-full setup-dirs download-db download-sample-genome

all: help

help: ## Show this help message
	@echo "Bakta Docker Environment Makefile"
	@echo "=================================="
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

setup-dirs: ## Create necessary directories
	@echo "Creating data directories..."
	mkdir -p $(DB_DIR) $(TEST_DIR) $(OUTPUT_DIR)

build: setup-dirs ## Build Docker image
	@echo "Building Docker image..."
	docker build -t $(IMAGE_NAME) .

clean: ## Remove Docker image and data directories
	@echo "Cleaning up..."
	docker rmi -f $(IMAGE_NAME) 2>/dev/null || true
	rm -rf data/

rebuild: clean build ## Clean and rebuild Docker image

test-install: build ## Test if Bakta is properly installed in container
	@echo "Testing Bakta installation..."
	$(DOCKER_RUN) bakta --version
	$(DOCKER_RUN) bakta --help

download-db-light: build setup-dirs ## Download light database (1.3GB)
	@echo "Downloading light database from Zenodo..."
	$(DOCKER_RUN) bash -c "cd /data/db && wget -O db-light.tar.xz https://zenodo.org/record/14916843/files/db-light.tar.xz"
	@echo "Extracting database..."
	$(DOCKER_RUN) bash -c "cd /data/db && tar -xf db-light.tar.xz"
	@echo "Setting up AMRFinder database..."
	$(DOCKER_RUN) bash -c "amrfinder_update --force_update --database /data/db/db-light/amrfinderplus-db/" || true

download-db-full: build setup-dirs ## Download full database (31.9GB) - WARNING: Large download!
	@echo "WARNING: This will download 31.9GB of data. Are you sure? [y/N]"
	@read line; if [ $$line = "y" ] || [ $$line = "Y" ]; then \
		echo "Downloading full database from Zenodo..."; \
		$(DOCKER_RUN) bash -c "cd /data/db && wget -O db.tar.xz https://zenodo.org/record/14916843/files/db.tar.xz"; \
		echo "Extracting database..."; \
		$(DOCKER_RUN) bash -c "cd /data/db && tar -xf db.tar.xz"; \
		echo "Setting up AMRFinder database..."; \
		$(DOCKER_RUN) bash -c "amrfinder_update --force_update --database /data/db/db/amrfinderplus-db/" || true; \
	else \
		echo "Cancelled."; \
	fi

create-sample-genome: setup-dirs ## Create a small sample genome for testing
	@echo "Creating sample genome..."
	@echo ">test_genome" > $(TEST_DIR)/$(SAMPLE_GENOME)
	@echo "ATGAAAAAATTAATTATTCGCAACATCCATACGTTTATACGATGGATCCAAATTTGGGGAATACTACGATGATGATCTGATTCCGGATATTGATGAACCGACGGATGATCGCGATGATGATGATGATTAA" >> $(TEST_DIR)/$(SAMPLE_GENOME)
	@echo "ATGGGCTTTATTACCCCAGATGATGATGATGATGATGATGATGATGATGATCCGGGCGGCGGCGGCTATGCCGATGATGATGATTAA" >> $(TEST_DIR)/$(SAMPLE_GENOME)

download-sample-genome: setup-dirs ## Download E. coli sample genome
	@echo "Downloading E. coli sample genome..."
	$(DOCKER_RUN) bash -c "cd /data/test && wget -O ecoli_sample.fna.gz 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/005/825/GCF_000005825.2_ASM582v2/GCF_000005825.2_ASM582v2_genomic.fna.gz'"
	$(DOCKER_RUN) bash -c "cd /data/test && gunzip ecoli_sample.fna.gz"

test-quick: build create-sample-genome ## Quick test with minimal sample (requires light DB)
	@echo "Running quick test with sample genome..."
	@if [ ! -d "$(DB_DIR)/db-light" ]; then \
		echo "Light database not found. Please run 'make download-db-light' first."; \
		exit 1; \
	fi
	$(DOCKER_RUN) bakta --db /data/db/db-light --output /data/output --prefix quick_test /data/test/$(SAMPLE_GENOME)
	@echo "Quick test completed. Check $(OUTPUT_DIR)/ for results."

test-full: build download-sample-genome ## Full test with E. coli genome (requires light DB)
	@echo "Running full test with E. coli genome..."
	@if [ ! -d "$(DB_DIR)/db-light" ]; then \
		echo "Light database not found. Please run 'make download-db-light' first."; \
		exit 1; \
	fi
	$(DOCKER_RUN) bakta --db /data/db/db-light --output /data/output --prefix ecoli_test --genus Escherichia --species coli /data/test/ecoli_sample.fna
	@echo "Full test completed. Check $(OUTPUT_DIR)/ for results."

interactive: build ## Start interactive bash session in container
	docker run -it --rm -v $(DB_DIR):/data/db -v $(TEST_DIR):/data/test -v $(OUTPUT_DIR):/data/output $(IMAGE_NAME) bash

check-db: ## Check database status
	@if [ -d "$(DB_DIR)/db-light" ]; then \
		echo "Light database: PRESENT"; \
		ls -la $(DB_DIR)/db-light/ | head -10; \
	else \
		echo "Light database: NOT FOUND"; \
	fi
	@if [ -d "$(DB_DIR)/db" ]; then \
		echo "Full database: PRESENT"; \
		ls -la $(DB_DIR)/db/ | head -10; \
	else \
		echo "Full database: NOT FOUND"; \
	fi

status: ## Show current status
	@echo "Bakta Docker Environment Status"
	@echo "==============================="
	@echo "Docker image: $(shell docker images -q $(IMAGE_NAME) >/dev/null 2>&1 && echo "PRESENT" || echo "NOT BUILT")"
	@echo "DB directory: $(shell [ -d "$(DB_DIR)" ] && echo "EXISTS" || echo "NOT CREATED")"
	@echo "Test directory: $(shell [ -d "$(TEST_DIR)" ] && echo "EXISTS" || echo "NOT CREATED")"
	@echo "Output directory: $(shell [ -d "$(OUTPUT_DIR)" ] && echo "EXISTS" || echo "NOT CREATED")"
	@make check-db

# Complete setup workflow
setup: build download-db-light create-sample-genome ## Complete setup: build image, download light DB, create sample
	@echo "Setup completed! You can now run 'make test-quick' or 'make test-full'"