#!/bin/bash

# Flye Genome Assembly Script
# Author: Your Name
# Version: 1.0
# License: MIT

set -euo pipefail

# Default values
INPUT=""
OUTPUT=""
READ_TYPE=""
GENOME_SIZE=""
THREADS=$(nproc)
POLISH=false
META=false
PLASMIDS=false
RESUME=false
MIN_OVERLAP=5000
ITERATIONS=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

print_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to show help
show_help() {
    cat << EOF
Flye Genome Assembly Script

USAGE:
    $0 [OPTIONS]

REQUIRED OPTIONS:
    -i, --input FILE        Input FASTQ file with long reads
    -o, --output DIR        Output directory
    -t, --type TYPE         Read type: nanopore, pacbio, pacbio-hifi

OPTIONAL PARAMETERS:
    -g, --genome-size SIZE  Estimated genome size (e.g., 5m, 2.3g)
    -p, --polish           Enable polishing with Racon/Medaka
    -m, --meta             Enable metagenome mode
    -s, --plasmids         Enable plasmid recovery
    -r, --resume           Resume interrupted assembly
    -T, --threads INT      Number of threads (default: all available)
    --min-overlap INT      Minimum overlap length (default: 5000)
    --iterations INT       Number of polishing iterations (default: 1)
    
HELP:
    -h, --help             Show this help message

EXAMPLES:
    # Basic bacterial genome assembly
    $0 -i reads.fastq -o output -t nanopore -g 5m

    # Assembly with polishing
    $0 -i reads.fastq -o output -t nanopore -g 5m -p

    # Metagenome assembly
    $0 -i reads.fastq -o output -t nanopore -m

    # PacBio HiFi assembly
    $0 -i reads.fastq -o output -t pacbio-hifi -g 3g
EOF
}

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "Required command '$1' not found. Please install it first."
        exit 1
    fi
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    check_command "flye"
    
    if [[ "$POLISH" == true ]]; then
        check_command "minimap2"
        check_command "racon"
        if [[ "$READ_TYPE" == "nanopore" ]]; then
            check_command "medaka"
        fi
    fi
    
    check_command "seqtk"
    
    if command -v quast &> /dev/null; then
        QUAST_AVAILABLE=true
    else
        QUAST_AVAILABLE=false
        print_warning "QUAST not found. Assembly quality assessment will be skipped."
    fi
    
    print_status "All required dependencies found."
}

# Function to validate input parameters
validate_parameters() {
    print_status "Validating parameters..."
    
    # Check input file
    if [[ ! -f "$INPUT" ]]; then
        print_error "Input file '$INPUT' does not exist."
        exit 1
    fi
    
    # Check read type
    case "$READ_TYPE" in
        nanopore|pacbio|pacbio-hifi)
            ;;
        *)
            print_error "Invalid read type '$READ_TYPE'. Must be: nanopore, pacbio, or pacbio-hifi"
            exit 1
            ;;
    esac
    
    # Validate genome size format if provided
    if [[ -n "$GENOME_SIZE" ]]; then
        if ! [[ "$GENOME_SIZE" =~ ^[0-9]+(\.[0-9]+)?[kmgtKMGT]?$ ]]; then
            print_error "Invalid genome size format '$GENOME_SIZE'. Use format like: 5m, 2.3g, 100k"
            exit 1
        fi
    fi
    
    # Check threads
    if [[ "$THREADS" -lt 1 ]]; then
        print_error "Number of threads must be at least 1."
        exit 1
    fi
    
    print_status "Parameters validated successfully."
}

# Function to create output directory structure
create_output_structure() {
    print_status "Creating output directory structure..."
    
    mkdir -p "$OUTPUT"/{assembly,logs,qc,intermediate/{polishing,temp}}
    
    # Create log file
    LOG_FILE="$OUTPUT/logs/flye.log"
    touch "$LOG_FILE"
    
    print_status "Output structure created: $OUTPUT"
}

# Function to get read statistics
get_read_stats() {
    print_status "Analyzing input reads..."
    
    local stats_file="$OUTPUT/qc/read_stats.txt"
    
    # Get basic statistics
    {
        echo "=== READ STATISTICS ==="
        echo "File: $INPUT"
        echo "Date: $(date)"
        echo ""
        
        # Count reads and calculate N50
        seqtk fqchk "$INPUT" | head -3
        
        echo ""
        echo "Read length distribution:"
        seqtk seq "$INPUT" | awk 'NR%4==2{print length($0)}' | sort -n | \
        awk '{
            len[NR]=$1; total+=$1
        } 
        END {
            print "Total reads: " NR
            print "Total bases: " total
            print "Average length: " total/NR
            print "Median length: " len[int(NR/2)]
            print "Min length: " len[1]
            print "Max length: " len[NR]
        }'
    } > "$stats_file"
    
    print_info "Read statistics saved to: $stats_file"
}

# Function to run Flye assembly
run_flye_assembly() {
    print_status "Starting Flye assembly..."
    
    local flye_cmd="flye"
    
    # Add read type parameter
    case "$READ_TYPE" in
        nanopore)
            flye_cmd+=" --nano-raw $INPUT"
            ;;
        pacbio)
            flye_cmd+=" --pacbio-raw $INPUT"
            ;;
        pacbio-hifi)
            flye_cmd+=" --pacbio-hifi $INPUT"
            ;;
    esac
    
    # Add output directory
    flye_cmd+=" --out-dir $OUTPUT/intermediate/flye_output"
    
    # Add genome size if provided
    if [[ -n "$GENOME_SIZE" ]]; then
        flye_cmd+=" --genome-size $GENOME_SIZE"
    fi
    
    # Add meta mode if enabled
    if [[ "$META" == true ]]; then
        flye_cmd+=" --meta"
    fi
    
    # Add plasmid recovery if enabled
    if [[ "$PLASMIDS" == true ]]; then
        flye_cmd+=" --plasmids"
    fi
    
    # Add resume if enabled
    if [[ "$RESUME" == true ]]; then
        flye_cmd+=" --resume"
    fi
    
    # Add threads
    flye_cmd+=" --threads $THREADS"
    
    # Add minimum overlap
    flye_cmd+=" --min-overlap $MIN_OVERLAP"
    
    print_info "Running command: $flye_cmd"
    
    # Run Flye and capture output
    if eval "$flye_cmd" 2>&1 | tee -a "$LOG_FILE"; then
        print_status "Flye assembly completed successfully."
    else
        print_error "Flye assembly failed. Check log file: $LOG_FILE"
        exit 1
    fi
    
    # Copy results to final location
    if [[ -f "$OUTPUT/intermediate/flye_output/assembly.fasta" ]]; then
        cp "$OUTPUT/intermediate/flye_output/assembly.fasta" "$OUTPUT/assembly/"
        cp "$OUTPUT/intermediate/flye_output/assembly_info.txt" "$OUTPUT/assembly/"
        cp "$OUTPUT/intermediate/flye_output/assembly_graph.gfa" "$OUTPUT/assembly/"
        print_status "Assembly files copied to output directory."
    else
        print_error "Assembly output not found. Check Flye logs."
        exit 1
    fi
}

# Function to run polishing
run_polishing() {
    if [[ "$POLISH" != true ]]; then
        return 0
    fi
    
    print_status "Starting polishing pipeline..."
    
    local assembly="$OUTPUT/assembly/assembly.fasta"
    local polished_assembly="$assembly"
    local polish_log="$OUTPUT/logs/polishing.log"
    
    for ((i=1; i<=ITERATIONS; i++)); do
        print_info "Polishing iteration $i/$ITERATIONS"
        
        local current_assembly="$polished_assembly"
        local iteration_dir="$OUTPUT/intermediate/polishing/iteration_$i"
        mkdir -p "$iteration_dir"
        
        # Map reads to assembly
        print_info "Mapping reads to assembly..."
        minimap2 -ax map-ont -t "$THREADS" "$current_assembly" "$INPUT" > "$iteration_dir/mapped.sam" 2>> "$polish_log"
        
        # Run Racon
        print_info "Running Racon polishing..."
        racon -t "$THREADS" "$INPUT" "$iteration_dir/mapped.sam" "$current_assembly" > "$iteration_dir/racon_polished.fasta" 2>> "$polish_log"
        
        polished_assembly="$iteration_dir/racon_polished.fasta"
        
        # Run Medaka for Nanopore data
        if [[ "$READ_TYPE" == "nanopore" ]]; then
            print_info "Running Medaka polishing..."
            medaka_consensus -i "$INPUT" -d "$polished_assembly" -o "$iteration_dir/medaka_output" -t "$THREADS" >> "$polish_log" 2>&1
            polished_assembly="$iteration_dir/medaka_output/consensus.fasta"
        fi
    done
    
    # Copy final polished assembly
    cp "$polished_assembly" "$OUTPUT/assembly/assembly_polished.fasta"
    print_status "Polishing completed. Final assembly: $OUTPUT/assembly/assembly_polished.fasta"
}

# Function to run quality assessment
run_quality_assessment() {
    print_status "Running quality assessment..."
    
    local assembly_file="$OUTPUT/assembly/assembly.fasta"
    if [[ -f "$OUTPUT/assembly/assembly_polished.fasta" ]]; then
        assembly_file="$OUTPUT/assembly/assembly_polished.fasta"
    fi
    
    # Basic assembly statistics
    {
        echo "=== ASSEMBLY STATISTICS ==="
        echo "File: $assembly_file"
        echo "Date: $(date)"
        echo ""
        
        # Get basic stats using seqtk
        seqtk comp "$assembly_file" | awk '{
            total_len += $2
            gc_content += $3 + $4
            num_contigs++
            lengths[num_contigs] = $2
        }
        END {
            # Sort lengths for N50 calculation
            asort(lengths)
            
            # Calculate N50
            cumulative = 0
            for (i = num_contigs; i >= 1; i--) {
                cumulative += lengths[i]
                if (cumulative >= total_len/2) {
                    n50 = lengths[i]
                    break
                }
            }
            
            print "Number of contigs: " num_contigs
            print "Total length: " total_len " bp"
            print "Average contig length: " int(total_len/num_contigs) " bp"
            print "Longest contig: " lengths[num_contigs] " bp"
            print "N50: " n50 " bp"
            print "GC content: " sprintf("%.2f", (gc_content/total_len)*100) "%"
        }'
    } > "$OUTPUT/qc/assembly_stats.txt"
    
    # Run QUAST if available
    if [[ "$QUAST_AVAILABLE" == true ]]; then
        print_info "Running QUAST quality assessment..."
        quast.py "$assembly_file" -o "$OUTPUT/qc/quast_report" --threads "$THREADS" >> "$LOG_FILE" 2>&1
    fi
    
    print_status "Quality assessment completed."
}

# Function to generate summary report
generate_summary() {
    print_status "Generating summary report..."
    
    local summary_file="$OUTPUT/assembly_summary.txt"
    
    {
        echo "=================================="
        echo "   FLYE ASSEMBLY SUMMARY REPORT   "
        echo "=================================="
        echo ""
        echo "Run Information:"
        echo "  Date: $(date)"
        echo "  Input file: $INPUT"
        echo "  Output directory: $OUTPUT"
        echo "  Read type: $READ_TYPE"
        echo "  Genome size estimate: ${GENOME_SIZE:-'Not specified'}"
        echo "  Threads used: $THREADS"
        echo "  Polishing: $POLISH"
        echo "  Meta mode: $META"
        echo "  Plasmid recovery: $PLASMIDS"
        echo ""
        
        if [[ -f "$OUTPUT/qc/assembly_stats.txt" ]]; then
            cat "$OUTPUT/qc/assembly_stats.txt"
        fi
        
        echo ""
        echo "Output Files:"
        echo "  Primary assembly: assembly/assembly.fasta"
        if [[ -f "$OUTPUT/assembly/assembly_polished.fasta" ]]; then
            echo "  Polished assembly: assembly/assembly_polished.fasta"
        fi
        echo "  Assembly info: assembly/assembly_info.txt"
        echo "  Assembly graph: assembly/assembly_graph.gfa"
        echo "  Logs: logs/"
        echo "  Quality reports: qc/"
        
    } > "$summary_file"
    
    print_status "Summary report generated: $summary_file"
}

# Function to cleanup intermediate files
cleanup_intermediate() {
    print_status "Cleaning up intermediate files..."
    
    # Remove temporary files but keep important intermediate results
    if [[ -d "$OUTPUT/intermediate/temp" ]]; then
        rm -rf "$OUTPUT/intermediate/temp"/*
    fi
    
    # Compress large intermediate files
    if command -v gzip &> /dev/null; then
        find "$OUTPUT/intermediate" -name "*.sam" -exec gzip {} \;
    fi
    
    print_status "Cleanup completed."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -t|--type)
            READ_TYPE="$2"
            shift 2
            ;;
        -g|--genome-size)
            GENOME_SIZE="$2"
            shift 2
            ;;
        -p|--polish)
            POLISH=true
            shift
            ;;
        -m|--meta)
            META=true
            shift
            ;;
        -s|--plasmids)
            PLASMIDS=true
            shift
            ;;
        -r|--resume)
            RESUME=true
            shift
            ;;
        -T|--threads)
            THREADS="$2"
            shift 2
            ;;
        --min-overlap)
            MIN_OVERLAP="$2"
            shift 2
            ;;
        --iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check required parameters
if [[ -z "$INPUT" || -z "$OUTPUT" || -z "$READ_TYPE" ]]; then
    print_error "Missing required parameters."
    show_help
    exit 1
fi

# Main execution
main() {
    print_status "Starting Flye genome assembly pipeline..."
    print_info "Input: $INPUT"
    print_info "Output: $OUTPUT"
    print_info "Read type: $READ_TYPE"
    print_info "Threads: $THREADS"
    
    check_dependencies
    validate_parameters
    create_output_structure
    get_read_stats
    run_flye_assembly
    run_polishing
    run_quality_assessment
    generate_summary
    cleanup_intermediate
    
    print_status "Assembly pipeline completed successfully!"
    print_info "Results are available in: $OUTPUT"
    print_info "Summary report: $OUTPUT/assembly_summary.txt"
}

# Run main function
main "$@"
