#!/bin/bash
#SBATCH -p nvidia
#SBATCH -c 20
#SBATCH --gres=gpu:1
#SBATCH -t 00:05:00

source /share/apps/NYUAD5/miniconda/3-4.11.0/bin/activate
conda activate drna

module load all
module load gencore
module load minimap2/2.24
module load samtools/1.10

module load pigz

# Check if the correct number of arguments is provided
if [ $# -lt 2 ];then
    echo "Usage: $0 <tar file> <number of cores> [fast5 directory path]"
    exit 1
fi

# Set parameters
TAR_FILE="$1"
CORE_COUNT="$2"
#FOLDER_COUNT="$3"  #跑demo时做的限制
BASE_DIR="${4:-fast5}"

# Temporary extraction directory
TEMP_DIR="./temp"

# Create the temporary directory
mkdir -p "$TEMP_DIR"
mkdir -p $TEMP_DIR/fastq/

echo "TAR_FILE: $TAR_FILE"
echo "CORE_COUNT: $CORE_COUNT"
#echo "FOLDER_COUNT: $FOLDER_COUNT"
echo "BASE_DIR: $BASE_DIR"

# List the contents of the tar file and save to a temporary file
echo "Listing files in ${TAR_FILE}..."
tar --use-compress-program="pigz -d -p $CORE_COUNT" -tf "$TAR_FILE" > $TEMP_DIR/tar_list.txt

#if [ $? -ne 0 ]; then
#    echo "Failed to read ${TAR_FILE}. Please check if the file exists and the path is correct."
#    exit 1
#fi 
#tar有一些问题，会返回正常的结果但是会报错，不知道为什么所以把这一段检查注释掉了

echo "File list saved to $TEMP_DIR/tar_list.txt"

# Match directories containing the specified base directory and save to another temporary file
grep "/$BASE_DIR/" $TEMP_DIR/tar_list.txt | grep "/$BASE_DIR/[^/]\+/$" > $TEMP_DIR/filtered_fast5_list.txt
if [ $? -ne 0 ]; then
    echo "No matching fast5 directories found. Please check if the path is correct."
    exit 1
fi

echo "Filtered fast5 directories list saved to $TEMP_DIR/filtered_fast5_list.txt"
cat $TEMP_DIR/filtered_fast5_list.txt

# Get all unique parent directories of fast5, limited by the number specified
FAST5_DIRS=$(cat $TEMP_DIR/filtered_fast5_list.txt | awk -F/ '{print $1"/"$2"/"$3"/"$4}' | sort -u ) # head -n "$FOLDER_COUNT"

echo "Found fast5 directories:"
echo "$FAST5_DIRS"

if [ -z "$FAST5_DIRS" ]; then
    echo "No fast5 directories found. Please check if the path is correct."
    exit 1
fi


# Process each found fast5 directory
for FAST5_DIR in $FAST5_DIRS; do
    echo "Processing fast5 directory: $FAST5_DIR"

    subfold=$(basename "${FAST5_DIR%/}")
    mkdir $TEMP_DIR/fastq/$subfold
 
    # Extract the specified subdirectory
    echo "Extracting subdirectory: $FAST5_DIR"
    tar --use-compress-program="pigz -d -p $CORE_COUNT" -xf "$TAR_FILE" -C "$TEMP_DIR" --wildcards "$FAST5_DIR*" #感觉每次解压都要历经整个文件的内容，虽然已经用pigz加速了，但还是感觉很慢

#    if [ $? -ne 0 ]; then
#        echo "Failed to extract $FAST5_DIR."
#        continue
#    fi
#同样的

    TARGET_DIR="$TEMP_DIR/$FAST5_DIR"
    echo "Analyzing directory: $TARGET_DIR"

    # Check if the extracted directory exists
    if [ -d "$TARGET_DIR" ]; then
        # Add your analysis code here
        echo "Running analysis on files in directory: $TARGET_DIR"     #这之后才是正式的分析代码
	
	echo "Start basecaller"
	/scratch/lb4489/project/dRNA/ont-guppy/bin/guppy_basecaller -i $TARGET_DIR -s $TEMP_DIR/fastq/$subfold --flowcell FLO-MIN106 --kit SQK-RNA002 --device auto -q 0 -r  #使用guppy进行baseball
	
	echo "Start minimap"

	minimap2 -ax map-ont -uf -t $CORE_COUNT --secondary=no /scratch/lb4489/project/dRNA/GRCh38.mmi  $TEMP_DIR/fastq/$subfold/pass/*.fastq > $TEMP_DIR/$subfold.sam 2>> $TEMP_DIR/$subfold.bam.log 
 	#使用minimap对fastq文件进行分析，这里我其实不太明白，对于索引我应该用基因组还是转录组呢？
  
	samtools view -Sb $TEMP_DIR/$subfold.sam | samtools sort -o $TEMP_DIR/$subfold.bam - &>> $TEMP_DIR/$subfold.bam.log
	samtools index $TEMP_DIR/$subfold.bam &>> $TEMP_DIR/$subfold.bam.log

	echo "Start polish"

	nanopolish index -d $TARGET_DIR $TEMP_DIR/fastq/$subfold/pass/*.fastq #polish

	nanopolish eventalign --reads $TEMP_DIR/fastq/$subfold/pass/*.fastq \
	--bam $TEMP_DIR/$subfold.bam \
	--genome /scratch/lb4489/bioindex/GRCh38.p14.genome.fa \ #同理，这里的fasta文件也值得考虑，在demo中我使用了基因组，m6Anet的输出结果就变成了染色体以及基因组位置，这其实更方便了（？），但显然和m6Anet的设计以及官方demo不一样的
	--signal-index \
	--scale-events \
	--summary $TEMP_DIR/$subfold.summary.txt \
	--threads $CORE_COUNT > $TEMP_DIR/$subfold.eventalign.txt

    else
        echo "Extracted directory not found: $TARGET_DIR"
    fi


    # Delete the extracted subdirectory and its contents
    echo "Deleting directory and its contents: $TARGET_DIR"
    rm -rf "$TARGET_DIR"
    if [ $? -ne 0 ]; then
        echo "Failed to delete directory $TARGET_DIR."
    else
        echo "Deleted directory: $TARGET_DIR"
    fi
done

echo "Processing complete."
