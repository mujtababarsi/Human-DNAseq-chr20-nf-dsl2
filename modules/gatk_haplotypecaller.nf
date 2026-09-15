#!/usr/bin/env nextflow

/*
 * Call variants per-sample with GATK HaplotypeCaller in GVCF mode.
 */
process GATK_HAPLOTYPECALLER {

    tag "$sample_id"
    label 'process_medium'
    publishDir "${params.outdir}/gvcf", mode: 'copy'

    conda "${projectDir}/envs/gatk4.yml"
    container 'community.wave.seqera.io/library/gatk4:4.5.0.0--730ee8817e436867'

    input:
    tuple val(sample_id), path(bam), path(bai)
    path ref_fasta
    path ref_index
    path ref_dict
    path interval_list

    output:
    tuple val(sample_id), path("${bam}.g.vcf"), path("${bam}.g.vcf.idx"), emit: gvcf

    script:
    """
    gatk HaplotypeCaller \
        -R ${ref_fasta} \
        -I ${bam} \
        -O ${bam}.g.vcf \
        -L ${interval_list} \
        -ERC GVCF
    """
}
