# Bakta Docker Environment Setup Guide

This guide sets up a complete Bakta environment using Docker for bacterial genome annotation testing.

## Quick Start

1. **Complete Setup (Recommended)**
   ```bash
   make setup
   ```
   This will build the Docker image, download the light database (~1.3GB), and create sample data.

2. **Run Quick Test**
   ```bash
   make test-quick
   ```

3. **Run Full E. coli Test**
   ```bash
   make test-full
   ```

## Step-by-Step Setup

### 1. Build Docker Environment
```bash
make build
```

### 2. Download Database
Choose either light (faster, less comprehensive) or full (complete, slower):

```bash
# Light database (~1.3GB, faster download)
make download-db-light

# Full database (~32GB, comprehensive annotations)
make download-db-full
```

### 3. Create Test Data
```bash
# Small synthetic genome for quick testing
make create-sample-genome

# Real E. coli genome for comprehensive testing
make download-sample-genome
```

## Available Commands

### Setup & Management
- `make help` - Show all available commands
- `make status` - Check environment status
- `make build` - Build Docker image
- `make clean` - Remove Docker image and data
- `make rebuild` - Clean and rebuild

### Database Management
- `make download-db-light` - Download light database (1.3GB)
- `make download-db-full` - Download full database (31.9GB)
- `make check-db` - Check database installation status

### Testing
- `make test-install` - Verify Bakta installation
- `make test-quick` - Quick test with synthetic genome
- `make test-full` - Full test with E. coli genome
- `make interactive` - Start interactive container session

### Data Management
- `make create-sample-genome` - Create small test genome
- `make download-sample-genome` - Download E. coli reference genome

## Directory Structure

```
bakta/
├── Dockerfile              # Docker environment
├── Makefile                # Automation commands
├── environment.yml         # Conda dependencies
└── data/
    ├── db/                 # Database files
    │   └── db-light/       # Light database (after download)
    ├── test/               # Input genomes
    │   ├── test_genome.fasta
    │   └── ecoli_sample.fna
    └── output/             # Annotation results
```

## Database Information

### Light Database (~1.3GB)
- Streamlined version with UniRef50 clusters only
- Faster runtime, smaller storage requirement
- Good for testing and high-throughput analysis

### Full Database (~32GB)
- Complete UniRef100/90/50 protein clusters
- Most comprehensive annotations
- Best for detailed analysis and research

## Testing Examples

### Quick Test Output
After `make test-quick`, check `data/output/` for:
- `quick_test.gff3` - Feature annotations
- `quick_test.gbff` - GenBank format
- `quick_test.tsv` - Human-readable table
- `quick_test.json` - Machine-readable data

### Full Test Output
After `make test-full` with E. coli:
- Complete genome annotation (~4.6MB genome)
- All feature types: CDS, tRNA, rRNA, ncRNA, etc.
- Functional annotations and database cross-references

## Troubleshooting

### Database Download Issues
- Zenodo downloads can be slow (5-10 minutes for light DB)
- Check `make status` to see download progress
- Use `make check-db` to verify installation

### Container Issues
- Ensure Docker is running
- Try `make rebuild` to rebuild image from scratch
- Use `make interactive` to debug inside container

### Annotation Errors
- Verify database is fully downloaded and extracted
- Check input genome format (FASTA required)
- Use `make test-install` to verify Bakta installation

## Performance Notes

- Light database: ~30 seconds for small genomes
- Full database: 5-10 minutes for typical bacterial genomes
- Memory usage: 2-4GB RAM recommended
- Storage: 5GB minimum (light), 40GB minimum (full)

## Integration with Analysis Pipelines

The Docker setup can be integrated into larger bioinformatics workflows:

```bash
# Example: Annotate multiple genomes
for genome in *.fasta; do
    make test-quick SAMPLE_GENOME="$genome"
done

# Example: Use custom parameters
docker run --rm -v $(pwd)/data/db:/data/db \
    -v $(pwd)/input:/input -v $(pwd)/output:/output \
    --entrypoint="" bakta-test \
    bakta --db /data/db/db-light --output /output \
    --prefix custom_annotation --genus Escherichia --species coli \
    /input/genome.fasta
```

## Citation

If you use this Bakta setup in your research, please cite:

> Schwengers O., Jelonek L., Dieckmann M. A., Beyvers S., Blom J., Goesmann A. (2021).
> Bakta: rapid and standardized annotation of bacterial genomes via alignment-free sequence identification.
> Microbial Genomics, 7(11). https://doi.org/10.1099/mgen.0.000685