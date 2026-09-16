#!/usr/bin/env nextflow

/*
 * Per-sample alignment QC: samtools stats + samtools flagstat.
 * Text reports feed into the aggregated MultiQC report.
 */
process SAMTOOLS_STATS {

    tag "$sample_id"
    label 'process_low'
    publishDir "${params.outdir}/qc/samtools", mode: 'copy'

    conda "${projectDir}/envs/samtools.yml"
    container 'community.wave.seqera.io/library/samtools:1.20--b5dfbd93de237464'

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    path "${bam}.stats.txt"    , emit: stats
    path "${bam}.flagstat.txt" , emit: flagstat

    script:
    """
    samtools stats ${bam} > ${bam}.stats.txt
    samtools flagstat ${bam} > ${bam}.flagstat.txt
    """
}
