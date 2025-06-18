#! /bin/bash

# === Usage ===
# ./fix_classifier_model.sh [ROOT_DIR] [PARTICIPANT_FILE] [MODEL_OUTPUT_DIR] [QX_CONTAINER]

ROOT_DIR=${1:-}
PARTICIPANT_FILE=${2:-}
MODEL_OUTPUT_DIR=${3:-}
STUDIES_ID=${4:-}
QX_CONTAINER=${5:-/scratch/smansour/qunex/1.0.4/qunex_suite_1.0.4.sif}

RED='\033[0;31m'
NC='\033[0m'

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: $0 [ROOT_DIR] [PARTICIPANT_FILE] [MODEL_OUTPUT_DIR] [STUDIES_CSV] [QX_CONTAINER]"
  echo ""
  echo "Arguments:"
  echo "  ROOT_DIR           Path to project root where studies are (required) (i.e /projects/ttan/BEEST_hcp)"
  echo "  PARTICIPANT_FILE   Path to participant .txt file (required) (i.e \$ROOT_DIR/selected_participants.txt)"
  echo "  MODEL_OUTPUT_DIR   Path to output model directory (required) (i.e \$ROOT_DIR/STUDY_model)"
  echo "  STUDIES_ID         Comma-separated list of studies (required) (i.e 'SPN20,SPN40')"
  echo "  QX_CONTAINER       Path to qunex Singularity container (optional, default: /scratch/smansour/qunex/1.0.4/qunex_suite_1.0.4.sif)"
  exit 0
fi

if [[ -z "$ROOT_DIR" || -z "$PARTICIPANT_FILE" || -z "$MODEL_OUTPUT_DIR" || -z "$STUDIES_ID" ]]; then
  echo -e "${RED}ERROR:${NC} Missing required arguments. Use --help for detail"
  echo "Usage: $0 [ROOT_DIR] [PARTICIPANT_FILE] [MODEL_OUTPUT_DIR] [STUDIES_CSV] [QX_CONTAINER]"
  exit 1
fi

# Convert to array by splitting on comma
IFS=',' read -r -a STUDIES <<< "$STUDIES_ID"

# === Logging Setup ===
timestamp=$(date +"%Y%m%d_%H%M%S")
logfile="BEEST_model_training_${timestamp}.log"
exec > >(tee -a "$logfile") 2>&1

echo "🔧 Starting script at $(date)"
echo "🔧 ROOT_DIR          : $ROOT_DIR"
echo "🔧 PARTICIPANT_FILE  : $PARTICIPANT_FILE"
echo "🔧 MODEL_OUTPUT_DIR  : $MODEL_OUTPUT_DIR"
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
# === Step 1: Copy hand-label files to ICA directories ===
copyfiles() {
  local STUDY=$1
  local STUDYFOLDER="${ROOT_DIR}/${STUDY}"
  local ica_correct="${STUDYFOLDER}/ica_correct/outputs_label"

  while read -r file; do
    mni_folder=$(basename "$file" | cut -d '.' -f1)
    subid=$(echo "${mni_folder}" | cut -d '_' -f1)
    if ! is_participant_selected "$subid"; then
      echo "⏭️  Skipping participant: ${subid} (not in selected list)"
      continue
    fi
    target_dir="${STUDYFOLDER}/sessions/${subid}/hcp/${subid}/MNINonLinear/Results/${mni_folder}/${mni_folder}_hp2000.ica"

    echo "📁 Copying hand-label file for subject: ${subid} (Study: ${STUDY})"
    echo "    Source: ${file}"
    echo "    Target: ${target_dir}/hand_labels_noise.txt"

    if [[ -d "$target_dir" ]]; then
      rsync -av "${file}" "${target_dir}/hand_labels_noise.txt"
    else
      echo "⚠️  Target directory not found: ${target_dir}"
    fi
  done < <(find "${ica_correct}" -type f -name "*BOLD*.txt")
}

# === Step 2: Collect ICA dirs with labels ===
mergefiles() {
  local STUDY=$1
  local STUDYFOLDER="${ROOT_DIR}/${STUDY}"

  echo "🔍 Collecting ICA directories for study: ${STUDY}"
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
  done < <(find "${STUDYFOLDER}/sessions" -type d -name "*_BOLD_*_PA_hp2000.ica")
}

# === Step 3: Train FIX model ===
trainmodel() {
  if [[ -z "$subs_ica_dir" ]]; then
    echo "❌ No ICA directories found with labels."
    return 1
  fi

  mkdir -p "${MODEL_OUTPUT_DIR}"
  model_name=$(basename $MODEL_OUTPUT_DIR)
  echo "🧠 Training FIX model with ICA dirs:"
  echo "$subs_ica_dir" | tr ' ' '\n' | sort
  echo "Launching Qunex Singularity Container..."
  echo singularity exec -B "$ROOT_DIR" -B "$MODEL_OUTPUT_DIR" --env MODEL_NAME="$model_name" "$QX_CONTAINER" \
  bash -c '
    source /opt/qunex/env/qunex_environment.sh
    export FSL_FIX_MATLAB_MODE=2
    /opt/fsl/fix/fix -t "$0"/ -l "$@"
  ' "$MODEL_OUTPUT_DIR" ${subs_ica_dir}

  singularity exec -B "$ROOT_DIR" -B "$MODEL_OUTPUT_DIR" --env MODEL_NAME="$model_name" "$QX_CONTAINER" \
  bash -c '
    source /opt/qunex/env/qunex_environment.sh
    export FSL_FIX_MATLAB_MODE=2
    /opt/fsl/fix/fix -t "$0/${MODEL_NAME}" -l "$@" &&
    /opt/fsl/fix/fix -C /opt/fsl/fix/training_files/HCP_hp2000.RData "$0/HCP_hp2000_accuracy" "$@"

  ' "$MODEL_OUTPUT_DIR" ${subs_ica_dir}
}

# === Step 4: Compute
# === Main Workflow ===
for study in "${STUDIES[@]}"; do
  echo "🔄 Processing study: $study"
  copyfiles "$study"
  mergefiles "$study"
done

# Train final model
trainmodel
