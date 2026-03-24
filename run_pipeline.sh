#!/bin/bash
# ===========================================================================
# run_pipeline.sh  —  SLURM master job for AD variance Nextflow pipeline
# Submit with: sbatch run_pipeline.sh
# ===========================================================================
#SBATCH --job-name=nf_AD_variance
#SBATCH --partition=m8
#SBATCH --time=48:00:00
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH --mem=8G
#SBATCH --mail-user=aidanfew@byu.edu
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --output=/home/aidanfew/groups/grp_ADVariance/nobackup/autodelete/36361_cohort/logs/nextflow_master_%j.out
#SBATCH --error=/home/aidanfew/groups/grp_ADVariance/nobackup/autodelete/36361_cohort/logs/nextflow_master_%j.err
 
# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
set -euo pipefail
 
module purge
module load nextflow
module load miniconda3/24.3.0-poykqmt
source activate advariance
 
# Prevent Nextflow from phoning home (important on compute nodes)
export NXF_OFFLINE=true
export NXF_UPDATE_CHECK=false
 
# Keep Nextflow's own Java heap small — it's just the orchestrator
export NXF_OPTS="-Xms512m -Xmx4g"
 
# ---------------------------------------------------------------------------
# Paths — all hardcoded to avoid SLURM working directory issues
# ---------------------------------------------------------------------------
PIPELINE_DIR="/home/aidanfew/groups/grp_ADVariance/nobackup/autodelete/36361_cohort"
LOG_DIR="/home/aidanfew/groups/grp_ADVariance/nobackup/autodelete/36361_cohort/logs"
 
# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
echo "Starting AD variance pipeline: $(date)"
echo "Pipeline dir: ${PIPELINE_DIR}"
 
nextflow run "${PIPELINE_DIR}/pipeline.nf" \
    -profile slurm \
    -resume \
    -with-report "${LOG_DIR}/report.html" \
    -with-timeline "${LOG_DIR}/timeline.html" \
    -with-dag "${LOG_DIR}/dag.html" \
    -with-trace "${LOG_DIR}/trace.txt"
 
echo "Pipeline complete: $(date)"
