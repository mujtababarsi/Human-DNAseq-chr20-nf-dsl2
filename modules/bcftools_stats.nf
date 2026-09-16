#!/usr/bin/env nextflow

/*
 * Variant-calling QC on the final joint-genotyped cohort VCF.
 */
process BCFTOOLS_STATS {

    tag "$cohort_name"
    label 'process_low'
    publishDir "${params.outdir}/qc/bcftools", mode: 'copy'

    conda "${projectDir}/envs/bcftools.yml"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'

    input:
    path vcf
    val  cohort_name

    output:
    path "${cohort_name}.bcftools_stats.txt", emit: stats

    script:
    """
    bcftools stats ${vcf} > ${cohort_name}.bcftools_stats.txt
    """
}
