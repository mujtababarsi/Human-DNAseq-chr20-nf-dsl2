#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
 * 1. Load the pipeline sub-workflow
 */
include { DNASEQ_WORKFLOW } from './workflows/dnaseq.nf'

/*
 * 2. Build the input channel from the samplesheet.
 *    Expected columns: sample_id, reads_bam
 *    `reads_bam` may be an absolute path, or a path relative to the
 *    project directory (used by the bundled `-profile test` dataset).
 */
Channel
    .fromPath(params.input, checkIfExists: true)
    .splitCsv(header: true)
    .map { row ->
        def bam_path = row.reads_bam.startsWith('/')
            ? row.reads_bam
            : "${projectDir}/${row.reads_bam}"
        tuple(row.sample_id, file(bam_path, checkIfExists: true))
    }
    .set { reads_ch }

/*
 * 3. Run the workflow
 */
workflow {
    DNASEQ_WORKFLOW(reads_ch)
}
