# fd-7987-cellranger-repro

Reproduces Cell Ranger `multi` cache thrash on AWS Batch with Fusion: when Cell Ranger's barcode-sorted shards live in a Fusion work dir and are larger than the instance's local NVMe, ALIGN_AND_COUNT's scattered reads keep evicting and re-downloading the same 128 MiB chunks, and the task stalls with near-zero CPU and constant S3 download.

## 1. Prepare inputs (this repo)

`main.nf` extracts the public 10x Genomics Chromium X full-chip 3' HT v3.1 FASTQs (H1975/A549 drug screen, 16 tars, ~3.1 TB) and the GRCh38-2024-A reference directly into S3 through the Fusion mount, then writes a samplesheet:

- `<dest>/fastq/` - FASTQs, one directory tree per tar
- `<dest>/ref/refdata-gex-GRCh38-2024-A/` - Cell Ranger reference, used as `--cellranger_index`
- `<dest>/samplesheet.csv` - every gene expression lane from every tar as ONE nf-core/scrnaseq sample, so a single `cellranger multi` task sees the whole ~3 TB

The source tars come from the requester-pays bucket `s3://10x.largefiles/samples/cell-exp/6.1.0/H1975_A549_DrugScreen_3p_HT_nextgem/` (us-west-2) and must first be copied into a bucket you own:

```
aws s3 cp --recursive --request-payer requester --copy-props none \
  s3://10x.largefiles/samples/cell-exp/6.1.0/H1975_A549_DrugScreen_3p_HT_nextgem/ \
  s3://my-bucket/prefix/source/H1975_A549_DrugScreen_3p_HT_nextgem/
```

`--copy-props none` is needed because the 10x bucket denies `GetObjectTagging`, which the CLI calls for multipart copies.

Requires a Fusion-enabled compute environment.

```
nextflow run robsyme/fd-7987-cellranger-repro --dest s3://my-bucket/prefix --source 's3://my-bucket/prefix/source/*/*_fastqs.tar'
```

## 2. Run nf-core/scrnaseq 4.2.0

`launch/` holds the params and config for two runs of nf-core/scrnaseq 4.2.0 (`--aligner cellrangermulti`, Cell Ranger 10.0.0):

| Run | Params | Config | Expectation |
|---|---|---|---|
| Repro | `params-fusion-workdir.json` | `fusion-workdir.config` | ALIGN_AND_COUNT stalls once the shards outgrow the NVMe cache |
| Control | `params-scratch.json` | `scratch.config` | Same task with `scratch = true`, so intermediates stay on local disk. With ~3 TB of input it may run out of space on a 2.4 TB instance, which is itself the disk-sizing result |

Both expect a compute environment matching the original report: AWS Batch, on-demand `r5ad.16xlarge` (64 vCPU, 512 GiB, 2.4 TB NVMe), Fusion v2 + Wave + fast instance storage. Use on-demand: the stall only appears after roughly 10 hours.

## What to look for

In the CELLRANGER_MULTI task's `.fusion.log`, `garbage collector` lines at `urgency=Critical` whose `postAvailable` jumps back to near the disk total, repeating roughly hourly, while `SC_MULTI_CS/.../ALIGN_AND_COUNT/fork0/chnk*` paths keep being re-read.
