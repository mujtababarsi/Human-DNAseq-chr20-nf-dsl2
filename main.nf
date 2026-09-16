#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// --help is handled automatically by nf-schema (see nextflow.config)
include { DNASEQ_WORKFLOW }                     from './workflows/dnaseq.nf'
include { validateParameters; paramsSummaryLog } from 'plugin/nf-schema'

workflow {
    // Validate params against nextflow_schema.json
    validateParameters()
    log.info paramsSummaryLog(workflow)

    // Build input channel from the samplesheet
    // Columns: sample_id, reads_bam (absolute path or relative to project dir)
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