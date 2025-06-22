#!/bin/bash

# Read Quality Control Script
# Author: Your Name
# Version: 1.0
# License: MIT

set -euo pipefail

# Default values
INPUT=""
OUTPUT=""
MIN_LENGTH=1000
MAX_LENGTH=100000
MIN_QUALITY=7
THREADS=$(nproc)
READ_TYPE=""

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
Read Quality Control Script

USAGE:
    $0 [OPTIONS]

REQUIRED OPTIONS:
    -i, --input FILE        Input FASTQ file
    -o, --output FILE       Output filtered FASTQ file
    -t, --type TYPE         Read type: nanopore, pacbio, pacbio-hifi

OPTIONAL PARAMETERS:
    --min-length INT        Minimum read length (default: 1000)
    --max-length INT        Maximum read length (default: 100000)
    --min-quality FLOAT     Minimum average quality score (default: 7)
    -T, --threads INT       Number of threads (default: all available)
    
HELP:
    -h, --help             Show this help message

EXAMPLES:
    # Basic filtering for Nanopore reads
    $0 -i reads.fastq -o filtered.fastq -t nanopore

    # Custom length and quality filters
    $0 -i reads.fastq -o filtered.fastq -t pacbio --min-length 5000 --min-quality 10

    # PacBio HiFi with stricter filters
    $0 -i reads.fastq -o filtered.fastq -t pacbio-hifi --min-length 10000 --min-quality 15
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
    
    check_command "seqtk"
    
    if command -v fastqc &> /dev/null; then
        FASTQC_AVAILABLE=true
    else
        FASTQC_AVAILABLE=false
        print_warning "FastQC not found. Read quality assessment will be limited."
    fi
    
    if command -v NanoPlot &> /dev/null; then
        NANOPLOT_AVAILABLE=true
    else
        NANOPLOT_AVAILABLE=false
        print_warning "NanoPlot not found. Nanopore-specific QC will be skipped."
    fi
    
    print_status "Dependencies checked."
}

# Function to get initial read statistics
get_initial_stats() {
    print_status "Analyzing input reads..."
    
    local stats_file="${OUTPUT%.fastq}_initial_stats.txt"
    
    {
        echo "=== INITIAL READ STATISTICS ==="
        echo "File: $INPUT"
        echo "Date: $(date)"
        echo ""
        
        # Get basic statistics using seqtk
        seqtk fqchk "$INPUT" | head -5
        
        echo ""
        echo "Read length and quality distribution:"
        seqtk seq "$INPUT" | awk '
        NR%4==1 {read_count++}
        NR%4==2 {
            length = length($0)
            total_length += length
            lengths[read_count] = length
            if (length > max_length) max_length = length
            if (min_length == 0 || length < min_length) min_length = length
        }
        NR%4==4 {
            qual_sum = 0
            for (i = 1; i <= length($0); i++) {
                qual_sum += (ord(substr($0, i, 1)) - 33)
            }
            avg_qual = qual_sum / length($0)
            total_quality += avg_qual
        }
        function ord(c) {
            return sprintf("%c", c) + 0
        }
        END {
            print "Total reads: " read_count
            print "Total bases: " total_length
            print "Average read length: " (read_count > 0 ? total_length/read_count : 0)
            print "Min read length: " min_length
            print "Max read length: " max_length
            print "Average quality: " (read_count > 0 ? total_quality/read_count : 0)
        }'
    } > "$stats_file"
    
    print_info "Initial statistics saved to: $stats_file"
}

# Function to set read-type specific defaults
set_read_type_defaults() {
    case "$READ_TYPE" in
        nanopore)
            if [[ $MIN_LENGTH -eq 1000 ]]; then MIN_LENGTH=1000; fi
            if [[ $MAX_LENGTH -eq 100000 ]]; then MAX_LENGTH=100000; fi
            if [[ $MIN_QUALITY -eq 7 ]]; then MIN_QUALITY=7; fi
            ;;
        pacbio)
            if [[ $MIN_LENGTH -eq 1000 ]]; then MIN_LENGTH=1000; fi
            if [[ $MAX_LENGTH -eq 100000 ]]; then MAX_LENGTH=50000; fi
            if [[ $MIN_QUALITY -eq 7 ]]; then MIN_QUALITY=9; fi
            ;;
        pacbio-hifi)
            if [[ $MIN_LENGTH -eq 1000 ]]; then MIN_LENGTH=5000; fi
            if [[ $MAX_LENGTH -eq 100000 ]]; then MAX_LENGTH=25000; fi
            if [[ $MIN_QUALITY -eq 7 ]]; then MIN_QUALITY=15; fi
            ;;
    esac
    
    print_info "Read type: $READ_TYPE"
    print_info "Length filter: $MIN_LENGTH - $MAX_LENGTH bp"
    print_info "Quality filter: >= $MIN_QUALITY"
}

# Function to filter reads by length
filter_by_length() {
    local input_file="$1"
    local output_file="$2"
    
    print_status "Filtering reads by length ($MIN_LENGTH - $MAX_LENGTH bp)..."
    
    seqtk seq -L "$MIN_LENGTH" "$input_file" | \
    awk -v max_len="$MAX_LENGTH" '
    BEGIN { RS="\n"; FS="" }
    NR%4==1 { header=$0 }
    NR%4==2 { 
        sequence=$0
        if (length(sequence) <= max_len) {
            print header
            print sequence
            getline; print $0  # quality header
            getline; print $0  # quality scores
        } else {
            getline; getline  # skip quality header and scores
        }
    }' > "$output_file"
    
    local filtered_count=$(grep -c "^@" "$output_file" || echo "0")
    print_info "Reads after length filtering: $filtered_count"
}

# Function to filter reads by quality
filter_by_quality() {
    local input_file="$1"
    local output_file="$2"
    
    print_status "Filtering reads by average quality (>= $MIN_QUALITY)..."
    
    python3 << EOF
import sys
from Bio import SeqIO

def calculate_avg_quality(quality_scores):
    """Calculate average quality score from ASCII quality string."""
    return sum(ord(q) - 33 for q in quality_scores) / len(quality_scores)

input_file = "$input_file"
output_file = "$output_file"
min_quality = $MIN_QUALITY

with open(output_file, 'w') as out_handle:
    for record in SeqIO.parse(input_file, "fastq"):
        avg_qual = calculate_avg_quality(record.letter_annotations["phred_quality"])
        if avg_qual >= min_quality:
            SeqIO.write(record, out_handle, "fastq")

print(f"Quality filtering completed.")
EOF
    
    local filtered_count=$(grep -c "^@" "$output_file" || echo "0")
    print_info "Reads after quality filtering: $filtered_count"
}

# Function to run FastQC
run_fastqc() {
    if [[ "$FASTQC_AVAILABLE" != true ]]; then
        return 0
    fi
    
    local input_file="$1"
    local output_dir="${OUTPUT%.fastq}_qc"
    
    print_status "Running FastQC analysis..."
    
    mkdir -p "$output_dir"
    fastqc "$input_file" -o "$output_dir" -t "$THREADS" --quiet
    
    print_info "FastQC report saved to: $output_dir"
}

# Function to run NanoPlot (for Nanopore data)
run_nanoplot() {
    if [[ "$NANOPLOT_AVAILABLE" != true ]] || [[ "$READ_TYPE" != "nanopore" ]]; then
        return 0
    fi
    
    local input_file="$1"
    local output_dir="${OUTPUT%.fastq}_nanoplot"
    
    print_status "Running NanoPlot analysis..."
    
    mkdir -p "$output_dir"
    NanoPlot --fastq "$input_file" --outdir "$output_dir" --threads "$THREADS" --plots dot --legacy hex
    
    print_info "NanoPlot report saved to: $output_dir"
}

# Function to get final statistics
get_final_stats() {
    print_status "Generating final statistics..."
    
    local stats_file="${OUTPUT%.fastq}_final_stats.txt"
    
    {
        echo "=== FINAL READ STATISTICS ==="
        echo "File: $OUTPUT"
        echo "Date: $(date)"
        echo ""
        echo "Filtering parameters:"
        echo "  Read type: $READ_TYPE"
        echo "  Min length: $MIN_LENGTH bp"
        echo "  Max length: $MAX_LENGTH bp"
        echo "  Min quality: $MIN_QUALITY"
        echo ""
        
        # Get basic statistics using seqtk
        seqtk fqchk "$OUTPUT" | head -5
        
        echo ""
        echo "Read length and quality distribution:"
        seqtk seq "$OUTPUT" | awk '
        NR%4==1 {read_count++}
        NR%4==2 {
            length = length($0)
            total_length += length
            lengths[read_count] = length
            if (length > max_length) max_length = length
            if (min_length == 0 || length < min_length) min_length = length
        }
        NR%4==4 {
            qual_sum = 0
            for (i = 1; i <= length($0); i++) {
                qual_sum += (ord(substr($0, i, 1)) - 33)
            }
            avg_qual = qual_sum / length($0)
            total_quality += avg_qual
        }
        function ord(c) {
            return sprintf("%c", c) + 0
        }
        END {
            print "Total reads: " read_count
            print "Total bases: " total_length
            print "Average read length: " (read_count > 0 ? total_length/read_count : 0)
            print "Min read length: " min_length
            print "Max read length: " max_length
            print "Average quality: " (read_count > 0 ? total_quality/read_count : 0)
        }'
    } > "$stats_file"
    
    print_info "Final statistics saved to: $stats_file"
}

# Function to create summary report
create_summary_report() {
    print_status "Creating summary report..."
    
    local summary_file="${OUTPUT%.fastq}_qc_summary.txt"
    local initial_stats="${OUTPUT%.fastq}_initial_stats.txt"
    local final_stats="${OUTPUT%.fastq}_final_stats.txt"
    
    {
        echo "=================================="
        echo "   READ QC SUMMARY REPORT         "
        echo "=================================="
        echo ""
        echo "Processing Information:"
        echo "  Input file: $INPUT"
        echo "  Output file: $OUTPUT"
        echo "  Read type: $READ_TYPE"
        echo "  Date: $(date)"
        echo ""
        echo "Filtering Parameters:"
        echo "  Min length: $MIN_LENGTH bp"
        echo "  Max length: $MAX_LENGTH bp"
        echo "  Min quality: $MIN_QUALITY"
        echo ""
        
        if [[ -f "$initial_stats" ]]; then
            echo "BEFORE FILTERING:"
            echo "=================="
            grep -E "(Total reads|Total bases|Average read length|Average quality)" "$initial_stats" | sed 's/^/  /'
            echo ""
        fi
        
        if [[ -f "$final_stats" ]]; then
            echo "AFTER FILTERING:"
            echo "================"
            grep -E "(Total reads|Total bases|Average read length|Average quality)" "$final_stats" | sed 's/^/  /'
            echo ""
        fi
        
        echo "Quality Control Reports:"
        if [[ "$FASTQC_AVAILABLE" == true ]]; then
            echo "  FastQC report: ${OUTPUT%.fastq}_qc/"
        fi
        if [[ "$NANOPLOT_AVAILABLE" == true ]] && [[ "$READ_TYPE" == "nanopore" ]]; then
            echo "  NanoPlot report: ${OUTPUT%.fastq}_nanoplot/"
        fi
        
    } > "$summary_file"
    
    print_status "Summary report created: $summary_file"
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
        --min-length)
            MIN_LENGTH="$2"
            shift 2
            ;;
        --max-length)
            MAX_LENGTH="$2"
            shift 2
            ;;
        --min-quality)
            MIN_QUALITY="$2"
            shift 2
            ;;
        -T|--threads)
            THREADS="$2"
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

# Validate input file
if [[ ! -f "$INPUT" ]]; then
    print_error "Input file '$INPUT' does not exist."
    exit 1
fi

# Validate read type
case "$READ_TYPE" in
    nanopore|pacbio|pacbio-hifi)
        ;;
    *)
        print_error "Invalid read type '$READ_TYPE'. Must be: nanopore, pacbio, or pacbio-hifi"
        exit 1
        ;;
esac

# Main execution
main() {
    print_status "Starting read quality control pipeline..."
    print_info "Input: $INPUT"
    print_info "Output: $OUTPUT"
    
    check_dependencies
    set_read_type_defaults
    get_initial_stats
    
    # Create temporary files for filtering steps
    local temp_length="${OUTPUT%.fastq}_temp_length.fastq"
    local temp_quality="${OUTPUT%.fastq}_temp_quality.fastq"
    
    # Filter by length first
    filter_by_length "$INPUT" "$temp_length"
    
    # Then filter by quality
    filter_by_quality "$temp_length" "$OUTPUT"
    
    # Clean up temporary files
    rm -f "$temp_length"
    
    # Generate final statistics
    get_final_stats
    
    # Run quality control tools
    run_fastqc "$OUTPUT"
    run_nanoplot "$OUTPUT"
    
    # Create summary report
    create_summary_report
    
    print_status "Read QC pipeline completed successfully!"
    print_info "Filtered reads: $OUTPUT"
    print_info "Summary report: ${OUTPUT%.fastq}_qc_summary.txt"
}

# Run main function
main "$@"
