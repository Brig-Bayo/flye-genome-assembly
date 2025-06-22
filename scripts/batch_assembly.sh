#!/bin/bash

# Batch Flye Assembly Script
# Author: Brig-Bayo

set -euo pipefail

# Default values
CONFIG_FILE=""
OUTPUT_DIR=""
THREADS=$(nproc)
PARALLEL_JOBS=1
POLISH=false
RESUME=false

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
Batch Flye Assembly Script

USAGE:
    $0 [OPTIONS]

REQUIRED OPTIONS:
    -c, --config FILE       Configuration file with sample information
    -o, --output DIR        Output base directory

OPTIONAL PARAMETERS:
    -j, --jobs INT          Number of parallel jobs (default: 1)
    -T, --threads INT       Threads per job (default: all available)
    -p, --polish           Enable polishing for all samples
    -r, --resume           Resume interrupted assemblies
    
HELP:
    -h, --help             Show this help message

CONFIG FILE FORMAT:
    Tab-separated file with columns: sample_name, input_file, read_type, genome_size
    
    Example:
    sample1	/path/to/sample1.fastq	nanopore	5m
    sample2	/path/to/sample2.fastq	pacbio	12m
    sample3	/path/to/sample3.fastq	pacbio-hifi	2.8g

EXAMPLES:
    # Process all samples sequentially
    $0 -c samples.txt -o results/

    # Run 3 assemblies in parallel
    $0 -c samples.txt -o results/ -j 3

    # Enable polishing for all samples
    $0 -c samples.txt -o results/ -p
EOF
}

# Function to validate config file
validate_config() {
    print_status "Validating configuration file..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file '$CONFIG_FILE' does not exist."
        exit 1
    fi
    
    # Check if file is not empty
    if [[ ! -s "$CONFIG_FILE" ]]; then
        print_error "Configuration file '$CONFIG_FILE' is empty."
        exit 1
    fi
    
    # Validate format
    local line_num=0
    while IFS=$'\t' read -r sample_name input_file read_type genome_size || [[ -n "$sample_name" ]]; do
        ((line_num++))
        
        # Skip empty lines and comments
        if [[ -z "$sample_name" || "$sample_name" =~ ^#.* ]]; then
            continue
        fi
        
        # Check required fields
        if [[ -z "$sample_name" || -z "$input_file" || -z "$read_type" ]]; then
            print_error "Line $line_num: Missing required fields (sample_name, input_file, read_type)"
            exit 1
        fi
        
        # Check if input file exists
        if [[ ! -f "$input_file" ]]; then
            print_error "Line $line_num: Input file '$input_file' does not exist."
            exit 1
        fi
        
        # Validate read type
        case "$read_type" in
            nanopore|pacbio|pacbio-hifi)
                ;;
            *)
                print_error "Line $line_num: Invalid read type '$read_type'. Must be: nanopore, pacbio, or pacbio-hifi"
                exit 1
                ;;
        esac
        
        # Validate genome size format if provided
        if [[ -n "$genome_size" ]]; then
            if ! [[ "$genome_size" =~ ^[0-9]+(\.[0-9]+)?[kmgtKMGT]?$ ]]; then
                print_error "Line $line_num: Invalid genome size format '$genome_size'. Use format like: 5m, 2.3g, 100k"
                exit 1
            fi
        fi
        
    done < "$CONFIG_FILE"
    
    print_status "Configuration file validated successfully."
}

# Function to create batch summary
create_batch_summary() {
    print_status "Creating batch summary..."
    
    local summary_file="$OUTPUT_DIR/batch_summary.txt"
    local total_samples=$(grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | wc -l)
    
    {
        echo "=================================="
        echo "   BATCH ASSEMBLY SUMMARY REPORT  "
        echo "=================================="
        echo ""
        echo "Batch Information:"
        echo "  Date: $(date)"
        echo "  Configuration file: $CONFIG_FILE"
        echo "  Output directory: $OUTPUT_DIR"
        echo "  Total samples: $total_samples"
        echo "  Parallel jobs: $PARALLEL_JOBS"
        echo "  Threads per job: $THREADS"
        echo "  Polishing enabled: $POLISH"
        echo ""
        echo "Sample List:"
        echo "  Sample Name           Input File                    Read Type      Genome Size"
        echo "  -----------           ----------                    ---------      -----------"
        
        while IFS=$'\t' read -r sample_name input_file read_type genome_size || [[ -n "$sample_name" ]]; do
            # Skip empty lines and comments
            if [[ -z "$sample_name" || "$sample_name" =~ ^#.* ]]; then
                continue
            fi
            
            printf "  %-20s  %-28s  %-12s  %s\n" "$sample_name" "$(basename "$input_file")" "$read_type" "${genome_size:-'Not specified'}"
            
        done < "$CONFIG_FILE"
        
    } > "$summary_file"
    
    print_status "Batch summary created: $summary_file"
}

# Function to process a single sample
process_sample() {
    local sample_name="$1"
    local input_file="$2"
    local read_type="$3"
    local genome_size="$4"
    local sample_output="$OUTPUT_DIR/$sample_name"
    
    print_status "Processing sample: $sample_name"
    
    # Build flye_assembly.sh command
    local cmd="./scripts/flye_assembly.sh"
    cmd+=" -i '$input_file'"
    cmd+=" -o '$sample_output'"
    cmd+=" -t '$read_type'"
    cmd+=" -T $THREADS"
    
    if [[ -n "$genome_size" ]]; then
        cmd+=" -g '$genome_size'"
    fi
    
    if [[ "$POLISH" == true ]]; then
        cmd+=" -p"
    fi
    
    if [[ "$RESUME" == true ]]; then
        cmd+=" -r"
    fi
    
    # Create sample-specific log
    local sample_log="$OUTPUT_DIR/$sample_name.batch.log"
    
    print_info "Command: $cmd"
    print_info "Log file: $sample_log"
    
    # Run assembly
    if eval "$cmd" > "$sample_log" 2>&1; then
        print_status "Sample $sample_name completed successfully."
        echo "SUCCESS: $sample_name - $(date)" >> "$OUTPUT_DIR/batch_status.log"
    else
        print_error "Sample $sample_name failed. Check log: $sample_log"
        echo "FAILED: $sample_name - $(date)" >> "$OUTPUT_DIR/batch_status.log"
        return 1
    fi
}

# Function to run batch processing
run_batch_processing() {
    print_status "Starting batch processing..."
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Initialize status log
    echo "Batch processing started: $(date)" > "$OUTPUT_DIR/batch_status.log"
    
    # Create job queue
    local job_queue=()
    while IFS=$'\t' read -r sample_name input_file read_type genome_size || [[ -n "$sample_name" ]]; do
        # Skip empty lines and comments
        if [[ -z "$sample_name" || "$sample_name" =~ ^#.* ]]; then
            continue
        fi
        
        job_queue+=("$sample_name:$input_file:$read_type:$genome_size")
    done < "$CONFIG_FILE"
    
    print_info "Total jobs to process: ${#job_queue[@]}"
    
    # Process jobs
    local active_jobs=()
    local completed_jobs=0
    local failed_jobs=0
    
    for job in "${job_queue[@]}"; do
        IFS=':' read -r sample_name input_file read_type genome_size <<< "$job"
        
        # Wait if we've reached the parallel job limit
        while [[ ${#active_jobs[@]} -ge $PARALLEL_JOBS ]]; do
            # Check for completed jobs
            local new_active_jobs=()
            for active_job in "${active_jobs[@]}"; do
                if kill -0 "$active_job" 2>/dev/null; then
                    new_active_jobs+=("$active_job")
                else
                    wait "$active_job"
                    if [[ $? -eq 0 ]]; then
                        ((completed_jobs++))
                    else
                        ((failed_jobs++))
                    fi
                fi
            done
            active_jobs=("${new_active_jobs[@]}")
            
            if [[ ${#active_jobs[@]} -ge $PARALLEL_JOBS ]]; then
                sleep 30  # Wait 30 seconds before checking again
            fi
        done
        
        # Start new job
        process_sample "$sample_name" "$input_file" "$read_type" "$genome_size" &
        local job_pid=$!
        active_jobs+=("$job_pid")
        
        print_info "Started job for $sample_name (PID: $job_pid)"
    done
    
    # Wait for remaining jobs to complete
    print_status "Waiting for remaining jobs to complete..."
    for job_pid in "${active_jobs[@]}"; do
        wait "$job_pid"
        if [[ $? -eq 0 ]]; then
            ((completed_jobs++))
        else
            ((failed_jobs++))
        fi
    done
    
    # Final summary
    local total_jobs=${#job_queue[@]}
    print_status "Batch processing completed!"
    print_info "Total jobs: $total_jobs"
    print_info "Completed successfully: $completed_jobs"
    print_info "Failed: $failed_jobs"
    
    # Update batch status log
    {
        echo "Batch processing completed: $(date)"
        echo "Total jobs: $total_jobs"
        echo "Completed successfully: $completed_jobs"
        echo "Failed: $failed_jobs"
    } >> "$OUTPUT_DIR/batch_status.log"
    
    if [[ $failed_jobs -gt 0 ]]; then
        print_warning "$failed_jobs job(s) failed. Check individual log files for details."
        exit 1
    fi
}

# Function to generate final batch report
generate_batch_report() {
    print_status "Generating final batch report..."
    
    local report_file="$OUTPUT_DIR/batch_final_report.txt"
    
    {
        echo "=================================="
        echo "   FINAL BATCH ASSEMBLY REPORT    "
        echo "=================================="
        echo ""
        echo "Processing Summary:"
        cat "$OUTPUT_DIR/batch_status.log"
        echo ""
        echo "Individual Sample Results:"
        echo "=========================="
        
        while IFS=$'\t' read -r sample_name input_file read_type genome_size || [[ -n "$sample_name" ]]; do
            # Skip empty lines and comments
            if [[ -z "$sample_name" || "$sample_name" =~ ^#.* ]]; then
                continue
            fi
            
            echo ""
            echo "Sample: $sample_name"
            echo "------"
            
            local sample_output="$OUTPUT_DIR/$sample_name"
            if [[ -f "$sample_output/assembly_summary.txt" ]]; then
                # Extract key statistics
                echo "Status: SUCCESS"
                grep -E "(Number of contigs|Total length|N50|GC content)" "$sample_output/assembly_summary.txt" || true
            else
                echo "Status: FAILED or INCOMPLETE"
            fi
            
        done < "$CONFIG_FILE"
        
    } > "$report_file"
    
    print_status "Final batch report generated: $report_file"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -j|--jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        -T|--threads)
            THREADS="$2"
            shift 2
            ;;
        -p|--polish)
            POLISH=true
            shift
            ;;
        -r|--resume)
            RESUME=true
            shift
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
if [[ -z "$CONFIG_FILE" || -z "$OUTPUT_DIR" ]]; then
    print_error "Missing required parameters."
    show_help
    exit 1
fi

# Main execution
main() {
    print_status "Starting batch Flye assembly pipeline..."
    print_info "Configuration file: $CONFIG_FILE"
    print_info "Output directory: $OUTPUT_DIR"
    print_info "Parallel jobs: $PARALLEL_JOBS"
    print_info "Threads per job: $THREADS"
    
    validate_config
    create_batch_summary
    run_batch_processing
    generate_batch_report
    
    print_status "Batch assembly pipeline completed!"
    print_info "Results are available in: $OUTPUT_DIR"
    print_info "Final report: $OUTPUT_DIR/batch_final_report.txt"
}

# Run main function
main "$@"
