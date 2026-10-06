# fd-7987-cellranger-repro

Input preparation for reproducing Cell Ranger `multi` cache thrash on AWS Batch with Fusion.

`main.nf` extracts the public 10x Genomics Chromium X full-chip 3' HT v3.1 FASTQs (H1975/A549 drug screen, 16 tars, ~3.1 TB) and the GRCh38-2024-A reference directly into S3 through the Fusion mount:

- `<dest>/fastq/` - FASTQs, one directory tree per tar
- `<dest>/ref/refdata-gex-GRCh38-2024-A/` - Cell Ranger reference, usable as `--cellranger_index`

The source tars come from the requester-pays bucket `s3://10x.largefiles/samples/cell-exp/6.1.0/H1975_A549_DrugScreen_3p_HT_nextgem/` and must first be copied into a bucket you own (`aws s3 cp --recursive --request-payer requester --copy-props none ...`).

Requires a Fusion-enabled compute environment.

```
nextflow run robsyme/fd-7987-cellranger-repro --dest s3://my-bucket/prefix --source 's3://my-bucket/prefix/source/*_fastqs.tar'
```

The repro itself then runs nf-core/scrnaseq with `--aligner cellrangermulti` on all gene expression FASTQs as a single sample.
