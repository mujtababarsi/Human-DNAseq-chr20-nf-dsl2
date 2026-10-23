#!/usr/bin/env nextflow

/*
 * Predict the functional effect of each variant (gene, consequence,
 * impact HIGH/MODERATE/LOW/MODIFIER) with SnpEff, using a pre-downloaded
 * database. Writes the INFO/ANN field plus HTML and CSV summaries
 * (the CSV is picked up by MultiQC).
 */
process SNPEFF {

    tag "$cohort_name"
    label 'process_medium'
    publishDir "${params.outdir}/annotation", mode: 'copy'

    conda "${projectDir}/envs/snpeff.yml"
    container 'quay.io/biocontainers/snpeff:5.4.0c--hdfd78af_0'

    input:
    path vcf
    path snpeff_db   // directory holding <genome>/snpEffectPredictor.bin
    val  genome
    val  cohort_name

    output:
    path "${cohort_name}.snpeff.vcf"      , emit: vcf
    path "${cohort_name}.snpeff.html"     , emit: html
    path "${cohort_name}.snpeff.csv"      , emit: csv
    path "${cohort_name}.snpeff.genes.txt", emit: genes

    script:
    // Leave ~20% of the task memory for the JVM itself
    def java_mem = task.memory ? "-Xmx${(task.memory.toMega() * 0.8).intValue()}m" : ''
    """
    # -dataDir must be absolute: SnpEff resolves relative paths against
    # its own config file inside the container, not the task directory
    snpEff ${java_mem} \\
        -nodownload \\
        -noLog \\
        -dataDir \$PWD/${snpeff_db} \\
        -stats ${cohort_name}.snpeff.html \\
        -csvStats ${cohort_name}.snpeff.csv \\
        ${genome} \\
        ${vcf} \\
        > ${cohort_name}.snpeff.vcf
    """

    stub:
    """
    touch ${cohort_name}.snpeff.vcf ${cohort_name}.snpeff.html ${cohort_name}.snpeff.csv ${cohort_name}.snpeff.genes.txt
    """
}
