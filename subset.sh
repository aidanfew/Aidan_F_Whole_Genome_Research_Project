#!/bin/bash

#SBATCH --time=00:10:00              
#SBATCH --ntasks=1                   
#SBATCH --nodes=1                    
#SBATCH --mem-per-cpu=4096M          
#SBATCH -J "subset_vcf"              
#SBATCH --mail-user=aidanfew@byu.edu 
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --output=subset_vcf_%j.out   

# Clean the environment and load htslib so bgzip works
module purge
module load htslib/1.9

# Decompress, grab 10,000 lines, recompress to the new folder
gzip -dc /nobackup/private/bioinfstg3/2018/ADSP/r5_adsp_vcfs_tbis/gcad.qc.r5.wgs.58506.GLnexus.2025.07.31.genotypes.chr16:80300753-85319549.ALL.vcf.bgz | head -n 10000 | bgzip > /home/aidanfew/groups/grp_ADVariance/nobackup/autodelete/36361_cohort/nextflow_test_file/test_subset.vcf.bgz
