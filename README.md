# dRNA_seq

#记录自己做dRNA分析的代码

STEP0，数据准备，好像就构建minimap索引要做
```
minimap2 -ax map-ont -t 20 -uf -k14 -d ./GRCh38.mmi /scratch/lb4489/bioindex/GRCh38.p14.genome.fa
```


STEP1_polish.sh是对fast5格式文件进行操作的代码，包括basecall以及nanopolish。这部分的代码写得非常复杂，是因为服务器有文件数量限制，如果直接把fast5文件解压缩并分析会简单得多，但是我不能这样做。
于是我使用的方法是将文件分批次进行解压，一次对一个子文件夹文件进行分析，最后对basecall 和 polish文件进行合并就可以绕过服务器的文件数量限制。
使用方法是：其中18为核心数，fast5是母文件夹，我们以fast5下一级的文件夹为单位进行的分析
```
sbatch demo2.sh test.tar.gz 18 'fast5'
```
其中18为核心数，fast5是母文件夹，我们以fast5下一级的文件夹为单位进行的分析

STEP1_speedup.sh的分析和STEP1_polish.sh一模一样但是为了加速分析流程进行修改，在STEP1_polish.sh中根据子文件夹进行了分批次的处理，而在STEP1_speedup.sh则根据文件数量进行的处理，一次对更多数量的文件进行操作可以减少解压的次数
此外也对解压方式进行了修改，应该可以加快许多

#合并结果
```
awk 'FNR==1 && NR!=1 { next; } { print }' $(ls *eventalign.txt | sort) > merge_eventalign.txt
awk 'FNR==1 && NR!=1 { next; } { print }' $(ls *summary.txt | sort) > merge_summary.txt
```

#bam文件
```
samtools merge merged.bam  ./*.bam
```

#对于m6Anet结果进行坐标转换
```
gppy t2g -g /scratch/lb4489/bioindex/gencode.v44.annotation.gtf -i t2g.txt  > gpos.txt
```
