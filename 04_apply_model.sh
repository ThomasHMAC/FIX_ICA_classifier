#! /bin/bash

# === Usage ===
# apply_fix_classifier.sh [STUDY_DIR] [MODEL] [PARTICIPANT_LABEL]

STUDY_DIR=${1:-}
MODEL=${2:-}
PARTICIPANT_LABEL=${3:-}
REST_NUM=${4:-}

RED='\033[0;31m'
NC='\033[0m'

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: $0 [STUDY_DIR] [MODEL] [PARTICIPANT_LABEL] [QX_CONTAINER]"
  echo ""
  echo "Arguments:"
  echo "  STUDY_DIR          Path to where studies are (required) (i.e /projects/ttan/BEEST_hcp/SPN40)"
  echo "  MODEL              Path to model (required)"
  echo "  PARTICIPANT_LABEL  Participant identifier (required)"
  echo "  REST_NUM           Number of resting-state run"
  exit 0
fi

if [[ -z "$STUDY_DIR" || -z "$MODEL" || -z "$PARTICIPANT_LABEL" || -z "$REST_NUM" ]]; then
  echo -e "${RED}ERROR:${NC} Missing required arguments. Use --help for detail"
  echo "Usage: $0 [STUDY_DIR] [MODEL] [PARTICIPANT_LABEL] [REST_NUM]"
  exit 1
fi

sessions_folder=${STUDY_DIR}/sessions 
hcp_dir=${sessions_folder}/${PARTICIPANT_LABEL}/hcp

fmriname=${PARTICIPANT_LABEL}_BOLD_${REST_NUM}_PA

mni_results=${hcp_dir}/${PARTICIPANT_LABEL}/MNINonLinear/Results/${fmriname}/${fmriname}

# === HCP pipelines ===
source /opt/qunex/env/qunex_environment.sh
export FSL_FIX_MATLAB_MODE=2

# === Logging Parameters ===
echo "🔧 Starting script at $(date)"
echo "🔧 STUDY_DIR          : $STUDY_DIR"
echo "🔧 SESSIONS           : $sessions_folder"
echo "🔧 PARTICIPANT_LABEL  : $PARTICIPANT_LABEL"
echo "🔧 REST_NUM           : $fmriname"
echo "🔧 MODEL              : $MODEL"
echo "============================================="

# hcp_fix <4D_FMRI_data> <highpass> <do_motion_regression> [<TrainingFile>] [<FixThreshold>] [<DeleteIntermediates>
/opt/HCP/HCPpipelines/ICAFIX/hcp_fix \
 ${mni_results} \
 2000 \
 "TRUE" \
 ${MODEL} \
 10 \
 "FALSE"

/opt/HCP/HCPpipelines/ICAFIX/PostFix.sh \
--study-folder=${hcp_dir} \
--subject=${PARTICIPANT_LABEL} \
--fmri-name=${fmriname} \
--high-pass="2000" \
--template-scene-dual-screen="/opt/HCP/HCPpipelines/ICAFIX/PostFixScenes/ICA_Classification_DualScreenTemplate.scene" \
--template-scene-single-screen="/opt/HCP/HCPpipelines/ICAFIX/PostFixScenes/ICA_Classification_SingleScreenTemplate.scene" \
--reuse-high-pass="YES" \
--matlab-run-mode="2"