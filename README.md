# 16S_PacBio_CCS_Metabarcoding_analysis_protocol
This is an easy guide of PacBio 16S metabarcoding analysis for amateur bioinformatician

당신이 만약 처음 메타바코딩 분석을 진행한다면, 그것도 만약 16S rRNA Full-length를 대상으로 PacBio CCS reads를 가지고 있는 상태라면 잘 오셨습니다.

지금부터 Rawdata 분석부터 Taxonomical classification 까지의 분석과정을 소개할 것입니다.

# 1. Rawdata processing
분석을 시작하기 전, Rawdata부터 살펴보는 것은 아주 중요하며 기본이자 필수적인 과정입니다.
저같은 경우는 MultiQC report가 직관적이고 CLI에서 수행하기 편리하기 때문에, FastQC -> MultiQC 방식을 선호합니다.

분석 방향은 비슷하되, 다른 Tools을 사용하는 것은 언제나 환영입니다.

### FastQC command line
```Linux command
/path/to/FastQC {Input file path} -t {Choose your thread numbers} -o {Output file name}
```
FastQC를 통해 얻은 result.html & result.zip 파일이 포함된 디렉토리에서 이어서 MultiQC를 수행해줍니다.

### MultiQC command line
```Linux command
/path/to/multiqc .
```

다음과 같은 방식으로 MultiQC를 수행하게 되면 "multiqc_report.html" 파일을 통해 나의 Rawdata 정보를 확인할 수 있습니다.

만약, Rawdata가 원하는 길이 (ex. 16S rRNA Full-length = 1,550 bp)보다 너무 작거나 길다면 추후 QC 과정에서 제거할 수 있습니다.
이 과정이 바로 추후 분석과정에서 얼마나 Filtering 할 지 정하기 위한 과정이라고 생각하면 됩니다.


# 2. Qiime import
저는 메타바코딩 분석을 위해서 가장 대표적으로 많이 쓰이는 Qiime2 platform을 사용합니다.
대다수의 Bioinformatics Software는 Bionconda 및 Conda를 지원하고 있으며, Qiime2도 이와 마찬가지 입니다.
또한, Qiime2 공식문서에서도 좋은 튜토리얼을 통해 설명해주고 있기때문에 Illumina & Pyrosequencing Reads를 가지고 있는 사람이라면 정말 좋은 교본이 될 것입니다.

다만 Qiime2에서도 PacBio CCS Long-read에 대해서는 공식적인 문서가 아직 확인된바 없어, 저와 같이 이러한 상황에서 어떻게 분석해야할지 모르시는 분들을 위해 Qiime2 PacBio CCS 로그를 적어놓으려고 한 것입니다.

자, 여러분들께서 이미 Qiime은 설치하셨을 거라고 믿습니다.
https://docs.qiime2.org/2024.10/install/native/

저는 Amplicon sequencing 결과를 기반으로 Metabarcoding 분석을 진행하기 때문에, Amplicon 버전을 통해서 설치를 완료했구요 버전은 2024.10 버전을 쓰고있으나 크게 업데이트로 인해 분석 흐름도가 바뀌지는 않아서 저는 여전히 2024.10 버전을 사용하고 있습니다.

각자 환경에 Qiime이 설치되었다는 가정하에 설명을 이어나가보죠.

Qiime 분석을 위해서는 Qiime에서 요구하는 .qza format으로 변환해야합니다.
Import 과정에서는 
   1. 본인이 무슨 파일을 가지고 있는지 (.fastq or .fasta or etc...)
   2. 파일 경로는 정확히 어디로 설정되어있는지
   3. 변환하고자 하는 파일의 형식은 무엇인지 (.qzv or .qza or etc...)
를 반드시 고려한 뒤에 importing을 진행합니다.

16S PacBio CCS에서는 .fastq.gz 파일 형태를 제공해주기 때문에, 우리는 이에 적합한 파일형태로서 .qza format으로 변환하고자 합니다.


### QZA importing command line
```Linux command
qiime tools import \
  --type 'SampleData[SequencesWithQuality]' \
  --input-path manifest.tsv \
  --input-format SingleEndFastqManifestPhred33V2 \
  --output-path ccs_reads.qza
```
우리가 가지고 있는 PacBio CCS는 우선 Single end reads이며, Phred33V2를 사용하고, Quality score가 포함되어있는 FastQ format임을 감안해 다음과같은 명령어를 구성했고, 이를 실행하여 ccs_reads.qza 파일을 얻게 되었다.

다만 의아해할만한 것은 input-path에 File path가 .tsv로 끝난다는 것인데, input-format을 잘 보면 SingleEndFastq"Manifest"Phred33V2이다.
즉, 모든 input에 대해서 Manifest 파일을 통해 importing을 하는 것이다.

Manifest 파일에는 모든 Input file(.fastq.gz)에 대한 절대경로가 포함되어 있으며, 
header는
sample-id   absolute-filepath   direction
이 3가지 Header를 사용한다.

다음 Header에 적절하게 내용을 채운 Manifest.tsv 파일을 input-path로 넣어주면 성공적으로 Importing이 될 것이다.


# 3. Primer sequences trimming
내가 시퀀싱을 부탁한 업체에서는 Demultiplexing을 기본적으로 수행해서 Rawdata를 제공해주기 때문에, Demultiplexing 과정을 생략할 수 있었다.
Demultiplexing 과정은 Illumina나 PacBio나 크게 다르지 않기떄문에 Barcode sequence에 대한 정보가 있다면 충분히 혼자서도 수행할 수 있습니다.

우리가 16S rRNA Full-length 서열을 분석하는 과정에서, 최초로 Amplicon 을 위해 사용했던 Primer 서열에 대해 알아야 한다.

대표적으로 V1F ~ V9R Primer sequence를 사용한다.

### V1-V9 primer sequences information (Universal primer)
```
V1F(27): AGRGTTYGATYMTGGCTCAG
V9R(1492): RGYTACCTTGTTACGACTT 
```
다음 서열을 참고해서 Qiime를 통해 Primer trimming을 진행할 것이다.

### Primer trimming command line
```
qiime cutadapt trim-single \
   --i-demultiplexed-sequences ccs_reads.qza \
   --p-front AGRGTTYGATYMTGGCTCAG \
   --p-adapter RGYTACCTTGTTACGACTT \
   --o-trimmed-sequences ccs_trimmed_reads.qza \
   --verbose > ccs_trimming_log.txt
```

나는 Qiime에서 제공하는 Cutadapt을 통해 Primer trimming을 수행하였다.
SingleEnd Fastq 파일이므로 trim-single 옵션을 사용했으며, front (5')와 adatper (3')에는 각각 Forward primer (27F) / Reverse Primer (1492R) 를 기입하였다.

## 그러나!!
기존의 Illumina sequencing platform에서는 위 과정과 같이 Cutadapt을 통해서 Forward/Reverse primer trimming을 진행할 수 있었으나, PacBio CCS reads에 대해서 DADA2에서 Primer-trimming까지 진행해주는 옵션이 생기게 되었다.
따라서, 나는 DADA2와의 분석 연계성을 위해 Cutadapat -> DADA2보다는, DADA2에서 제공하는 All-in-one 방식의 분석을 진행하고자 한다.

실제로 두 과정에 따라서 발생한 결과 (Trimming log.txt 파일에서 제공하는 Trimming 결과 통계)가 다른데, 이 이유에 대해서는 아직까지 잘 모른다. (조금 더 공부해봐야 할 듯, 아시는분은 direct messages 부탁드립니다)


# 4. Primer sequences trimming + Feature extraction + Denoising (DADA2)

DADA2는 PCR error 및 Chimeric sequence 등을 제거해주는 Quality control software로 가장 대표적이다.
De novo 방식의 Denoising을 진행하며 최종적으로 ASVs (Amplicon Sequence Variants)를 제공해주는데, 기존의 OTU 방식과 사뭇 다른 방식으로 각 Feature (ex. Species)에 대한 Representative sequences를 제공해준다. OTU 방식보다는 생성되는 Feature 수가 적음에도 불구하고 정확도 측면에서 충분히 개선되었다는 논문이 다수 있어, 이를 기반으로 본인은 DADA2를 통해 분석을 진행하고자 한다.

위에서 적은 생물학적인 이유도 있겠지만, 무엇보다도 본인이 DADA2를 선택한 이유로 다른 Software에서 지원해주지 않는 CCS reads 옵션이 유일무이한 것 같아서 선택한 것도 꽤 컸다.

아무튼, DADA2 분석시 사용했던 Command는 다음과 같다.
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

