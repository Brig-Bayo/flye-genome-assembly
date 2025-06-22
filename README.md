
# Flye Genome Assembly Pipeline

A comprehensive pipeline for genome assembly using Flye assembler with support for long-read sequencing data (PacBio and Oxford Nanopore).

## Overview

This repository contains scripts and tools for performing genome assembly using Flye, including preprocessing, assembly, and post-assembly quality assessment.

## Features

- **Automated Flye assembly** with configurable parameters
- **Quality control** and preprocessing of long reads
- **Assembly statistics** and quality assessment
- **Polishing pipeline** for improved accuracy
- **Multi-sample batch processing** support
- **Comprehensive logging** and error handling

## Requirements

### Software Dependencies

- [Flye](https://github.com/fenderglass/Flye) (>= 2.9)
- [Minimap2](https://github.com/lh3/minimap2) (for polishing)
- [Racon](https://github.com/lbcb-sci/racon) (for polishing)
- [Medaka](https://github.com/nanoporetech/medaka) (for Nanopore polishing)
- [QUAST](https://github.com/ablab/quast) (for assembly evaluation)
- [Seqtk](https://github.com/lh3/seqtk) (for sequence processing)
- [Samtools](https://github.com/samtools/samtools) (>= 1.10)

### System Requirements

- Linux/macOS operating system
- Minimum 8GB RAM (32GB+ recommended for large genomes)
- Sufficient disk space (3-5x the size of input data)

## Installation

### Using Conda (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourusername/flye-genome-assembly.git
cd flye-genome-assembly

# Create conda environment
conda env create -f environment.yml
conda activate flye-assembly
```

### Manual Installation

```bash
# Install dependencies manually
conda install -c bioconda flye minimap2 racon medaka quast seqtk samtools
# or use your preferred package manager
```

## Quick Start

### Single Sample Assembly

```bash
# Basic assembly
./scripts/flye_assembly.sh -i input_reads.fastq -o output_dir -t nanopore

# With polishing
./scripts/flye_assembly.sh -i input_reads.fastq -o output_dir -t nanopore -p
```

### Batch Processing

```bash
# Process multiple samples
./scripts/batch_assembly.sh -c config/samples.txt -o results/
```

## Usage

### Command Line Options

```bash
./scripts/flye_assembly.sh [OPTIONS]

Required:
  -i, --input FILE      Input FASTQ file with long reads
  -o, --output DIR      Output directory
  -t, --type TYPE       Read type: nanopore, pacbio, pacbio-hifi

Optional:
  -g, --genome-size SIZE    Estimated genome size (e.g., 5m, 2.3g)
  -p, --polish             Enable polishing with Racon/Medaka
  -m, --meta               Enable metagenome mode
  -s, --plasmids           Enable plasmid recovery
  -r, --resume             Resume interrupted assembly
  -T, --threads INT        Number of threads (default: all available)
  -h, --help               Show help message
```

### Configuration Files

Create a sample configuration file for batch processing:

```
# samples.txt
sample1	/path/to/sample1.fastq	nanopore	5m
sample2	/path/to/sample2.fastq	pacbio	12m
sample3	/path/to/sample3.fastq	pacbio-hifi	2.8g
```

## Output Structure

```
output_directory/
├── assembly/
│   ├── assembly.fasta          # Final assembly
│   ├── assembly_info.txt       # Assembly statistics
│   └── assembly_graph.gfa      # Assembly graph
├── logs/
│   ├── flye.log               # Flye assembly log
│   └── polishing.log          # Polishing log (if enabled)
├── qc/
│   ├── quast_report/          # QUAST quality assessment
│   └── assembly_stats.txt     # Basic statistics
└── intermediate/              # Intermediate files
    ├── polishing/
    └── temp/
```

## Examples

### Example 1: Bacterial Genome Assembly

```bash
# E. coli genome with Nanopore reads
./scripts/flye_assembly.sh \
  -i ecoli_nanopore.fastq \
  -o ecoli_assembly \
  -t nanopore \
  -g 5m \
  -p
```

### Example 2: Large Eukaryotic Genome

```bash
# Human genome with PacBio HiFi reads
./scripts/flye_assembly.sh \
  -i human_hifi.fastq \
  -o human_assembly \
  -t pacbio-hifi \
  -g 3.2g \
  -T 32
```

### Example 3: Metagenome Assembly

```bash
# Metagenomic sample
./scripts/flye_assembly.sh \
  -i metagenome.fastq \
  -o meta_assembly \
  -t nanopore \
  -m \
  -T 16
```

## Best Practices

1. **Quality Control**: Always check read quality before assembly
2. **Genome Size**: Provide accurate genome size estimates when possible
3. **Resources**: Ensure sufficient RAM and disk space
4. **Polishing**: Use polishing for higher accuracy, especially with Nanopore data
5. **Validation**: Run QUAST and other QC tools on final assemblies

## Troubleshooting

### Common Issues

1. **Out of Memory**: Reduce thread count or increase system RAM
2. **Disk Space**: Ensure 3-5x input data size is available
3. **Read Quality**: Filter low-quality reads if assembly fails
4. **Genome Size**: Check if estimated genome size is reasonable

### Getting Help

- Check the [Flye documentation](https://github.com/fenderglass/Flye)
- Review log files in the `logs/` directory
- Open an issue on GitHub

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Citation

If you use this pipeline in your research, please cite:

- **Flye**: Kolmogorov, M., Yuan, J., Lin, Y. et al. Assembly of long, error-prone reads using repeat graphs. Nat Biotechnol 37, 540–546 (2019).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Authors

- Your Name (https://github.com/Brig-Bayo)

## Acknowledgments

- Flye development team
- Bioinformatics community
- Contributors to this project
