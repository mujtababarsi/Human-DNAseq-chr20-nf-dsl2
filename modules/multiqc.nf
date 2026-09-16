#!/usr/bin/env nextflow

/*
 * Aggregate every QC report (samtools stats/flagstat, bcftools stats)
 * into a single interactive MultiQC dashboard.
 */
process MULTIQC {

    label 'process_low'
    publishDir "${params.outdir}/qc/multiqc", mode: 'copy'

    conda "${projectDir}/envs/multiqc.yml"
    container 'quay.io/biocontainers/multiqc:1.27--pyhdfd78af_0'

    input:
    path qc_files

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_data"       , emit: data

    script:
    """
    multiqc .
    """
}
