#!/usr/bin/env nextflow
/*
  Nextflow Pipeline for QIIME Workflow:
    - FastQC → MultiQC
    - QIIME Tools Import
    - QIIME Cutadapt Primer Trimming
    - QIIME DADA2 denoise-ccs (two runs with different primers)
    - Taxonomic Classification
    - Metadata and Representative Sequence Visualization
*/

params {
    // Paths to tools (update these as needed)
    fastqc = '/path/to/FastQC/fastqc'
    multiqc = 'multiqc'         // assuming in $PATH
    qiime  = 'qiime'             // assuming QIIME2 is in $PATH

    // Directories and files (use generic names)
    fastqc_out = 'fastqc_output'
    input_fastq = '*.fastq.gz'
    manifest   = 'manifest.tsv'
    classifier = 'silva_classifier.qza'
}

workflow {

    // Step 1: FastQC
    fastqc_ch = fastqc_process(params.input_fastq)

    // Step 2: MultiQC in FastQC output directory
    multiqc_ch = multiqc_process(fastqc_ch)

    // Step 3: QIIME Import (using manifest)
    qiime_import_ch = qiime_import_process(params.manifest)

    // Step 4: QIIME Cutadapt Primer Trimming
    qiime_cutadapt_ch = qiime_cutadapt_process(qiime_import_ch)

    // Step 5: QIIME DADA2 denoise-ccs (first run)
    dada2_ch = qiime_dada2_process(qiime_import_ch, 'AGRGTTYGATYMTGGCTCAG', 'RGYTACCTTGTTACGACTT', 0, 1000, 1600)

    // Step 6: QIIME DADA2 denoise-ccs (second run)
    dada2_v2_ch = qiime_dada2_process(qiime_import_ch, 'GUUCAGAGUUCUACAGUCCGACGAUC', 'TGGAATTCTCGGGTGCCAAGG', 40, 1000, 1600)

    // Step 7: QIIME Taxonomic Classification using first DADA2 rep-seqs
    taxonomy_ch = qiime_tax_class_process(dada2_ch.rep_seqs, params.classifier)

    // Step 8: Visualization of Denoising Stats and Representative Sequences
    metadata_viz_ch = qiime_metadata_process(dada2_ch.stats)
    repseqs_viz_ch  = qiime_tabulate_seqs_process(dada2_ch.rep_seqs)

    // Publish outputs (example: you might want to copy them to a results folder)
    taxonomy_ch.view()
    metadata_viz_ch.view()
    repseqs_viz_ch.view()
}

process fastqc_process {
    tag "$sample"

    input:
    file sample from file(params.input_fastq)

    output:
    file "${sample.simpleName}_fastqc.zip" into fastqc_results

    script:
    """
    mkdir -p ${params.fastqc_out}
    ${params.fastqc} -t 50 -o ${params.fastqc_out} ${sample}
    """
}

process multiqc_process {
    input:
    file(fastqc_zip) from fastqc_results.collect()

    output:
    file "multiqc_report.html" into multiqc_report

    script:
    """
    cd ${params.fastqc_out}
    ${params.multiqc} .
    """
}

process qiime_import_process {
    input:
    file(manifest_file) from file(params.manifest)

    output:
    file "full_length.qza" into qiime_imported

    script:
    """
    ${params.qiime} tools import \\
      --type 'SampleData[SequencesWithQuality]' \\
      --input-path ${manifest_file} \\
      --input-format SingleEndFastqManifestPhred33V2 \\
      --output-path full_length.qza
    """
}

process qiime_cutadapt_process {
    input:
    file(full_length) from qiime_imported

    output:
    file "trimmed_seqs.qza" into qiime_trimmed
    file "cutadapt_log.txt" into cutadapt_log

    script:
    """
    ${params.qiime} cutadapt trim-single \\
      --i-demultiplexed-sequences ${full_length} \\
      --p-front AGRGTTYGATYMTGGCTCAG \\
      --p-adapter RGYTACCTTGTTACGACTT \\
      --o-trimmed-sequences trimmed_seqs.qza \\
      --verbose > cutadapt_log.txt
    """
}

process qiime_dada2_process {
    /*
      This process runs qiime dada2 denoise-ccs.
      It takes parameters for primer sequences, thread count, and min/max lengths.
      The output includes: table.qza, rep_seqs.qza, and denoising_stats.qza.
    */
    input:
    file(full_length) from qiime_imported
    val(primer_front)
    val(primer_adapter)
    val(nthreads)
    val(min_len)
    val(max_len)

    output:
    file "table.qza" into dada2_table
    file "rep_seqs.qza" into dada2_rep_seqs
    file "denoising_stats.qza" into dada2_stats

    script:
    """
    ${params.qiime} dada2 denoise-ccs \\
      --i-demultiplexed-seqs ${full_length} \\
      --p-front ${primer_front} \\
      --p-adapter ${primer_adapter} \\
      --p-min-len ${min_len} \\
      --p-max-len ${max_len} \\
      --o-table table.qza \\
      --o-representative-sequences rep_seqs.qza \\
      --o-denoising-stats denoising_stats.qza \\
      --p-n-threads ${nthreads}
    """
}

process qiime_tax_class_process {
    input:
    file rep_seqs from dada2_rep_seqs
    val(classifier_path)

    output:
    file "taxonomy.qza" into taxonomy

    script:
    """
    ${params.qiime} feature-classifier classify-sklearn \\
      --i-classifier ${classifier_path} \\
      --i-reads ${rep_seqs} \\
      --o-classification taxonomy.qza
    """
}

process qiime_metadata_process {
    input:
    file(stats) from dada2_stats

    output:
    file "denoising_stats.qzv" into metadata_viz

    script:
    """
    ${params.qiime} metadata tabulate \\
      --m-input-file ${stats} \\
      --o-visualization denoising_stats.qzv
    """
}

process qiime_tabulate_seqs_process {
    input:
    file(rep_seqs) from dada2_rep_seqs

    output:
    file "rep_seqs.qzv" into repseqs_viz

    script:
    """
    ${params.qiime} feature-table tabulate-seqs \\
      --i-data ${rep_seqs} \\
      --o-visualization rep_seqs.qzv
    """
}
