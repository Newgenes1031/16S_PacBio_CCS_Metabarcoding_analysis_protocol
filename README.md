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
