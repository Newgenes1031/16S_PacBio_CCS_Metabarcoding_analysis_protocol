# 16S_PacBio_CCS_Metabarcoding_analysis_protocol
Welcome! 🚀

If you’re new to metabarcoding analysis and working with 16S rRNA full-length sequences from PacBio CCS reads, you’ve come to the right place!

In this guide, I’ll walk you through the entire analysis pipeline – from raw data processing to taxonomic classification.

Let’s get started! 🔬🧬

# 1. Rawdata processing
Before diving into the analysis, it’s essential to inspect the raw data. This is a fundamental and crucial step in any workflow.

Personally, I prefer using FastQC → MultiQC, as MultiQC provides an intuitive report and is easy to run from the CLI.

Of course, the general approach remains the same, but feel free to use different tools that best suit your workflow! 🚀

### FastQC command line
```Linux command
/path/to/FastQC {Input file path} -t {Choose your thread numbers} -o {Output file name}
```
Next, we’ll run MultiQC to aggregate and visualize the results from FastQC.

### MultiQC command line
```Linux command
/path/to/multiqc .
```

After running MultiQC, you can check your raw data quality using the generated multiqc_report.html file.

If your raw reads are too short or too long compared to the expected length (e.g., 16S rRNA Full-length ≈ 1,550 bp), you may need to filter them out in later QC steps.
Think of this process as deciding how strictly you’ll filter the data in the next steps! 🚀


# 2. Qiime import
For metabarcoding analysis, I use QIIME 2, one of the most widely used platforms in the field.

Most bioinformatics software, including QIIME 2, supports Bioconda and Conda, making installation straightforward.
The official QIIME 2 documentation also provides great tutorials, especially for those working with Illumina & Pyrosequencing reads.

However, QIIME 2 does not yet have an official guide for PacBio CCS long reads.
That’s why I’m documenting my approach—so others in the same situation can find a reference!

🔹 QIIME 2 Installation

I assume you already have QIIME 2 installed.
Since I’m working with amplicon sequencing data, I installed the Amplicon version of QIIME 2 (version 2024.10).
Even though QIIME 2 updates regularly, the core analysis workflow remains mostly the same, so I continue using 2024.10.

🔹 Importing Data into QIIME 2

QIIME 2 requires all input data to be in .qza format.
Before running the import step, make sure you know:
	1.	What type of files you have (.fastq, .fasta, etc.)
	2.	Where your files are located (the exact file path)
	3.	What format you need (.qza, .qzv, etc.)

Since PacBio CCS 16S sequencing data is provided in .fastq.gz format, we need to convert it into QIIME 2’s .qza format before proceeding with the analysis.


### QZA importing command line
```Linux command
qiime tools import \
  --type 'SampleData[SequencesWithQuality]' \
  --input-path manifest.tsv \
  --input-format SingleEndFastqManifestPhred33V2 \
  --output-path ccs_reads.qza
```
We are working with PacBio CCS reads, which are:
✅ Single-end reads
✅ Phred33V2 quality scores
✅ FASTQ format with quality scores included

Based on these properties, we used the following command to import the data into QIIME 2, generating the ccs_reads.qza file.

🔹 Why is the input file a .tsv instead of .fastq.gz?

You might notice that the input path ends with .tsv, which may seem unexpected.
This is because we are using the “SingleEndFastqManifestPhred33V2” input format, meaning that all input files are referenced through a Manifest file instead of being passed directly.

🔹 What is a Manifest file?

A Manifest file contains the absolute paths to all .fastq.gz input files.
The file must follow a specific format with three headers:
```
sample-id   absolute-filepath   direction
```

After creating and properly formatting the Manifest.tsv file, you can specify it as the input-path, and the import will be successful.


# 3. Primer sequences trimming
Since the sequencing provider already demultiplexed the reads before delivering the raw data, we can skip the demultiplexing step.
(If you need to demultiplex manually, the process is similar for both Illumina and PacBio as long as you have barcode sequence information.)

For 16S rRNA Full-length sequencing, we need to remove the primers that were used during amplicon generation.

🔹 Commonly Used 16S rRNA Full-Length Primers

The universal V1–V9 primer sequences are as follows:
```
V1F(27): AGRGTTYGATYMTGGCTCAG
V9R(1492): RGYTACCTTGTTACGACTT 
```
Using these sequences, we will proceed with primer trimming in QIIME 2. 🚀

### Primer trimming command line
```
qiime cutadapt trim-single \
   --i-demultiplexed-sequences ccs_reads.qza \
   --p-front AGRGTTYGATYMTGGCTCAG \
   --p-adapter RGYTACCTTGTTACGACTT \
   --o-trimmed-sequences ccs_trimmed_reads.qza \
   --verbose > ccs_trimming_log.txt
```

I performed primer trimming using Cutadapt, a tool integrated within QIIME 2.

Since we are working with Single-End FASTQ files, I used the trim-single option.
For --front (5’) and --adapter (3’), I specified the Forward Primer (27F) and Reverse Primer (1492R), respectively.

🔹 But wait…!!

On the Illumina sequencing platform, we typically trim primers using Cutadapt before proceeding with downstream analysis.

However, with PacBio CCS reads, a new DADA2 option now includes primer trimming as part of its pipeline!

Why is this important?
	•	Instead of running Cutadapt → DADA2, we can perform all trimming directly in DADA2.
	•	This improves workflow consistency and ensures better integration with DADA2’s error correction model.

Interestingly, when comparing trimming logs from both approaches, I noticed differences in the reported trimming statistics.
I’m still investigating the cause—if anyone has insights, feel free to reach out via direct messages! 🙌


# 4. Primer sequences trimming + Feature extraction + Denoising (DADA2)

DADA2 is one of the most widely used tools for quality control in metabarcoding analysis.
It performs de novo denoising by removing PCR errors, chimeric sequences, and more.

🔹 Why DADA2?
	•	Instead of clustering into OTUs (Operational Taxonomic Units), DADA2 provides ASVs (Amplicon Sequence Variants).
	•	ASVs provide higher accuracy while generating fewer total features than OTUs.
	•	Multiple studies have shown that ASV-based methods outperform traditional OTU clustering in accuracy.
	•	Most importantly, DADA2 is one of the few tools that directly supports PacBio CCS reads, which was a major factor in my decision to use it!

Now, let’s dive into the DADA2 command I used for analysis! 🚀

### Qiime DADA2 denoise-ccs command line
```Linux command
qiime dada2 denoise-ccs \
   --i-demultiplexed-seqs ccs_reads.qza \
   --p-front AGRGTTYGATYMTGGCTCAG \
   --p-adapter RGYTACCTTGTTACGACTT \
   --p-min-len 1000 \
   --p-max-len 1600 \
   --o-table ccs_table.qza \
   --o-representative-sequences ccs_rep-reads.qza \
   --o-denoising-stats ccs_denoising-stats.qza \
   --p-n-threads 0 #if you want to use all threads you can use, type 0
```

We will use ccs_reads.qza (generated from raw data) as the input for DADA2.

For --p-front / --p-adapter, I specified the primer sequences according to the correct orientation.
For --p-min-len / --p-max-len, I followed the recommended DADA2 denoise-ccs length settings (1,000 - 1,600 bp).

🔹 Output Files from DADA2

Running DADA2 generates three key outputs:

1️⃣ Feature Table (table.qza) → The number of unique features detected (Dereplicated Features)
2️⃣ Representative Sequences (rep-seqs.qza) → The actual sequences of the identified features
3️⃣ Denoising Statistics (denoising-stats.qza) → Filtering statistics, showing how reads were processed and retained

🔹 Filtering Low-Frequency Features

In my case, I applied Filter-features with a minimum frequency of 2.

Why? 🤔
	•	A feature that appears only once (frequency = 1) could be a random sequencing error rather than a true biological signal.
	•	So, I filtered out singleton features (frequency = 1) to improve the reliability of my results.

Of course, this threshold is flexible—you can apply stricter filters (e.g., 5 or 10) depending on your analysis needs.

# 5. Taxonomical classification
Now that we have an ASV table (table.qza) and representative reads (rep-seqs.qza), we need to assign taxonomy to our ASV features.

If you inspect the ASV table, you’ll notice that feature names are in MD5 hash format.
These hashed IDs allow us to differentiate ASVs, but we don’t yet know which taxonomy each feature belongs to—for that, we need a classifier.

(Alternatively, you could export rep-seqs.qza and manually run BLAST search… but let’s be real, that would be exhausting! 😅)

🔹 Choosing a Classifier

For taxonomic classification, I used a Naive Bayes classifier.

This is a classic machine-learning algorithm that classifies sequences based on conditional probabilities of each taxonomy.

While alternative methods like BLASTN or Usearch exist, I prefer Naive Bayes because:
✅ It is computationally efficient, as it compares k-mers instead of aligning full sequences
✅ It is widely used and well-validated for 16S metabarcoding

🔹 Reference Database Selection

To train the Naive Bayes classifier, we need a reference database.
For 16S rRNA, the most commonly used reference is Silva.

I used the Silva 138.2 database (latest version) for training.

However, downloading raw sequences and manually preparing the taxonomy files can be time-consuming and tedious.

Luckily, the QIIME 2 RESCRIPt plugin makes this process much easier! 🚀

Next, I’ll show how I used RESCRIPt to train my classifier. 😊

### Classifier training command line
```Linux command
qiime rescript get-silva-data \
   --p-version '138.2' \
   --p-include-species-labels \
   --p-target 'SSURef_NR99' \
   --o-silva-sequences silva-138.2-ssu-nr99-rna-seqs.qza \
   --o-silva-taxonomy silva-138.2-ssu-nr99-tax.qza
```

Using the RESCRIPt plugin in QIIME 2, we can easily obtain reference sequences and taxonomy files with just one command:

### Classifier training command line
```Linux command
qiime rescript reverse-transcribe \
   --i-rna-sequences silva-138.2-ssu-nr99-rna-seqs.qza \
   --o-dna-sequences silva-138.2-ssu-nr99-seqs.qza

qiime rescript cull-seqs \
   --i-sequences silva-138.2-ssu-nr99-seqs.qza \
   --o-clean-sequences silva-138.2-ssu-nr99-seqs-cleaned.qza

qiime rescript filter-seqs-length-by-taxon \
   --i-sequences silva-138.2-ssu-nr99-seqs-cleaned.qza \
   --i-taxonomy silva-138.2-ssu-nr99-tax.qza \
   --p-labels Archaea Bacteria Eukaryota \
   --p-min-lens 900 1200 1400 \
   --o-filtered-seqs silva-138.2-ssu-nr99-seqs-filt.qza \
   --o-discarded-seqs silva-138.2-ssu-nr99-seqs-discard.qza

qiime rescript dereplicate \
   --i-sequences silva-138.2-ssu-nr99-seqs-filt.qza  \
   --i-taxa silva-138.2-ssu-nr99-tax.qza \
   --p-mode 'uniq' \
   --o-dereplicated-sequences silva-138.2-ssu-nr99-seqs-derep-uniq.qza \
   --o-dereplicated-taxa silva-138.2-ssu-nr99-tax-derep-uniq.qza

qiime rescript evaluate-fit-classifier \
   --i-sequences silva-138.2-ssu-nr99-seqs-derep-uniq.qza \
   --i-taxonomy silva-138.2-ssu-nr99-tax-derep-uniq.qza  \
   --o-classifier silva-138.2-ssu-nr99-classifier.qza \
   --o-observed-taxonomy silva-138.2-ssu-nr99-predicted-taxonomy.qza \
   --o-evaluation silva-138.2-ssu-nr99-fit-classifier-evaluation.qzv
```

By following these steps, we can train a Naive Bayes classifier using the Silva 138.2 database for taxonomy assignment in QIIME 2.
🎉 And that’s it! We now have a trained Naive Bayes classifier (silva-138.2-classifier.qza) ready to assign taxonomy to our ASVs!
   * I can’t express enough gratitude to the developers of the RESCRIPt plugin for making this process so much easier! 🙌
(출처: https://forum.qiime2.org/t/processing-filtering-and-evaluating-the-silva-database-and-other-reference-sequence-data-with-rescript/15494)

Next, let’s use this classifier to assign taxonomy to our ASV table! 🚀

### Classifier running command line
```Linux command
qiime feature-classifier classify-sklearn \
   --i-classifier silva-138.2-ssu-nr99-classifier.qza \
   --i-reads ccs_rep-reads.qza \
   --o-classification ccs_taxonomy.qza
```
🔹 Generating a Taxonomy Bar Plot

Now that we have our ccs_taxonomy.qza file, we can visualize the taxonomic composition of our samples by creating a bar plot!

Run the following command in QIIME 2:

### Creating Barplot command line
```Linux command
qiime taxa barplot \
   --i-table ccs_table.qza \
   --i-taxonomy ccs_taxonomy.qza \
   --o-classification ccs_barplot.qzv
```

This will generate a barplot.qzv file, which we can explore using QIIME 2 View:

🔗 QIIME 2 View

Simply upload your barplot.qzv file, and you’ll be able to interactively explore the taxonomic distribution within your samples! 🎉

## References

1. Michael S Robeson II, Devon R O'Rourke, Benjamin D Kaehler, Michal Ziemski, Matthew R Dillon, Jeffrey T Foster, Nicholas A Bokulich. 2021. "RESCRIPt: Reproducible sequence taxonomy reference database management". PLoS Computational Biology 17 (11): e1009581.; doi: 10.1371/journal.pcbi.1009581
2. Bolyen E, Rideout JR, Dillon MR, Bokulich NA, Abnet CC, Al-Ghalith GA, Alexander H, Alm EJ, Arumugam M, Asnicar F, Bai Y, Bisanz JE, Bittinger K, Brejnrod A, Brislawn CJ, Brown CT, Callahan BJ, Caraballo-Rodríguez AM, Chase J, Cope EK, Da Silva R, Diener C, Dorrestein PC, Douglas GM, Durall DM, Duvallet C, Edwardson CF, Ernst M, Estaki M, Fouquier J, Gauglitz JM, Gibbons SM, Gibson DL, Gonzalez A, Gorlick K, Guo J, Hillmann B, Holmes S, Holste H, Huttenhower C, Huttley GA, Janssen S, Jarmusch AK, Jiang L, Kaehler BD, Kang KB, Keefe CR, Keim P, Kelley ST, Knights D, Koester I, Kosciolek T, Kreps J, Langille MGI, Lee J, Ley R, Liu YX, Loftfield E, Lozupone C, Maher M, Marotz C, Martin BD, McDonald D, McIver LJ, Melnik AV, Metcalf JL, Morgan SC, Morton JT, Naimey AT, Navas-Molina JA, Nothias LF, Orchanian SB, Pearson T, Peoples SL, Petras D, Preuss ML, Pruesse E, Rasmussen LB, Rivers A, Robeson MS, Rosenthal P, Segata N, Shaffer M, Shiffer A, Sinha R, Song SJ, Spear JR, Swafford AD, Thompson LR, Torres PJ, Trinh P, Tripathi A, Turnbaugh PJ, Ul-Hasan S, van der Hooft JJJ, Vargas F, Vázquez-Baeza Y, Vogtmann E, von Hippel M, Walters W, Wan Y, Wang M, Warren J, Weber KC, Williamson CHD, Willis AD, Xu ZZ, Zaneveld JR, Zhang Y, Zhu Q, Knight R, and Caporaso JG. 2019. Reproducible, interactive, scalable and extensible microbiome data science using QIIME 2. Nature Biotechnology 37: 852–857. https://doi.org/10.1038/s41587-019-0209-9
3. Callahan BJ, McMurdie PJ, Rosen MJ, Han AW, Johnson AJ, Holmes SP. DADA2: High-resolution sample inference from Illumina amplicon data. Nat Methods. 2016 Jul;13(7):581-3. doi: 10.1038/nmeth.3869. Epub 2016 May 23. PMID: 27214047; PMCID: PMC4927377.
