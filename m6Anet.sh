#!/bin/bash
#SBATCH -p compute
#SBATCH -c 40
#SBATCH -t 00:40:00

source /share/apps/NYUAD5/miniconda/3-4.11.0/bin/activate
conda activate drna


m6anet dataprep --eventalign ./merge_eventalign.txt \
        --out_dir ten_fold \
        --n_processes 40

m6anet inference --input_dir ten_fold --out_dir ten_m6anet_result  --pretrained_model HEK293T_RNA004 --n_processes 40 --num_iterations 1000
