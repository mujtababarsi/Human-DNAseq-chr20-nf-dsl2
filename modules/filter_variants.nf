#!/usr/bin/env nextflow

/*
 * Pull out the trio variants worth a closer look:
 *   - protein-altering: SnpEff impact HIGH or MODERATE (only if INFO/ANN is present)
 *   - de novo: proband heterozygous, both parents homozygous reference
 * Sample columns are looked up by name, so column order does not matter.
 * Also writes a one-table count summary of the annotation steps.
 */
process FILTER_VARIANTS {

    tag "$cohort_name"
    label 'process_low'
    publishDir "${params.outdir}/annotation", mode: 'copy'

    conda "${projectDir}/envs/bcftools.yml"
    container 'quay.io/biocontainers/bcftools:1.23.1--hb2cee57_0'

    input:
    path vcf
    val  cohort_name
    val  proband
    val  father
    val  mother

    output:
    path "${cohort_name}.de_novo.vcf.gz"         , emit: de_novo
    path "${cohort_name}.protein_altering.vcf.gz", emit: protein_altering, optional: true
    path "${cohort_name}.annotation_summary.tsv" , emit: summary

    script:
    """
    # 0-based column index of a sample, or fail if the name is not in the VCF
    sample_index() {
        bcftools query -l ${vcf} | awk -v s="\$1" '\$0 == s { print NR - 1; found = 1 } END { exit !found }' \\
            || { echo "ERROR: sample '\$1' not found in ${vcf} (samples: \$(bcftools query -l ${vcf} | paste -sd,))" >&2; exit 1; }
    }
    p=\$(sample_index '${proband}')
    f=\$(sample_index '${father}')
    m=\$(sample_index '${mother}')

    count() { bcftools view -H "\$@" | wc -l; }
    has_info() { bcftools view -h ${vcf} | grep -q "^##INFO=<ID=\$1,"; }

    bcftools view \\
        -i "GT[\$p]=\\"het\\" && GT[\$f]=\\"RR\\" && GT[\$m]=\\"RR\\"" \\
        -Oz -o ${cohort_name}.de_novo.vcf.gz ${vcf}

    if has_info ANN; then
        bcftools view \\
            -i 'INFO/ANN~"[|]HIGH[|]" || INFO/ANN~"[|]MODERATE[|]"' \\
            -Oz -o ${cohort_name}.protein_altering.vcf.gz ${vcf}
        n_protein=\$(count ${cohort_name}.protein_altering.vcf.gz)
    else
        n_protein=NA
    fi

    if has_info CLNSIG; then
        n_clinvar=\$(count -e 'INFO/CLNSIG="."' ${vcf})
    else
        n_clinvar=NA
    fi

    {
        printf 'metric\\tcount\\n'
        printf 'total_variants\\t%s\\n'    "\$(count ${vcf})"
        printf 'clinvar_annotated\\t%s\\n' "\${n_clinvar}"
        printf 'protein_altering\\t%s\\n'  "\${n_protein}"
        printf 'de_novo\\t%s\\n'           "\$(count ${cohort_name}.de_novo.vcf.gz)"
    } > ${cohort_name}.annotation_summary.tsv
    """
}
