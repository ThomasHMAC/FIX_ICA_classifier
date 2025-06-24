# FIX Classifier Training and Visualization Module

This module trains a classifier for Independent Component Analysis (ICA) component classification using FSL's FIX tool. It includes utilities to train new FIX models on HCP-style datasets and visualize model performance.

---

## 🚀 Quick Start

### Software Dependencies
- **[FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIX)** with FIX tool

### Python Dependencies
- **Python 3.x** with the following packages:
  - `matplotlib`
  - `pandas` 
  - `numpy`

### Required Directory Structure

Your study directory should follow this structure:

```
/projects/ttan/BEEST_hcp/SPN20/
├── ica_correct/
│   └── outputs_label/
│       ├── CMH0001_BOLD_1_PA.txt    # Hand-labeled ICA components
│       ├── CMH0014_BOLD_2_PA.txt    # Hand-labeled ICA components
│       └── ...                      # Additional hand-labeled files
├── ica_dir/
└── sessions/
```

### 🏷️ Creating Hand-Labeled ICA Components

Before training your classifier, you need hand-labeled ICA component files. These can be created using **our interactive ICA labeling app** [available here](https://github.com/slimnsour/ica-ranker).

The app allows you to:
- Visually inspect ICA components
- Mark components classified as **noise**
- Export properly formatted label files

---

## 📖 Step-by-Step Usage

### Step 1: Train Your Classifier

Train a new FIX classifier using your hand-labeled data:

```bash
bash 01_train_model.sh [ROOT_DIR] [PARTICIPANT_FILE] [MODEL_TYPE] [MODEL_OUTPUT_DIR] [STUDIES_ID] [QX_CONTAINER]
```

Use `01_train_model.sh --help` for detailed parameter information.

#### Example:
```bash
bash 01_train_model.sh \
    /projects/ttan/BEEST_hcp \
    /projects/ttan/BEEST_hcp/selected_participants.txt \
    'pyfix_model' \
    /projects/ttan/BEEST_hcp/MODSOCCS_MODEL \
    'SPN20,SPN40'
```

#### Parameters:
| Parameter | Description |
|-----------|-------------|
| `ROOT_DIR` | Root directory containing your HCP-style study |
| `PARTICIPANT_FILE` | Text file listing participants for training (one per line) |
| `MODEL_TYPE` | Model format: `pyfix_model` or `RData` |
| `MODEL_OUTPUT_DIR` | Directory where the trained model will be saved |
| `STUDIES_ID` | Comma-separated list of study IDs (e.g., 'SPN20,SPN40') |
| `QX_CONTAINER` | Container specification for the execution environment |

---

### Step 2: Evaluate Model Performance

Test your trained model on a separate dataset to assess its accuracy:

```bash
bash 02_evaluate_model.sh [STUDY_DIR] [MODEL] [PARTICIPANT_FILE] [QX_CONTAINER]
```

#### Example:
```bash
bash 02_evaluate_model.sh \
    /projects/ttan/BEEST_hcp/SPN40 \
    /projects/ttan/BEEST_hcp/MODSOCCS_model/MODSOCCS_model.pyfix_model \
    /projects/ttan/BEEST_hcp/SPN20/test_sublist.txt
```

#### Parameters:
| Parameter | Description |
|-----------|-------------|
| `STUDY_DIR` | Path to your HCP-style study directory for testing |
| `MODEL` | Path to your trained model file |
| `PARTICIPANT_FILE` | Text file listing participants for testing (one per line) |
| `QX_CONTAINER` | Container specification for the execution environment |

> **💡 Note:** Performance results are saved in **[STUDY_DIR]/fix_model_metrics**. File naming depends on model type:
> - `pyfix_model`: Files include a "pyfix_model" suffix
> - `RData`: Files include an "RData_results" suffix

---

### Step 3: Visualize Model Performance

Generate performance plots using the results from Step 2. The visualization script reads the accuracy metrics file created during model evaluation:

```bash
python 03_visualize_metrics.py /PATH/TO/RESULTS_FILE --save /PATH/TO/OUTPUT --title "Model Performance"
```

**Finding your results file:** After Step 2, look in `[STUDY_DIR]/fix_model_metrics/` for a file with pattern:
- `*_accuracy_*_pyfix_model` (for pyfix_model type)
- `*_accuracy_*_RData_results` (for RData type)

#### Example:
```bash
# Using results from Step 2 evaluation
python 03_visualize_metrics.py \
    /projects/ttan/BEEST_hcp/SPN40/fix_model_metrics/MODSOCCS_model_accuracy_20250624_172033_pyfix_model \
    --save /projects/ttan/BEEST_hcp/MODSOCCS_performance.png \
    --title "MODSOCCS Model Performance"
```

#### Parameters:
| Parameter | Description |
|-----------|-------------|
| `metrics_path` | Full path to the accuracy results file |
| `--save` | Output path for the visualization plot |
| `--title` | Title for the performance plot |

---

### Step 4: Apply Model to New Data

Once you have a trained and validated model, you can apply it to classify ICA components in new datasets:

```bash
sbatch 04_apply_model_slurm.sh
```

**Before running, edit the script variables:**
```bash
# Required variables to set in 04_apply_model_slurm.sh
qx_container=/path/to/your/qunex_container.sif
STUDYFOLDER=/path/to/your/study/directory
sublist=/path/to/your/participant/list.txt
MODEL=/path/to/your/trained/model.pyfix_model
```

#### Parameters:
| Variable | Description |
|----------|-------------|
| `qx_container` | Path to your QuNex Singularity container |
| `STUDYFOLDER` | Main study directory containing your data |
| `sublist` | Text file listing participants to process (one per line) |
| `MODEL` | Path to your trained model file (from Step 1) |

> **💡 Note:** This step processes BOLD data for each participant and applies your trained FIX classifier to automatically identify and classify ICA components as signal or noise.

```

---

## 📊 Output Files

After completing all steps, you'll have:

**From Training (Step 1):**
- ✅ **Trained FIX classifier model** (`.RData` or `pyfix_model` format)
- 📋 **Training logs and configuration files**

**From Evaluation (Step 2):**
- 📈 **Performance metrics file** with accuracy statistics
- 📊 **Detailed classification results** (TPR, TNR, specificity, sensitivity)

**From Visualization (Step 3):**
- 📊 **Performance plots** showing model accuracy metrics