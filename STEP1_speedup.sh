#!/bin/bash
#SBATCH -p nvidia
#SBATCH -c 40
#SBATCH --gres=gpu:1
#SBATCH -t 36:00:00

start_time=$(date +%s)

source /share/apps/NYUAD5/miniconda/3-4.11.0/bin/activate
conda activate drna

module load all
module load gencore
module load minimap2/2.24
module load samtools/1.10
module load pigz

# Set parameters
TAR_FILE=HEK293T-Mettl3-KO-rep1.tar.gz
CORE_COUNT=40
BATCH_SIZE=20000

# Temporary extraction directory
TEMP_DIR="./sh_rep2"

# Create the temporary directory
mkdir -p "$TEMP_DIR"
mkdir -p $TEMP_DIR/fastq/
mkdir -p $TEMP_DIR/fast5/

echo "TAR_FILE: $TAR_FILE"
echo "CORE_COUNT: $CORE_COUNT"
echo "BASE_DIR: $BASE_DIR"
echo "BATCH SIZE: $BATCH_SIZE"

# List the contents of the tar file and save to a temporary file
echo "Listing files in ${TAR_FILE}..."
tar --use-compress-program="pigz -d -p $CORE_COUNT" -tf "$TAR_FILE" > $TEMP_DIR/tar_list.txt

TOTAL_LINES=$(grep '\.fast5$' $TEMP_DIR/tar_list.txt | wc -l)
TOTAL_BATCHES=$(( (TOTAL_LINES + BATCH_SIZE - 1) / BATCH_SIZE ))
CURRENT_BATCH=0

START_LINE=1

while [ $START_LINE -le $TOTAL_LINES ]; do

    END_LINE=$((START_LINE + BATCH_SIZE - 1))
    
    CURRENT_BATCH=$((CURRENT_BATCH + 1))
    
    echo "Extracting batch $CURRENT_BATCH of $TOTAL_BATCHES: lines $START_LINE to $END_LINE"
    
    grep '\.fast5$' $TEMP_DIR/tar_list.txt | sed -n "${START_LINE},${END_LINE}p" | tar --use-compress-program="pigz -d -p $CORE_COUNT" -xf "$TAR_FILE" -C $TEMP_DIR/fast5/ -T -
    
    echo "Running analysis on files" 
	
    echo "Start basecaller"
    mkdir $TEMP_DIR/fastq/$CURRENT_BATCH

    /scratch/lb4489/project/dRNA/ont-guppy/bin/guppy_basecaller -i $TEMP_DIR/fast5/ -s $TEMP_DIR/fastq/$CURRENT_BATCH --flowcell FLO-MIN106 --kit SQK-RNA002 --device auto -q 0 -r 
	
    echo "Start minimap"
    minimap2 -ax map-ont -uf -t $CORE_COUNT --secondary=no /scratch/lb4489/project/dRNA/GRCh38_trans.mmi  $TEMP_DIR/fastq/$CURRENT_BATCH/pass/*.fastq > $TEMP_DIR/$CURRENT_BATCH.sam 2>> $TEMP_DIR/$CURRENT_BATCH.bam.log 
  
    samtools view -Sb $TEMP_DIR/$CURRENT_BATCH.sam | samtools sort -o $TEMP_DIR/$CURRENT_BATCH.bam - &>> $TEMP_DIR/$CURRENT_BATCH.bam.log
    samtools index $TEMP_DIR/$CURRENT_BATCH.bam &>> $TEMP_DIR/$CURRENT_BATCH.bam.log

    echo "Start polish"

    nanopolish index -d $TEMP_DIR/fast5 $TEMP_DIR/fastq/$CURRENT_BATCH/pass/*.fastq #polish

    nanopolish eventalign --reads $TEMP_DIR/fastq/$CURRENT_BATCH/pass/*.fastq \
	    --bam $TEMP_DIR/$CURRENT_BATCH.bam \
	    --genome /scratch/lb4489/bioindex/gencode.v46.transcripts.fa \
	    --signal-index \
	    --scale-events \
	    --summary $TEMP_DIR/$CURRENT_BATCH.summary.txt \
	    --threads $CORE_COUNT > $TEMP_DIR/$CURRENT_BATCH.eventalign.txt

    echo "Progress: $CURRENT_BATCH/$TOTAL_BATCHES completed."

    START_LINE=$((END_LINE + 1))

    rm -rf $TEMP_DIR/fast5/*

done

echo "All files extracted in batches."

