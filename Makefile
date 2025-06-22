# Makefile for Flye Genome Assembly Pipeline
# Author: Your Name
# Version: 1.0

# Variables
CONDA_ENV = flye-assembly
SCRIPTS_DIR = scripts
CONFIG_DIR = config
TEST_DATA_DIR = test_data

# Colors
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help install test clean lint setup-dev check-deps example

# Default target
help:
	@echo "$(GREEN)Flye Genome Assembly Pipeline$(NC)"
	@echo ""
	@echo "Available targets:"
	@echo "  $(YELLOW)install$(NC)     - Install dependencies and set up environment"
	@echo "  $(YELLOW)test$(NC)        - Run tests and validation"
	@echo "  $(YELLOW)lint$(NC)        - Run linting on shell scripts"
	@echo "  $(YELLOW)clean$(NC)       - Clean up temporary files"
	@echo "  $(YELLOW)setup-dev$(NC)   - Set up development environment"
	@echo "  $(YELLOW)check-deps$(NC)  - Check if all dependencies are installed"
	@echo "  $(YELLOW)example$(NC)     - Create example data and run demo"
	@echo "  $(YELLOW)help$(NC)        - Show this help message"

# Install dependencies
install:
	@echo "$(GREEN)Installing dependencies...$(NC)"
	@if command -v conda >/dev/null 2>&1; then \
		conda env create -f environment.yml; \
		echo "$(GREEN)Conda environment '$(CONDA_ENV)' created successfully$(NC)"; \
		echo "$(YELLOW)Activate with: conda activate $(CONDA_ENV)$(NC)"; \
	else \
		echo "$(RED)Error: Conda not found. Please install Conda first.$(NC)"; \
		exit 1; \
	fi

# Set up development environment
setup-dev: install
	@echo "$(GREEN)Setting up development environment...$(NC)"
	@conda run -n $(CONDA_ENV) pip install pytest black flake8
	@chmod +x $(SCRIPTS_DIR)/*.sh
	@echo "$(GREEN)Development environment ready$(NC)"

# Check dependencies
check-deps:
	@echo "$(GREEN)Checking dependencies...$(NC)"
	@conda run -n $(CONDA_ENV) bash -c ' \
		echo "Checking core tools..."; \
		flye --version 2>/dev/null && echo "✓ Flye installed" || echo "✗ Flye missing"; \
		minimap2 --version 2>/dev/null && echo "✓ Minimap2 installed" || echo "✗ Minimap2 missing"; \
		racon --version 2>/dev/null && echo "✓ Racon installed" || echo "✗ Racon missing"; \
		medaka --version 2>/dev/null && echo "✓ Medaka installed" || echo "✗ Medaka missing"; \
		quast --version 2>/dev/null && echo "✓ QUAST installed" || echo "✗ QUAST missing"; \
		seqtk 2>&1 | head -1 && echo "✓ Seqtk installed" || echo "✗ Seqtk missing"; \
		samtools --version 2>/dev/null | head -1 && echo "✓ Samtools installed" || echo "✗ Samtools missing"; \
		python -c "import Bio; print(\"✓ BioPython installed\")" 2>/dev/null || echo "✗ BioPython missing"; \
	'

# Run linting
lint:
	@echo "$(GREEN)Running shellcheck on scripts...$(NC)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(SCRIPTS_DIR)/*.sh; \
		echo "$(GREEN)Shellcheck completed$(NC)"; \
	else \
		echo "$(YELLOW)Warning: shellcheck not found. Install with: apt-get install shellcheck$(NC)"; \
	fi
	@echo "$(GREEN)Checking Python syntax...$(NC)"
	@conda run -n $(CONDA_ENV) python -m py_compile $(SCRIPTS_DIR)/assembly_stats.py
	@echo "$(GREEN)Python syntax check completed$(NC)"

# Create test data
create-test-data:
	@echo "$(GREEN)Creating test data...$(NC)"
	@mkdir -p $(TEST_DATA_DIR)
	@conda run -n $(CONDA_ENV) python -c " \
import random; \
from Bio import SeqIO; \
from Bio.SeqRecord import SeqRecord; \
from Bio.Seq import Seq; \
random.seed(42); \
records = []; \
for i in range(200): \
    seq = ''.join(random.choices('ATCG', k=random.randint(2000, 8000))); \
    qual = [random.randint(20, 40) for _ in range(len(seq))]; \
    record = SeqRecord(Seq(seq), id=f'read_{i:04d}', description='test_read'); \
    record.letter_annotations['phred_quality'] = qual; \
    records.append(record); \
SeqIO.write(records, '$(TEST_DATA_DIR)/test_reads.fastq', 'fastq'); \
print('Created test_reads.fastq with 200 reads') \
	"
	@conda run -n $(CONDA_ENV) python -c " \
import random; \
from Bio import SeqIO; \
from Bio.SeqRecord import SeqRecord; \
from Bio.Seq import Seq; \
random.seed(42); \
records = []; \
for i in range(20): \
    seq = ''.join(random.choices('ATCG', k=random.randint(10000, 50000))); \
    record = SeqRecord(Seq(seq), id=f'contig_{i:03d}', description='test_contig'); \
    records.append(record); \
SeqIO.write(records, '$(TEST_DATA_DIR)/test_assembly.fasta', 'fasta'); \
print('Created test_assembly.fasta with 20 contigs') \
	"

# Run tests
test: create-test-data
	@echo "$(GREEN)Running tests...$(NC)"
	@echo "$(YELLOW)Testing script syntax...$(NC)"
	@bash -n $(SCRIPTS_DIR)/flye_assembly.sh
	@bash -n $(SCRIPTS_DIR)/batch_assembly.sh
	@bash -n $(SCRIPTS_DIR)/qc_reads.sh
	@conda run -n $(CONDA_ENV) python -m py_compile $(SCRIPTS_DIR)/assembly_stats.py
	@echo "$(GREEN)✓ Syntax checks passed$(NC)"
	
	@echo "$(YELLOW)Testing QC script...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/qc_reads.sh
	@conda run -n $(CONDA_ENV) ./$(SCRIPTS_DIR)/qc_reads.sh \
		-i $(TEST_DATA_DIR)/test_reads.fastq \
		-o $(TEST_DATA_DIR)/filtered_reads.fastq \
		-t nanopore --min-length 1500
	@echo "$(GREEN)✓ QC script test passed$(NC)"
	
	@echo "$(YELLOW)Testing assembly stats script...$(NC)"
	@conda run -n $(CONDA_ENV) python $(SCRIPTS_DIR)/assembly_stats.py \
		-i $(TEST_DATA_DIR)/test_assembly.fasta \
		--json $(TEST_DATA_DIR)/stats.json \
		--tsv $(TEST_DATA_DIR)/stats.tsv
	@echo "$(GREEN)✓ Assembly stats script test passed$(NC)"
	
	@echo "$(GREEN)All tests passed!$(NC)"

# Create example configuration and run demo
example: create-test-data
	@echo "$(GREEN)Creating example configuration...$(NC)"
	@mkdir -p examples
	@echo -e "# Example configuration for demo\ntest_sample\t$(PWD)/$(TEST_DATA_DIR)/test_reads.fastq\tnanopore\t5m" > examples/demo_samples.txt
	@echo "$(GREEN)Example configuration created: examples/demo_samples.txt$(NC)"
	@echo "$(YELLOW)To run the example:$(NC)"
	@echo "  conda activate $(CONDA_ENV)"
	@echo "  ./$(SCRIPTS_DIR)/batch_assembly.sh -c examples/demo_samples.txt -o examples/results/"
	@echo ""
	@echo "$(YELLOW)Or for a single assembly:$(NC)"
	@echo "  ./$(SCRIPTS_DIR)/flye_assembly.sh -i $(TEST_DATA_DIR)/test_reads.fastq -o examples/single_assembly -t nanopore -g 5m"

# Clean up temporary files
clean:
	@echo "$(GREEN)Cleaning up...$(NC)"
	@rm -rf $(TEST_DATA_DIR)
	@rm -rf examples/results
	@rm -rf examples/single_assembly
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -delete
	@echo "$(GREEN)Cleanup completed$(NC)"

# Remove conda environment
uninstall:
	@echo "$(RED)Removing conda environment...$(NC)"
	@conda env remove -n $(CONDA_ENV) -y 2>/dev/null || true
	@echo "$(GREEN)Environment removed$(NC)"

# Show project structure
structure:
	@echo "$(GREEN)Project structure:$(NC)"
	@tree -I '__pycache__|*.pyc|test_data|examples' . || find . -type f -name "*.sh" -o -name "*.py" -o -name "*.yml" -o -name "*.txt" -o -name "*.md" | grep -v test_data | sort

# Format code
format:
	@echo "$(GREEN)Formatting Python code...$(NC)"
	@conda run -n $(CONDA_ENV) black $(SCRIPTS_DIR)/assembly_stats.py || echo "$(YELLOW)Black not installed, skipping formatting$(NC)"

# Show usage statistics
stats:
	@echo "$(GREEN)Project statistics:$(NC)"
	@echo "Shell scripts: $$(find $(SCRIPTS_DIR) -name "*.sh" | wc -l)"
	@echo "Python scripts: $$(find $(SCRIPTS_DIR) -name "*.py" | wc -l)"
	@echo "Total lines of code: $$(find $(SCRIPTS_DIR) -name "*.sh" -o -name "*.py" | xargs wc -l | tail -1)"
	@echo "Configuration files: $$(find $(CONFIG_DIR) -name "*.txt" | wc -l)"

# Quick start guide
quickstart:
	@echo "$(GREEN)Quick Start Guide$(NC)"
	@echo "=================="
	@echo ""
	@echo "1. $(YELLOW)Install dependencies:$(NC)"
	@echo "   make install"
	@echo ""
	@echo "2. $(YELLOW)Activate environment:$(NC)"
	@echo "   conda activate $(CONDA_ENV)"
	@echo ""
	@echo "3. $(YELLOW)Run tests:$(NC)"
	@echo "   make test"
	@echo ""
	@echo "4. $(YELLOW)Create example data:$(NC)"
	@echo "   make example"
	@echo ""
	@echo "5. $(YELLOW)Run single assembly:$(NC)"
	@echo "   ./scripts/flye_assembly.sh -i reads.fastq -o output -t nanopore -g 5m"
	@echo ""
	@echo "6. $(YELLOW)Run batch assembly:$(NC)"
	@echo "   ./scripts/batch_assembly.sh -c config/samples.txt -o results/"
	@echo ""
	@echo "$(GREEN)For more information, see README.md$(NC)"
