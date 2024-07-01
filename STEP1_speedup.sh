#!/bin/bash
#SBATCH -p nvidia
#SBATCH -c 40
#SBATCH --gres=gpu:1
#SBATCH -t 24:00:00

source /share/apps/NYUAD5/miniconda/3-4.11.0/bin/activate
conda activate drna

module load all
module load gencore
module load minimap2/2.24
module load samtools/1.10
module load pigz

# Set parameters
TAR_DIR="./SH1"
CORE_COUNT=40

# Temporary extraction directory
TEMP_DIR="./SH1_temp"

# Create the temporary directory
mkdir -p "$TEMP_DIR"
mkdir -p $TEMP_DIR/fastq/
mkdir -p $TEMP_DIR/fast5/

echo "TAR_DIR: $TAR_FILE"
echo "CORE_COUNT: $CORE_COUNT"

# List the contents of the tar file and save to a temporary file

TOTAL_BATCHES=$(find "$TAR_DIR" -name "*.tar.gz" | wc -l)

for CURRENT_BATCH in $(seq 1 $TOTAL_BATCHES); do
    
    echo "Extracting batch $CURRENT_BATCH of $TOTAL_BATCHES"
    
    tar --use-compress-program="pigz -d -p $CORE_COUNT" -xf $TAR_DIR/batch_$CURRENT_BATCH.tar.gz -C $TEMP_DIR/fast5/
    
    echo "Running analysis on files" 
	
    echo "Start basecaller"
    mkdir $TEMP_DIR/fastq/$CURRENT_BATCH

    /scratch/lb4489/project/dRNA/ont-guppy/bin/guppy_basecaller -i $TEMP_DIR/fast5/ -s $TEMP_DIR/fastq/$CURRENT_BATCH --flowcell FLO-MIN106 --kit SQK-RNA002 --device auto -q 0 -r 	
	
    echo "Start minimap"
	
    minimap2 -ax map-ont -uf -t $CORE_COUNT --secondary=no /scratch/lb4489/project/dRNA/GRCh38_trans.mmi  $TEMP_DIR/fastq/$CURRENT_BATCH/pass/*.fastq > $TEMP_DIR/$CURRENT_BATCH.sam 2>> $TEMP_DIR/$CURRENT_BATCH.bam.log 

    samtools view -Sb $TEMP_DIR/$CURRENT_BATCH.sam | samtools sort -o $TEMP_DIR/$CURRENT_BATCH.bam - &>> $TEMP_DIR/$CURRENT_BATCH.bam.log

    samtools index $TEMP_DIR/$CURRENT_BATCH.bam &>> $TEMP_DIR/$CURRENT_BATCH.bam.log

    echo "Start polish"

    cat $TEMP_DIR/fastq/$CURRENT_BATCH/pass/*.fastq >  $TEMP_DIR/fastq/$CURRENT_BATCH.fastq #这里产生了许多个fastq文件，对其进行了合并

    nanopolish index -d $TEMP_DIR/fast5 $TEMP_DIR/fastq/$CURRENT_BATCH.fastq

    nanopolish eventalign --reads $TEMP_DIR/fastq/$CURRENT_BATCH.fastq \
	--bam $TEMP_DIR/$CURRENT_BATCH.bam \
	--genome /scratch/lb4489/bioindex/gencode.v46.transcripts.fa \
	--signal-index \
	--scale-events \
	--summary $TEMP_DIR/$CURRENT_BATCH.summary.txt \
	--threads $CORE_COUNT > $TEMP_DIR/$CURRENT_BATCH.eventalign.txt

    echo "Progress: $CURRENT_BATCH/$TOTAL_BATCHES completed."

    rm -rf $TEMP_DIR/fast5/*

done

echo "All files extracted in batches."
