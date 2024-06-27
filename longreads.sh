#!/bin/bash
#SBATCH -p compute
#SBATCH -c 20
#SBATCH -t 00:20:00

source /share/apps/NYUAD5/miniconda/3-4.11.0/bin/activate
conda activate drna

module load all
module load gencore
module load fastqc/0.11.9
module load minimap2/2.24
module load samtools/1.10

fastqc ./*fastq

#用来polish的文件被比对到转录组了，这里重新比对到基因组

minimap2 -ax map-ont -uf -t 20 --secondary=no /scratch/lb4489/project/dRNA/GRCh38.mmi  ./WT1.fastq > ./togenome.sam

samtools view -Sb ./togenome.sam | samtools sort -o ./togenome.bam

samtools index ./togenome.bam

conda activate rna

#转录组组装和定量的话，可以直接用stringtie，老戏骨了

stringtie -L -o ./wt1_den.gtf ./togenome.bam  -p 20
#无参

stringtie -L -o ./wt1_ref.gtf ./togenome.bam  -p 20 -G /scratch/lb4489/bioindex/gencode.v44.annotation.gtf
#有参

#我没太明白，如果有参也可以得到未注释的转录本的话，那是不是就全做有参好了
