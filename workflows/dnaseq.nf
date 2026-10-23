/*
 * DNASEQ WORKFLOW
 * Index BAMs, call variants per sample, joint-genotype the cohort, run QC,
 * then optionally annotate (coordinate shift -> ClinVar -> SnpEff -> filters).
 */

include { SAMTOOLS_INDEX }       from '../modules/samtools_index.nf'
include { SAMTOOLS_STATS }       from '../modules/samtools_stats.nf'
include { GATK_HAPLOTYPECALLER } from '../modules/gatk_haplotypecaller.nf'
include { GATK_JOINTGENOTYPING } from '../modules/gatk_jointgenotyping.nf'
include { BCFTOOLS_STATS }       from '../modules/bcftools_stats.nf'
include { MULTIQC }              from '../modules/multiqc.nf'
include { SHIFT_COORDINATES }    from '../modules/shift_coordinates.nf'
include { CLINVAR_ANNOTATE }     from '../modules/clinvar_annotate.nf'
include { SNPEFF }               from '../modules/snpeff.nf'
include { FILTER_VARIANTS }      from '../modules/filter_variants.nf'

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

    // Optional annotation. Each step takes the previous step's VCF and is
    // skipped when its param is unset, so annot_vcf_ch is whatever ran last.
    annot_vcf_ch     = joint_ch.vcf
    ref_check_ch     = channel.empty()
    snpeff_csv_ch    = channel.empty()
    snpeff_html_ch   = channel.empty()
    filter_summary   = channel.empty()
    de_novo_ch       = channel.empty()
    protein_alt_ch   = channel.empty()

    // Shift excerpt coordinates onto the full chromosome (+ optional REF check)
    if (params.contig_offset != null) {
        check_fasta = params.ref_check_fasta ? file(params.ref_check_fasta,          checkIfExists: true) : []
        check_fai   = params.ref_check_fasta ? file("${params.ref_check_fasta}.fai", checkIfExists: true) : []
        shift_out = SHIFT_COORDINATES(
            annot_vcf_ch,
            params.cohort_name,
            params.source_contig,
            params.target_contig,
            params.target_contig_length,
            params.contig_offset,
            check_fasta,
            check_fai
        )
        annot_vcf_ch = shift_out.vcf
        ref_check_ch = shift_out.ref_check
    } else if (params.ref_check_fasta) {
        log.warn "--ref_check_fasta is ignored without --contig_offset"
    }

    // ClinVar clinical significance
    if (params.clinvar) {
        clinvar_vcf = file(params.clinvar,          checkIfExists: true)
        clinvar_tbi = file("${params.clinvar}.tbi", checkIfExists: true)
        annot_vcf_ch = CLINVAR_ANNOTATE(annot_vcf_ch, clinvar_vcf, clinvar_tbi, params.cohort_name).vcf
    }

    // Functional effect prediction (skipped in CI: the database is large)
    if (params.snpeff_db) {
        snpeff_db = file(params.snpeff_db, checkIfExists: true)
        file("${params.snpeff_db}/${params.snpeff_genome}/snpEffectPredictor.bin", checkIfExists: true)
        snpeff_out     = SNPEFF(annot_vcf_ch, snpeff_db, params.snpeff_genome, params.cohort_name)
        annot_vcf_ch   = snpeff_out.vcf
        snpeff_csv_ch  = snpeff_out.csv
        snpeff_html_ch = snpeff_out.html
    }

    // Trio filters: protein-altering (needs SnpEff) and de novo
    if (params.proband && params.father && params.mother) {
        filter_out = FILTER_VARIANTS(
            annot_vcf_ch,
            params.cohort_name,
            params.proband,
            params.father,
            params.mother
        )
        filter_summary = filter_out.summary
        de_novo_ch     = filter_out.de_novo
        protein_alt_ch = filter_out.protein_altering
    }

    // Combine all QC reports and run MultiQC once
    qc_files_ch = stats_out.stats
        .mix(stats_out.flagstat)
        .mix(vcf_stats_out.stats)
        .mix(snpeff_csv_ch)
        .collect()

    multiqc_out = MULTIQC(qc_files_ch)

    emit:
    indexed_bam    = indexed_ch          // tuple(sample_id, bam, bai)
    gvcf           = gvcf_ch             // tuple(sample_id, gvcf, gvcf_idx)
    joint_vcf      = joint_ch.vcf
    joint_idx      = joint_ch.idx
    bcftools_stats = vcf_stats_out.stats
    multiqc_report = multiqc_out.report
    // Annotation outputs (empty when the matching step was skipped)
    annotated_vcf      = annot_vcf_ch        // joint VCF if no annotation step ran
    ref_check          = ref_check_ch
    snpeff_html        = snpeff_html_ch
    de_novo            = de_novo_ch
    protein_altering   = protein_alt_ch
    annotation_summary = filter_summary
}