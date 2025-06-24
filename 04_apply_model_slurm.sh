#!/bin/bash -l
#SBATCH --partition=high-moby
#SBATCH --array=1
#SBATCH --job-name=qunex_HCP_pyfix
#SBATCH --output=%x_%j_%a.out
#SBATCH --cpus-per-task=4
#SBATCH --time=24:00:00
#SBATCH --mem-per-cpu=8000

#But make sure to set these variables each time

qx_container=/scratch/smansour/qunex/1.0.4/qunex_suite_1.0.4.sif
STUDYFOLDER=/projects/ttan/BEEST_hcp/SPN40
sublist=/projects/ttan/BEEST_hcp/SPN40/code/test_sublist.txt
MODEL=/projects/ttan/BEEST_hcp/MODSOCCS_model/MODSOCCS_model.pyfix_model

# Function for looping through subjects in sublist
index() {
   head -n $SLURM_ARRAY_TASK_ID $sublist \
   | tail -n 1
}

PARTICIPANT_LABEL=`index`

# Running HCP pipelines with new model

for dir in ${STUDYFOLDER}/sessions/${PARTICIPANT_LABEL}/hcp/${PARTICIPANT_LABEL}/unprocessed/BOLD_*PA; do
    name=$(basename "$dir")
    id=$(echo "$name" | sed -E 's/BOLD_([0-9]+)_PA.*/\1/')
    rand=$(shuf -i 1000-9999 -n 1)  
    echo singularity exec -B ${STUDYFOLDER} \
      -B /projects/ttan/BEEST_hcp/fix_classifier/04_apply_model.sh \
      $qx_container bash \
      /projects/ttan/BEEST_hcp/fix_classifier/04_apply_model.sh ${STUDYFOLDER} ${MODEL} ${PARTICIPANT_LABEL} ${id}
      
    singularity exec -B ${STUDYFOLDER} -B ${MODEL} \
      -B /projects/ttan/BEEST_hcp/fix_classifier/04_apply_model.sh \
      $qx_container bash \
      /projects/ttan/BEEST_hcp/fix_classifier/04_apply_model.sh ${STUDYFOLDER} ${MODEL} ${PARTICIPANT_LABEL} ${id}
done
