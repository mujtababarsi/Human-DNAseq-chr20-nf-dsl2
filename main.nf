#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
 * 1. Load the pipeline sub-workflow and schema-validation helpers.
 *    --help / --helpFull are intercepted automatically by nf-schema
 *    (see the `validation.help` block in nextflow.config) — no manual
 *    check needed here since nf-schema v2.1.0.
 */
include { DNASEQ_WORKFLOW }               from './workflows/dnaseq.nf'
include { validateParameters; paramsSummaryLog } from 'plugin/nf-schema'

/*
 * 2. Entry point. All executable statements must live inside a
 *    workflow/process/function block (bare top-level statements are
 *    rejected by the Nextflow language parser).
 */
workflow {
    // Validate parameters against nextflow_schema.json
    validateParameters()
    log.info paramsSummaryLog(workflow)

    // Build the input channel from the samplesheet.
    // Expected columns: sample_id, reads_bam
    // `reads_bam` may be an absolute path, or a path relative to the
    // project directory (used by the bundled `-profile test` dataset).
    reads_ch = Channel
        .fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true)
        .map { row ->
            def bam_path = row.reads_bam.startsWith('/')
                ? row.reads_bam
                : "${projectDir}/${row.reads_bam}"
            tuple(row.sample_id, file(bam_path, checkIfExists: true))
        }

    DNASEQ_WORKFLOW(reads_ch)
}