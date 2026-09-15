#!/usr/bin/env nextflow

/*
 * Generate a BAM index file with Samtools.
 */
process SAMTOOLS_INDEX {

    tag "$sample_id"
    label 'process_low'
    publishDir "${params.outdir}/indexed_bam", mode: 'copy'

    conda "${projectDir}/envs/samtools.yml"
    container 'community.wave.seqera.io/library/samtools:1.20--b5dfbd93de237464'

    input:
    tuple val(sample_id), path(bam)

    output:
    tuple val(sample_id), path(bam), path("${bam}.bai"), emit: indexed_bam

    script:
    """
    samtools index '${bam}'
    """
}
