# Test fixtures (annotation)

**Test fixtures only — not for analysis.** Small files used by the nf-tests in
`tests/modules/`. Each VCF also carries a `##comment=TEST FIXTURE ONLY: ...`
header line.

| File | Origin | Used by | What it proves |
|---|---|---|---|
| `annotation/clinvar_one_record.vcf.gz` (+ `.tbi`) | **Real.** One ClinVar GRCh37 record (VariationID 4098442, `20:10023877 A>G`, `CLNSIG=Likely_benign`, `CLNDN=not_specified`), copied unchanged with the full ClinVar header from `clinvar.vcf.gz`, fileDate 2026-10-19 | `clinvar_annotate.nf.test` | Positive control: a matching variant really receives CLNSIG/CLNDN |
| `annotation/synthetic_clinvar_query.vcf` | **Synthetic.** One invented variant at the same position and alleles as the record above | `clinvar_annotate.nf.test` | Query for the positive control, and for the negative control against `data/annotation/clinvar_region.vcf.gz` (0 records) |
| `annotation/joint_excerpt.vcf` | **Real pipeline output.** Header + first 3 records of `results/family_trio.joint.vcf` from `-profile test` (excerpt contig `20_10037292_10066351`) | `shift_coordinates.nf.test`, `filter_variants.nf.test`, `snpeff.nf.test` (stub) | Shift arithmetic (3480 → 10040772), REF check pass/fail against `data/ref/ref.fasta`, filters without ANN |
| `annotation/synthetic_trio.vcf` | **Synthetic.** 5 invented records; columns ordered mother, son, father | `filter_variants.nf.test` | Samples resolved by name; one de novo (pos 100), two protein-altering (200 HIGH, 300 MODERATE), a missing parental genotype (400), and a decoy gene name `HIGHMODERATE1` with MODIFIER impact (500) |

Why a separate ClinVar fixture: the test region (GRCh37 chr20:10037293-10066351)
has **no** ClinVar records, so the pipeline test alone can only ever show 0
matches. The one-record fixture comes from the nearest ClinVar cluster
(~20:10,018,9xx-10,025,xxx), so a 0 in the pipeline means "no record there",
not "annotation is broken".

## How the ClinVar fixture was made

From the repo root, with the full ClinVar GRCh37 VCF in `annot/` (gitignored):

```bash
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data -w /data \
  quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0 sh -c '
bcftools view --no-version -r 20:10023877 -i "ID==\"4098442\"" annot/clinvar.vcf.gz \
 | awk "/^#CHROM/{print \"##comment=TEST FIXTURE ONLY: ...\"} {print}" \
 | bcftools view --no-version -Oz -o tests/fixtures/annotation/clinvar_one_record.vcf.gz
bcftools index -t tests/fixtures/annotation/clinvar_one_record.vcf.gz'
```

`data/annotation/clinvar_region.vcf.gz` (used by `-profile test`) is
`bcftools view -r 20:10037000-10067000` of the same ClinVar file: the full
header and 0 records.
