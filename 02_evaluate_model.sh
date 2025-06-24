#! /bin/bash
# === Usage ===
# 02_evaluate_model.sh [STUDY_DIR] [MODEL] [PARTICIPANT_FILE]

STUDY_DIR=${1:-}
MODEL=${2:-}
PARTICIPANT_FILE=${3:-}
QX_CONTAINER=${4:-/scratch/smansour/qunex/1.0.4/qunex_suite_1.0.4.sif}

RED='\033[0;31m'
NC='\033[0m'

if [[ -z "$STUDY_DIR" || -z "$MODEL" || -z "$PARTICIPANT_FILE" ]]; then
  echo -e "${RED}ERROR:${NC} Missing required arguments. Use --help for detail"
  echo "Usage: $0 [STUDY_DIR] [MODEL] [PARTICIPANT_FILE] [QX_CONTAINER]"
  exit 1
fi

# === Logging Setup ===
OUTDIR=${STUDY_DIR}/fix_model_metrics
model_name=$(basename $MODEL)
extension="${model_name##*.}"
model_name="${model_name%.*}"
timestamp=$(date +"%Y%m%d_%H%M%S")
# logfile=${OUTDIR}/${model_name}_accuracy_${timestamp}_${extension}

# exec > >(tee -a "$logfile") 2>&1

echo "🔧 Starting script at $(date)"
echo "🔧 STUDY_DIR         : $STUDY_DIR"
echo "🔧 MODEL             : $MODEL"
echo "🔧 PARTICIPANT_FILE  : $PARTICIPANT_FILE"
echo "🔧 QX_CONTAINER      : $QX_CONTAINER"
echo "🔧 Logging to: $logfile"
echo "============================================="

# === Global Variables ===
subs_ica_dir=""  # global to accumulate ICA dirs

# Verify the participant file exists
if [[ ! -f "$PARTICIPANT_FILE" ]];then
  echo "❌ Error: Participant file not found: $PARTICIPANT_FILE"
  exit 1
fi

# === Function: Participant Selection ===
is_participant_selected() {
  local subid=$1
  grep -q "^${subid}$" "$PARTICIPANT_FILE"
}

# Collect ICA dirs with labels ===
mergefiles() {
  local STUDYFOLDER=$1
  local sessions_folder=${STUDY_DIR}/sessions
  echo "🔍 Collecting ICA directories"
  while read -r ica_dir; do
    subid=$(echo "$ica_dir" | grep -oP 'sessions/\K[^/]+' | head -1)

    if ! is_participant_selected "$subid"; then
      echo "⏭️  Skipping ICA dir for participant: ${subid}"
      continue
    fi

    label_f="${ica_dir}/hand_labels_noise.txt"
    if [[ -f "$label_f" ]]; then
      echo "✅ Found: $label_f"
      subs_ica_dir="${subs_ica_dir} ${ica_dir}"
    else
      echo "⚠️  Missing label in: $ica_dir"
    fi
  done < <(find "${sessions_folder}" -type d -name "*_BOLD_*_PA_hp2000.ica")
}

mergefiles ${STUDY_DIR}
mkdir -vp ${OUTDIR}
subs_ica_dir=$(echo "$subs_ica_dir" | tr ' ' '\n' | sort)

if [[ $extension == "pyfix_model" ]]; then
    logfile=${OUTDIR}/${model_name}_accuracy_${timestamp}_${extension}
    exec > >(tee -a "$logfile") 2>&1
    singularity exec -B ${STUDY_DIR} -B ${MODEL} --env MODEL_NAME=${model_name} ${QX_CONTAINER} \
      bash -c '
        source /opt/qunex/env/qunex_environment.sh
        export FSL_FIX_MATLAB_MODE=2

        echo "Input model: $0"
        echo "Input study dir: $1"
        echo "Model name: $MODEL_NAME"
        echo "ICA dirs: ${@:2}"
        echo /opt/fsl/fsl-6.0.7.14/bin/fix -C "$0" "$1/${MODEL_NAME}_accuracy" "${@:2}"
        # /opt/fsl/fsl-6.0.7.14/bin/fix -c "${@:2}" "$0" 10
        /opt/fsl/fsl-6.0.7.14/bin/fix -C -lf "$1"/pyfix_$(date +"%Y%m%d_%H%M%S").log "$0" "${@:2}"
      ' ${MODEL} ${OUTDIR} ${subs_ica_dir[@]}
elif [[ $extension == "RData" ]]; then
    singularity exec -B ${STUDY_DIR} -B ${MODEL} --env MODEL_NAME=${model_name} --env MODEL_EXT=${extension} ${QX_CONTAINER} \
      bash -c '
        source /opt/qunex/env/qunex_environment.sh
        export FSL_FIX_MATLAB_MODE=2

        echo "Input model: $0"
        echo "Input study dir: $1"
        echo "Model name: $MODEL_NAME"
        echo "ICA dirs: ${@:2}"
        echo /opt/fsl/fix/fix -C "$0" "$1/${MODEL_NAME}_accuracy_$(date +"%Y%m%d_%H%M%S")_${extension}" "${@:2}"
        /opt/fsl/fix/fix -C "$0" "$1/${MODEL_NAME}_accuracy_$(date +"%Y%m%d_%H%M%S")_${MODEL_EXT}" "${@:2}"
        # /opt/fsl/fix/fix -C /opt/fsl/fix/training_files/HCP_hp2000.RData "$1/HCP_hp2000_accuracy" "${@:2}"
      ' ${MODEL} ${OUTDIR} ${subs_ica_dir[@]}
else
    echo "Model extension is not recognized!!!"
fi
