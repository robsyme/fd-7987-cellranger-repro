// Prepare inputs for reproducing Cell Ranger multi cache thrash under Fusion.
// Extracts the 10x Chromium X full-chip 3' HT FASTQ tars and the GRCh38
// reference straight into S3 through the Fusion mount, so nothing is
// written twice.

params.source  = 's3://scidev-playground-us-west-2/fd-7987/source/H1975_A549_DrugScreen_3p_HT_nextgem/*_fastqs.tar'
params.dest    = 's3://scidev-playground-us-west-2/fd-7987'
params.ref_url = 'https://cf.10xgenomics.com/supp/cell-exp/refdata-gex-GRCh38-2024-A.tar.gz'

process UNTAR_FASTQS {
    tag "${tar.baseName}"
    cpus 8
    memory '16 GB'
    container 'ubuntu:24.04'

    input:
    path tar
    val dest

    output:
    path "${tar.baseName}.files.txt"

    script:
    """
    out=/fusion/s3/${dest - 's3://'}/fastq
    mkdir -p \$out
    tar -xvf ${tar} -C \$out > ${tar.baseName}.files.txt
    """
}

process UNTAR_REFERENCE {
    tag "${ref.name}"
    cpus 4
    memory '8 GB'
    container 'ubuntu:24.04'

    input:
    path ref
    val dest

    output:
    path "reference.files.txt"

    script:
    """
    out=/fusion/s3/${dest - 's3://'}/ref
    mkdir -p \$out
    tar -xzvf ${ref} -C \$out > reference.files.txt
    """
}

workflow {
    UNTAR_FASTQS(channel.fromPath(params.source, checkIfExists: true), params.dest)
    UNTAR_REFERENCE(file(params.ref_url), params.dest)
}
