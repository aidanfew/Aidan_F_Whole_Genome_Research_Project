nextflow.enable.dsl=2

// ---------------------------------------------------------------------------
// PARAMETERS
// ---------------------------------------------------------------------------
params.vcf    = '/home/aidanfew/groups/grp_ADVariance/nobackup/autodelete/36361_cohort/nextflow_test_file/test_subset.vcf.bgz'
params.outdir = '/home/aidanfew/groups/grp_ADVariance/nobackup/autodelete/pipeline_results'
params.chroms = ['chr16']

// ---------------------------------------------------------------------------
// PROCESS 0: Split VCF by chromosome
// ---------------------------------------------------------------------------
process SPLIT_VCF {
    tag "split_${chr}"
    publishDir "${params.outdir}/vcf_per_chrom", mode: 'copy'

    input:
    tuple val(chr), path(vcf)

    output:
    tuple val(chr), path("${chr}.recode.vcf")

    script:
    """
    vcftools \\
        --gzvcf ${vcf} \\
        --chr ${chr} \\
        --recode \\
        --recode-INFO-all \\
        --out ${chr}
    """
}

// ---------------------------------------------------------------------------
// PROCESS 1: VCF → PLINK BED/BIM/FAM
// --max-alleles 2 filters out multiallelic variants which .bed cannot store
// ---------------------------------------------------------------------------
process MAKE_BIM_BED_FAM {
    tag "plink_${chr}"
    publishDir "${params.outdir}/bim_bed_fam", mode: 'copy'

    input:
    tuple val(chr), path(vcf_chr)

    output:
    tuple val(chr), path("${chr}.bed"), path("${chr}.bim"), path("${chr}.fam")

    script:
    """
    plink2 \\
        --vcf ${vcf_chr} \\
        --max-alleles 2 \\
        --make-bed \\
        --out ${chr}
    """
}

// ---------------------------------------------------------------------------
// PROCESS 2: BIM/BED/FAM → phenotype file (.phen)
// Phenotype is identical across chromosomes — generated once from first chrom
// ---------------------------------------------------------------------------
process MAKE_PHENO {
    publishDir "${params.outdir}/phen_files", mode: 'copy'

    input:
    path fam

    output:
    path "cohort.phen"

    script:
    """
    awk '{print \$1, \$2, \$6}' ${fam} > cohort.phen
    """
}

// ---------------------------------------------------------------------------
// PROCESS 3: BIM/BED/FAM → GRM per chromosome
// ---------------------------------------------------------------------------
process MAKE_GRM {
    tag "grm_${chr}"
    publishDir "${params.outdir}/grm_files", mode: 'copy'

    input:
    tuple val(chr), path(bed), path(bim), path(fam)

    output:
    tuple val(chr), path("${chr}.grm.bin"), path("${chr}.grm.N.bin"), path("${chr}.grm.id")

    script:
    """
    gcta64 \\
        --bfile ${chr} \\
        --make-grm \\
        --out ${chr}
    """
}

// ---------------------------------------------------------------------------
// PROCESS 4: Write mgrm list using absolute paths so GCTA can find GRM files
// ---------------------------------------------------------------------------
process MAKE_MGRM_LIST {
    publishDir "${params.outdir}/greml_results", mode: 'copy'

    input:
    path grm_ids

    output:
    path "mgrm_list.txt"

    script:
    """
    for f in ${grm_ids}; do
        echo \${PWD}/\${f%.grm.id}
    done > mgrm_list.txt
    """
}

// ---------------------------------------------------------------------------
// PROCESS 5: GREML variance analysis
// All GRM files are staged into the work directory so GCTA can access them
// ---------------------------------------------------------------------------
process RUN_GREML {
    publishDir "${params.outdir}/greml_results", mode: 'copy'

    input:
    path mgrm_list
    path phen_file
    path grm_files   // stages all .grm.bin/.grm.N.bin/.grm.id into work dir

    output:
    path "AD_variance.hsq"
    path "AD_variance.log"

    script:
    """
    gcta64 \\
        --mgrm ${mgrm_list} \\
        --pheno ${phen_file} \\
        --reml \\
        --out AD_variance
    """
}

// ---------------------------------------------------------------------------
// WORKFLOW
// ---------------------------------------------------------------------------
workflow {

    // Pair each chromosome with the same input VCF
    chrom_ch = Channel.from(params.chroms)
        .map { chr -> tuple(chr, file(params.vcf)) }

    // Split VCF into one file per chromosome
    split_ch = SPLIT_VCF(chrom_ch)

    // Convert each per-chromosome VCF to PLINK binary format
    plink_ch = MAKE_BIM_BED_FAM(split_ch)

    // Generate phenotype file once from the first chromosome's .fam
    fam_ch1 = plink_ch
        .first()
        .map { chr, bed, bim, fam -> fam }
    phen_ch = MAKE_PHENO(fam_ch1)

    // Build GRM for each chromosome in parallel
    grm_ch = MAKE_GRM(plink_ch)

    // Collect all .grm.id files and write mgrm list with absolute paths
    grm_id_ch = grm_ch.map { chr, bin, nbin, id -> id }.collect()
    mgrm_ch   = MAKE_MGRM_LIST(grm_id_ch)

    // Collect all GRM files so Nextflow stages them into RUN_GREML work dir
    grm_files_ch = grm_ch
        .map { chr, bin, nbin, id -> [bin, nbin, id] }
        .flatten()
        .collect()

    // Run GREML with all chromosome GRMs + phenotype
    RUN_GREML(mgrm_ch, phen_ch, grm_files_ch)
}
