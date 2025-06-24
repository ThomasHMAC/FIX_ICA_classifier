#!/bin/bash

# ----------- Argument Parsing ------------
ROOT_DIR="${1:-}"
PARTICIPANT_FILE="${2:-}"
MODEL_TYPE="${3:-}"
MODEL_OUTPUT_DIR="${4:-}"
STUDIES_ID="${5:-}"
QX_CONTAINER="${6:-/scratch/smansour/qunex/1.0.4/qunex_suite_1.0.4.sif}"

# ----------- Color codes ------------
RED='\033[0;31m'
NC='\033[0m' # No Color

# ----------- Help Message ------------
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: $0 [ROOT_DIR] [PARTICIPANT_FILE] [MODEL_TYPE] [MODEL_OUTPUT_DIR] [STUDIES_ID] [QX_CONTAINER]"
  echo ""
  echo "Arguments:"
  echo "  ROOT_DIR           Path to project root where studies are (required)."
  echo "                     e.g., /projects/ttan/BEEST_hcp"
  echo "  PARTICIPANT_FILE   Path to participant .txt file used to train model (required)."
  echo "                     e.g., \$ROOT_DIR/selected_participants.txt"
  echo "  MODEL_TYPE         Type of the training model: 'pyfix_model' or 'RData' (required)"
  echo "  MODEL_OUTPUT_DIR   Path to output model directory (required)."
  echo "                     e.g., \$ROOT_DIR/STUDY_model"
  echo "  STUDIES_ID         Comma-separated list of studies (required)."
  echo "                     e.g., 'SPN20,SPN40' or 'SPN20'"
  echo "  QX_CONTAINER       Path to Qunex Singularity container (optional)."
  echo "                     Default: /scratch/smansour/qunex/1.0.4/qunex_suite_1.0.4.sif"
  exit 0
fi

# ----------- Validate Required Arguments ------------
if [[ -z "$ROOT_DIR" || -z "$PARTICIPANT_FILE" || -z "$MODEL_TYPE" || -z "$MODEL_OUTPUT_DIR" || -z "$STUDIES_ID" ]]; then
  echo -e "${RED}❌ ERROR:${NC} Missing required arguments. Use --help for details."
  echo "Usage: $0 [ROOT_DIR] [PARTICIPANT_FILE] [MODEL_TYPE] [MODEL_OUTPUT_DIR] [STUDIES_ID] [QX_CONTAINER]"
  exit 1
fi

# ----------- Validate MODEL_TYPE ------------
if [[ "$MODEL_TYPE" != "pyfix_model" && "$MODEL_TYPE" != "RData" ]]; then
  echo -e "${RED}❌ ERROR:${NC} MODEL_TYPE must be either 'pyfix_model' or 'RData'. Got: '$MODEL_TYPE'"
  exit 1
fi


# Convert to array by splitting on comma
IFS=',' read -r -a STUDIES <<< "$STUDIES_ID"

# === Logging Setup ===
timestamp=$(date +"%Y%m%d_%H%M%S")
logfile="01_train_model_${timestamp}.log"
exec > >(tee -a "$logfile") 2>&1

echo "🔧 Starting script at $(date)"
echo "🔧 ROOT_DIR          : $ROOT_DIR"
echo "🔧 PARTICIPANT_FILE  : $PARTICIPANT_FILE"
echo "🔧 MODEL_OUTPUT_DIR  : $MODEL_OUTPUT_DIR"
echo "🔧 QX_CONTAINER      : $QX_CONTAINER"
echo "🔧 Logging to        : $logfile"
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

  model_name=$(basename $MODEL_OUTPUT_DIR)
  echo "🧠 Training FIX model with ICA dirs:"
  subs_ica_dir=$(echo "$subs_ica_dir" | tr ' ' '\n' | sort)
  echo "Launching Qunex Singularity Container..."
  if [ $MODEL_TYPE = "pyfix_model" ]; then
    mkdir -p "${MODEL_OUTPUT_DIR}_${MODEL_TYPE}"
    echo singularity exec -B "$ROOT_DIR" -B "$MODEL_OUTPUT_DIR" --env MODEL_NAME="$model_name" "$QX_CONTAINER" \
    bash -c '
      source /opt/qunex/env/qunex_environment.sh
      export FSL_FIX_MATLAB_MODE=2
      /opt/fsl/fsl-6.0.7.14/bin/fix -t "$0/${MODEL_NAME}" -l "$@"
    ' "$MODEL_OUTPUT_DIR" ${subs_ica_dir}

    singularity exec -B "$ROOT_DIR" -B "$MODEL_OUTPUT_DIR" --env MODEL_NAME="$model_name" "$QX_CONTAINER" \
    bash -c '
      source /opt/qunex/env/qunex_environment.sh
      export FSL_FIX_MATLAB_MODE=2
      /opt/fsl/fsl-6.0.7.14/bin/fix -t "$0/${MODEL_NAME}" -l "$@"
    ' "$MODEL_OUTPUT_DIR" ${subs_ica_dir}

  elif [ $MODEL_TYPE = "RData" ]; then
    mkdir -p "${MODEL_OUTPUT_DIR}_${MODEL_TYPE}"
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
      /opt/fsl/fix/fix -t "$0/${MODEL_NAME}" -l "$@"
    ' "$MODEL_OUTPUT_DIR" ${subs_ica_dir}
  fi
}

# === Main Workflow ===
for study in "${STUDIES[@]}"; do
  echo "🔄 Processing study: $study"
  copyfiles "$study"
  mergefiles "$study"
done

# Train final model
trainmodel
