# my_dRNA_seq

#记录自己做dRNA分析的代码

#STEP1_polish.sh是对fast5格式文件进行操作的代码，包括basecall以及nanopolish，这部分的代码写得非常复杂

#合并结果
```
awk 'FNR==1 && NR!=1 { next; } { print }' $(ls *eventalign.txt | sort) > merge_eventalign.txt
awk 'FNR==1 && NR!=1 { next; } { print }' $(ls *summary.txt | sort) > merge_summary.txt
```
