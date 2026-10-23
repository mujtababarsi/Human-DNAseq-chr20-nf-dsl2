#!/usr/bin/env nextflow

/*
 * Copy ClinVar clinical significance (CLNSIG) and disease name (CLNDN)
 * onto every cohort variant that matches a ClinVar record by position
 * and allele.
 */
process CLINVAR_ANNOTATE {

    tag "$cohort_name"
    label 'process_low'
    publishDir "${params.outdir}/annotation", mode: 'copy'

    conda "${projectDir}/envs/bcftools.yml"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'

    input:
    path vcf
    path clinvar
    path clinvar_tbi
    val  cohort_name

    output:
    path "${cohort_name}.clinvar.vcf.gz"    , emit: vcf
    path "${cohort_name}.clinvar.vcf.gz.tbi", emit: tbi

    script:
    """
    # annotate needs a bgzipped + indexed input; the upstream VCF may be
    # plain text (no coordinate shift), so make an indexed copy either way
    bcftools view -Oz -o input.vcf.gz ${vcf}
    bcftools index -t input.vcf.gz

    bcftools annotate \\
        -a ${clinvar} \\
        -c INFO/CLNSIG,INFO/CLNDN \\
        -Oz -o ${cohort_name}.clinvar.vcf.gz \\
        input.vcf.gz

    bcftools index -t ${cohort_name}.clinvar.vcf.gz
    """
}
