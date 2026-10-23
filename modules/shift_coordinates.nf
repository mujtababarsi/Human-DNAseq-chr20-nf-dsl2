#!/usr/bin/env nextflow

/*
 * Lift a VCF called against a reference excerpt onto full-chromosome
 * coordinates: rename the excerpt contig, add a fixed offset to POS and
 * rewrite its ##contig header line. Optionally confirm that every REF
 * allele matches a full-chromosome FASTA (bcftools norm --check-ref e),
 * failing the run on any mismatch.
 */
process SHIFT_COORDINATES {

    tag "$cohort_name"
    label 'process_low'
    publishDir "${params.outdir}/annotation", mode: 'copy'

    conda "${projectDir}/envs/bcftools.yml"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'

    input:
    path vcf
    val  cohort_name
    val  source_contig
    val  target_contig
    val  target_contig_length
    val  offset
    path ref_check_fasta   // [] to skip the REF check
    path ref_check_fai     // [] to skip the REF check

    output:
    path "${cohort_name}.shifted.vcf.gz"    , emit: vcf
    path "${cohort_name}.shifted.vcf.gz.tbi", emit: tbi
    path "${cohort_name}.ref_check.txt"     , emit: ref_check, optional: true

    script:
    def ref_check = ref_check_fasta ? """
    n_records=\$(bcftools view -H ${cohort_name}.shifted.vcf.gz | wc -l)
    bcftools norm --check-ref e -f ${ref_check_fasta} -Ou -o /dev/null ${cohort_name}.shifted.vcf.gz
    echo "REF check passed: \${n_records}/\${n_records} records match ${ref_check_fasta}" > ${cohort_name}.ref_check.txt
    """ : ''
    """
    # Fail if the excerpt contig is absent: the offset would then be meaningless
    if ! grep -q '^##contig=<ID=${source_contig},' ${vcf}; then
        echo "ERROR: contig '${source_contig}' not found in the header of ${vcf}" >&2
        exit 1
    fi

    awk -v src='${source_contig}' -v dst='${target_contig}' \\
        -v len='${target_contig_length}' -v off='${offset}' '
        BEGIN { OFS = "\\t" }
        index(\$0, "##contig=<ID=" src ",") == 1 { print "##contig=<ID=" dst ",length=" len ">"; next }
        /^#/ { print; next }
        \$1 == src { \$1 = dst; \$2 = \$2 + off }
        { print }
    ' ${vcf} \\
        | bcftools view -Oz -o ${cohort_name}.shifted.vcf.gz

    bcftools index -t ${cohort_name}.shifted.vcf.gz
    ${ref_check}
    """
}
