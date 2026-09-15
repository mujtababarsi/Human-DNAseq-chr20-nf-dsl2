# nf-dnaseq

A small, modular **Nextflow** pipeline for germline short-variant calling (SNPs and indels)
from whole-genome sequencing BAM files, using **Samtools** and **GATK4**.

It implements both variant-calling strategies covered in the Nextflow
["Nextflow for Science: Genomics"](https://training.nextflow.io/latest/nf4_science/genomics/)
training course:

1. **Per-sample variant calling** — index each BAM with Samtools, then call variants
   independently per sample with GATK `HaplotypeCaller`.
2. **Joint calling on a cohort** — call each sample in GVCF mode, combine the GVCFs with
   GATK `GenomicsDBImport`, and run `GenotypeGVCFs` to produce a single cohort-level VCF.

## Pipeline overview

```
BAM ─▶ [SAMTOOLS_INDEX] ─▶ indexed BAM ─▶ [GATK_HAPLOTYPECALLER] ─▶ per-sample GVCF
                                                                        │
                                                     (collect across all samples)
                                                                        ▼
                                              [GATK_JOINTGENOTYPING] (GenomicsDBImport + GenotypeGVCFs)
                                                                        │
                                                                        ▼
                                                            cohort-level joint VCF
```

| Process                | Tool(s)                              | Container                                                                 |
|-------------------------|---------------------------------------|----------------------------------------------------------------------------|
| `SAMTOOLS_INDEX`        | Samtools `index`                      | `community.wave.seqera.io/library/samtools:1.20--b5dfbd93de237464`         |
| `GATK_HAPLOTYPECALLER`  | GATK `HaplotypeCaller` (GVCF mode)     | `community.wave.seqera.io/library/gatk4:4.5.0.0--730ee8817e436867`         |
| `GATK_JOINTGENOTYPING`  | GATK `GenomicsDBImport` + `GenotypeGVCFs` | `community.wave.seqera.io/library/gatk4:4.5.0.0--730ee8817e436867`     |

## Project layout

```
nf-dnaseq/
├── main.nf                       # main workflow
├── nextflow.config                # config + test profile
├── modules/
│   ├── samtools_index.nf
│   ├── gatk_haplotypecaller.nf
│   └── gatk_jointgenotyping.nf
└── data/                          # bundled test dataset (family trio, chr20 slice)
    ├── samplesheet.csv
    ├── bam/
    │   ├── reads_mother.bam
    │   ├── reads_father.bam
    │   └── reads_son.bam
    └── ref/
        ├── ref.fasta
        ├── ref.fasta.fai
        ├── ref.dict
        └── intervals.bed
```

## Requirements

- [Nextflow](https://www.nextflow.io/docs/latest/install.html) (>= 24.10)
- [Docker](https://docs.docker.com/get-docker/) (containers are pulled automatically)

## Usage

Run on the bundled test data (a small family trio subset of chromosome 20):

```bash
nextflow run main.nf -profile test
```

Run on your own samples by pointing at a samplesheet and reference files:

```bash
nextflow run main.nf \
    --input          samplesheet.csv \
    --reference      ref.fasta \
    --reference_index ref.fasta.fai \
    --reference_dict  ref.dict \
    --intervals      intervals.bed \
    --cohort_name    my_cohort
```

`samplesheet.csv` is a plain CSV with a header row:

```csv
sample_id,reads_bam
SAMPLE1,/path/to/sample1.bam
SAMPLE2,/path/to/sample2.bam
```

### Parameters

| Parameter          | Description                                                        |
|---------------------|----------------------------------------------------------------------|
| `input`             | CSV samplesheet listing `sample_id,reads_bam` (mapped BAM per sample)|
| `reference`         | Reference genome FASTA                                              |
| `reference_index`   | Reference `.fai` index                                              |
| `reference_dict`    | Reference sequence dictionary (`.dict`)                             |
| `intervals`         | BED file of genomic intervals to call variants over                 |
| `cohort_name`       | Name used for the final joint-called VCF                            |

## Outputs

Published under `results/` by default:

- `indexed_bam/` — each input BAM alongside its `.bai` index
- `gvcf/` — per-sample GVCFs (`*.g.vcf`) and their indices
- `<cohort_name>.joint.vcf` (+ `.idx`) — the final cohort-level, joint-genotyped VCF

## Test dataset

The bundled dataset under `data/` is the same one used in the Nextflow training: a family
trio (mother, father, son; Illumina short-read data already mapped to the reference) subset
to a small slice of chromosome 20 (hg19/b37), so the whole pipeline runs in seconds.

## Credits

This pipeline was built by working through the Nextflow
["Nextflow for Science: Genomics"](https://training.nextflow.io/latest/nf4_science/genomics/)
training course (Seqera), which also provides the bundled test dataset. See:

- [Part 1: Method overview](https://training.nextflow.io/latest/nf4_science/genomics/01_method/)
- [Part 2: Per-sample variant calling](https://training.nextflow.io/latest/nf4_science/genomics/02_per_sample_variant_calling/)
- [Part 3: Joint calling on a cohort](https://training.nextflow.io/latest/nf4_science/genomics/03_joint_calling/)

Training materials are © Seqera, licensed under
[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

## License

Pipeline code in this repository is released under the MIT License (see `LICENSE`).
