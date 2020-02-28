import os
from snakemake.remote.S3 import RemoteProvider as S3RemoteProvider
S3 = S3RemoteProvider()

configfile: "config_s3.yaml"

source = config['source_bucket']
reference = source + "/" + config['reference']
fastq_dir = source + "/" + config['fastq_dir']

file_ids = S3.glob_wildcards(fastq_dir + "/{id}_R1_001.fastq.gz")[0]


rule all:
    input:
        expand("data/mapped/{id}.bam.bai", id=file_ids)

rule bwa_index_remote:
    input:
        S3.remote(reference + ".fa.gz")
    output:
        S3.remote(reference + ".amb"),
        S3.remote(reference + ".ann"),
        S3.remote(reference + ".bwt"),
        S3.remote(reference + ".pac"),
        S3.remote(reference + ".sa")
    log:
        "logs/bwa_index/" + os.path.basename(reference) + ".log"
    conda:
        "../envs/bwa.yaml"
    shell:
        # need to use -a bwtsw for the human genome
        "bwa index {input} -p " + reference


rule bwa_mem:
    input:
        r1 = "data/trimmed/{id}_R1_001.fastq.gz",
        r2 = "data/trimmed/{id}_R2_001.fastq.gz",
        amb = S3.remote(reference + ".amb"),
        ann = S3.remote(reference + ".ann"),
        bwt = S3.remote(reference + ".bwt"),
        pac = S3.remote(reference + ".pac"),
        sa  = S3.remote(reference + ".sa")
    output:
        "data/mapped/{id}.bam"
    log:
        "logs/bwa_mem/{id}.log"
    conda:
        "../envs/bwa.yaml"
    threads:
        4
    shell:
        "bwa mem -t {threads} " + reference +
        " {input.r1} {input.r2}"
        " | samtools sort -@{threads} -o {output} -"

rule index_bam:
    input:
        "{id}.bam"
    output:
        "{id}.bam.bai"
    log:
        "logs/index_bam/{id}.log"
    conda:
        "../envs/bwa.yaml"
    shell:
        # need to use -a bwtsw for the human genome
        "samtools index {input}"

rule fastp:
    input:
        r1 = S3.remote(fastq_dir + "/{id}_R1_001.fastq.gz"),
        r2 = S3.remote(fastq_dir + "/{id}_R2_001.fastq.gz")
    output:
        r1 = "data/trimmed/{id}_R1_001.fastq.gz",
        r2 = "data/trimmed/{id}_R2_001.fastq.gz",
        html = "results/fastp/{id}_fastp.html",
        json = "results/fastp/{id}_fastp.json"
    log:
        "logs/bwa_mem/{id}.log"
    conda:
        "../envs/bwa.yaml"
    shell:
        "fastp --in1 {input.r1} --in2 {input.r2}"
        " --out1 {output.r1} --out2 {output.r2}"
        " --html {output.html}"
        " --json {output.json}"
        " --report_title '{wildcards.id} report'"