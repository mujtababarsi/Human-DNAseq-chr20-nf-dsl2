#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { DNASEQ_WORKFLOW }                                 from './workflows/dnaseq.nf'
include { validateParameters; paramsHelp; paramsSummaryLog } from 'plugin/nf-schema'

workflow {
    // Print help (generated from nextflow_schema.json) and stop before
    // validation, which would otherwise fail on the missing inputs
    if (params.help) {
        log.info paramsHelp()   // usage line comes from validation.help.command
        exit 0
    }

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