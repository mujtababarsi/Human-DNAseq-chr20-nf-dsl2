/*
 * DNASEQ WORKFLOW
 * Index BAMs, call variants per sample, joint-genotype the cohort, run QC.
 */

include { SAMTOOLS_INDEX }       from '../modules/samtools_index.nf'
include { SAMTOOLS_STATS }       from '../modules/samtools_stats.nf'
include { GATK_HAPLOTYPECALLER } from '../modules/gatk_haplotypecaller.nf'
include { GATK_JOINTGENOTYPING } from '../modules/gatk_jointgenotyping.nf'
include { BCFTOOLS_STATS }       from '../modules/bcftools_stats.nf'
include { MULTIQC }              from '../modules/multiqc.nf'

workflow DNASEQ_WORKFLOW {
    take:
    reads_ch   // tuple(sample_id, bam)

    main:
    // Stop early if no samples
    reads_ch.ifEmpty { error "No samples found. Check your samplesheet: ${params.input}" }

    // Reference files
    ref_fasta = file(params.reference,       checkIfExists: true)
    ref_index = file(params.reference_index, checkIfExists: true)
    ref_dict  = file(params.reference_dict,  checkIfExists: true)
    intervals = file(params.intervals,       checkIfExists: true)

    // Index BAMs
    indexed_ch = SAMTOOLS_INDEX(reads_ch).indexed_bam

    // Per-sample alignment QC
    stats_out = SAMTOOLS_STATS(indexed_ch)

    // Call variants per sample (GVCF mode)
    gvcf_ch = GATK_HAPLOTYPECALLER(
        indexed_ch,
        ref_fasta,
        ref_index,
        ref_dict,
        intervals
    ).gvcf

    // Collect GVCFs across all samples for joint genotyping
    all_gvcfs_ch = gvcf_ch.map { sample_id, vcf, idx -> vcf }.collect()
    all_idxs_ch  = gvcf_ch.map { sample_id, vcf, idx -> idx }.collect()

    // Joint genotype the cohort
    joint_ch = GATK_JOINTGENOTYPING(
        all_gvcfs_ch,
        all_idxs_ch,
        intervals,
        params.cohort_name,
        ref_fasta,
        ref_index,
        ref_dict
    )

    // Variant QC on the joint VCF
    vcf_stats_out = BCFTOOLS_STATS(joint_ch.vcf, params.cohort_name)

    // Combine all QC reports and run MultiQC once
    qc_files_ch = stats_out.stats
        .mix(stats_out.flagstat)
        .mix(vcf_stats_out.stats)
        .collect()

    multiqc_out = MULTIQC(qc_files_ch)

    emit:
    indexed_bam    = indexed_ch          // tuple(sample_id, bam, bai)
    gvcf           = gvcf_ch             // tuple(sample_id, gvcf, gvcf_idx)
    joint_vcf      = joint_ch.vcf
    joint_idx      = joint_ch.idx
    bcftools_stats = vcf_stats_out.stats
    multiqc_report = multiqc_out.report
}