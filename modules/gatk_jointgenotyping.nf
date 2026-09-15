#!/usr/bin/env nextflow

/*
 * Combine per-sample GVCFs into a GenomicsDB data store and run joint
 * genotyping across the cohort to produce a single cohort-level VCF.
 */
process GATK_JOINTGENOTYPING {

    tag "$cohort_name"
    label 'process_medium'
    publishDir "${params.outdir}", mode: 'copy'

    conda "${projectDir}/envs/gatk4.yml"
    container 'community.wave.seqera.io/library/gatk4:4.5.0.0--730ee8817e436867'

    input:
    path all_gvcfs
    path all_idxs
    path interval_list
    val  cohort_name
    path ref_fasta
    path ref_index
    path ref_dict

    output:
    path "${cohort_name}.joint.vcf"     , emit: vcf
    path "${cohort_name}.joint.vcf.idx" , emit: idx

    script:
    def gvcfs_line = all_gvcfs.collect { gvcf -> "-V ${gvcf}" }.join(' ')
    """
    gatk GenomicsDBImport \
        ${gvcfs_line} \
        -L ${interval_list} \
        --genomicsdb-workspace-path ${cohort_name}_gdb

    gatk GenotypeGVCFs \
        -R ${ref_fasta} \
        -V gendb://${cohort_name}_gdb \
        -L ${interval_list} \
        -O ${cohort_name}.joint.vcf
    """
}
