nextflow.enable.dsl=2

// --- parameters ---
params.vcf = '/home/aidanfew/groups/grp_ADVariance/nobackup/autodelete/file_10254-42298062.vcf.bgz'
params.pheno = '/home/aidanfew/groups/grp_ADVariance/nobackup/autodelete/your_alzheimers_traits.phen'
params.outdir = '/home/aidanfew/groups/grp_ADVariance/nobackup/autodelete/pipeline_results'

// --- SLURM defaults for all jobs ---
process {
    executor = 'slurm'
    cpus = 8            
    memory = '64 GB'     // 64 GB TOTAL memory for the job
    time = '12h'
    clusterOptions = '--mail-user=aidanfew@byu.edu --mail-type=FAIL' 
}

// --- pipeline Steps ---
process MAKE_BIM_BED_FAM {
    publishDir "${params.outdir}/bim_bed_fam_files", mode: 'copy'

    input:
    path vcf

    output:
    tuple path("plink_data.bed"), path("plink_data.bim"), path("plink_data.fam")

    script:
    """
    plink2 --vcf ${vcf} \\
           --make-bed \\
           --out plink_data \\
           --threads ${task.cpus} \\
           --memory 60000 
    """
}

process MAKE_GRM {
    publishDir "${params.outdir}/grm_files", mode: 'copy'

    input:
    tuple path(bed), path(bim), path(fam)

    output:
    tuple path("grm_data.grm.bin"), path("grm_data.grm.N.bin"), path("grm_data.grm.id")

    script:
    """
    PREFIX=\$(basename ${bed} .bed)
    
    gcta64 --bfile \$PREFIX \\
           --make-grm \\
           --out grm_data \\
           --thread-num ${task.cpus}
    """
}

process RUN_GREML {
    publishDir "${params.outdir}/greml_results", mode: 'copy'

    input:
    tuple path(grm_bin), path(grm_N), path(grm_id)
    path pheno

    output:
    path "greml_variance.hsq"
    path "greml_variance.log"

    script:
    """
    PREFIX=\$(basename ${grm_bin} .grm.bin)
    
    gcta64 --grm \$PREFIX \\
           --pheno ${pheno} \\
           --reml \\
           --out greml_variance \\
           --thread-num ${task.cpus}
    """
}

workflow {
    vcf_ch = Channel.fromPath(params.vcf, checkIfExists: true)
    pheno_ch = Channel.fromPath(params.pheno, checkIfExists: true)

    plink_ch = MAKE_BIM_BED_FAM(vcf_ch)
    grm_ch = MAKE_GRM(plink_ch)
    RUN_GREML(grm_ch, pheno_ch)
}
