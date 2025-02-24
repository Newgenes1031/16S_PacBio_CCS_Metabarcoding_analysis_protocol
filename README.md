# 16S_PacBio_CCS_Metabarcoding_analysis_protocol
This is an easy guide of PacBio 16S metabarcoding analysis for amateur bioinformatician

당신이 만약 처음 메타바코딩 분석을 진행한다면, 그것도 만약 16S rRNA Full-length를 대상으로 PacBio CCS reads를 가지고 있는 상태라면 잘 오셨습니다.

지금부터 Rawdata 분석부터 Taxonomical classification 까지의 분석과정을 소개할 것입니다.

## 1. Rawdata processing
분석을 시작하기 전, Rawdata부터 살펴보는 것은 아주 중요하며 기본이자 필수적인 과정입니다.
저같은 경우는 MultiQC report가 직관적이고 CLI에서 수행하기 편리하기 때문에, FastQC -> MultiQC 방식을 선호합니다.

분석 방향은 비슷하되, 다른 Tools을 사용하는 것은 언제나 환영입니다.

### FastQC command line
```Linux command
/path/to/FastQC {Input file path} -t {Choose your thread numbers} -o {Output file name}
```
