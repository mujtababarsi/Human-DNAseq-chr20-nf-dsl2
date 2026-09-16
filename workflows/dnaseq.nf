/*
 * DNASEQ WORKFLOW
 * -----------------------------------------------------------
 * Germline short-variant calling for a cohort of samples:
 *   1. Index each BAM with Samtools
 *   2. Call variants per-sample in GVCF mode with GATK HaplotypeCaller
 *   3. Combine all GVCFs into a GenomicsDB store and jointly genotype
 *      the cohort with GATK GenomicsDBImport + GenotypeGVCFs
 *   4. Collect QC (samtools stats/flagstat + bcftools stats) into a
 *      single aggregated MultiQC report
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
    // Fail fast: no point staging references or pulling containers
    // if the samplesheet didn't resolve to any samples.
    reads_ch.ifEmpty { error "No samples found. Check your samplesheet: ${params.input}" }

    // Load the reference genome and accessory files once, up front,
    // so every process call fails fast if any of them is missing.
    ref_fasta = file(params.reference,       checkIfExists: true)
    ref_index = file(params.reference_index, checkIfExists: true)
    ref_dict  = file(params.reference_dict,  checkIfExists: true)
    intervals = file(params.intervals,       checkIfExists: true)

    // 1. Index each BAM file
    indexed_ch = SAMTOOLS_INDEX(reads_ch).indexed_bam

    // 1b. Per-sample alignment QC (feeds into MultiQC below)
    stats_out = SAMTOOLS_STATS(indexed_ch)

    // 2. Per-sample variant calling in GVCF mode
    gvcf_ch = GATK_HAPLOTYPECALLER(
        indexed_ch,
        ref_fasta,
        ref_index,
        ref_dict,
        intervals
    ).gvcf

    // 3. Collect the GVCFs (and their indices) across all samples so
    //    they can be handed to a single joint-genotyping process call
    all_gvcfs_ch = gvcf_ch.map { sample_id, vcf, idx -> vcf }.collect()
    all_idxs_ch  = gvcf_ch.map { sample_id, vcf, idx -> idx }.collect()

    // 4. Combine into a GenomicsDB store and jointly genotype the cohort
    joint_ch = GATK_JOINTGENOTYPING(
        all_gvcfs_ch,
        all_idxs_ch,
        intervals,
        params.cohort_name,
        ref_fasta,
        ref_index,
        ref_dict
    )

    // 4b. Variant-calling QC on the joint VCF
    vcf_stats_out = BCFTOOLS_STATS(joint_ch.vcf, params.cohort_name)

    // 5. Aggregate every QC report into one MultiQC dashboard. `.mix()`
    //    combines the different report channels; `.collect()` gathers
    //    them into a single list so MultiQC only runs once, after
    //    everything else has finished.
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
