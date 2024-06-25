# my_dRNA_seq

#记录自己做dRNA分析的代码

STEP1_polish.sh是对fast5格式文件进行操作的代码，包括basecall以及nanopolish。这部分的代码写得非常复杂，是因为服务器有文件数量显著，如果直接把fast5文件解压缩并分析会简单得多，但是我不能这样做。
于是我使用的方法是将文件分批次进行解压，一次对一个子文件夹文件进行分析，最后对basecall 和 polish文件进行合并就可以绕过服务器的文件数量限制。

#合并结果
```
awk 'FNR==1 && NR!=1 { next; } { print }' $(ls *eventalign.txt | sort) > merge_eventalign.txt
awk 'FNR==1 && NR!=1 { next; } { print }' $(ls *summary.txt | sort) > merge_summary.txt
```
