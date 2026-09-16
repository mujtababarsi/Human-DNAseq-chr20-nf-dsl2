#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
 * 1. Load the pipeline sub-workflow and schema-validation helpers
 */
include { DNASEQ_WORKFLOW } from './workflows/dnaseq.nf'
include { validateParameters; paramsHelp; paramsSummaryLog } from 'plugin/nf-schema'

/*
 * 2. Print help and exit, or validate parameters against nextflow_schema.json
 */
if (params.help) {
    log.info paramsHelp('nextflow run main.nf --input samplesheet.csv --reference ref.fasta --reference_index ref.fasta.fai --reference_dict ref.dict --intervals intervals.bed -profile docker')
    exit 0
}

validateParameters()
log.info paramsSummaryLog(workflow)

/*
 * 3. Build the input channel from the samplesheet.
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
 * 4. Run the workflow
 */
workflow {
    DNASEQ_WORKFLOW(reads_ch)
}
