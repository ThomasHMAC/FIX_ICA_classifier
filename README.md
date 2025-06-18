# FIX Classifier Training and Visualization Module

This module is designed to train a classifier for Independent Component Analysis (ICA) component classification using FSL's FIX tool. It includes utilities to train new FIX models on HCP-style datasets and visualize model performance.

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

### 🏷️ Hand-Labeled ICA Components

Hand-labeled ICA component files can be created using **our interactive ICA labeling app** [available here](https://github.com/slimnsour/ica-ranker).

The app allows you to:
- Visually inspect ICA components
- Mark components classified as **noise**
- Export properly formatted label files

---

## 📖 Usage

### Step 1: Train Classifier

```bash
bash fix_classifier_model.sh [ROOT_DIR] [PARTICIPANT_FILE] [MODEL_OUTPUT_DIR] [STUDIES_ID] [QX_CONTAINER]
```

Use `fix_classifier_model.sh --help` for more details.

#### Example:
```bash
bash fix_classifier_model.sh \
    /projects/ttan/BEEST_hcp \
    /projects/ttan/BEEST_hcp/selected_participants.txt \
    /projects/ttan/BEEST_hcp/CMH_model \
    'SPN20,SPN40'
```

#### Parameters:
| Parameter | Description |
|-----------|-------------|
| `ROOT_DIR` | Root directory containing your HCP-style study data |
| `PARTICIPANT_FILE` | Text file containing participants for training |
| `MODEL_OUTPUT_DIR` | Directory where the trained model will be saved |
| `STUDIES_ID` | Comma-separated list of studies or a single study |
| `QX_CONTAINER` | Container specification for the execution environment |

---

### Step 2: Visualize Model Performance

```bash
python model_visualization.py /PATH/TO/model_accuracy_results --save /PATH/TO/OUTPUT --title "Model Performance"
```

#### Example:
```bash
python model_visualization.py \
    /projects/ttan/BEEST_hcp/SPN20_model/SPN20_model_LOO_results \
    --save /projects/ttan/BEEST_hcp/fix_classifier/SPN20_model_accuracy.png \
    --title "SPN20 Model Performance"
```

> **💡 Note:** The `model_accuracy_results` file is automatically generated in your `MODEL_OUTPUT_DIR` after training completes.

---

## 📊 Output Files

The training process generates:
- ✅ **Trained FIX classifier model**
- 📈 **Performance metrics and accuracy results**
- 📋 **Training logs**
- 📊 **Visualization plots** (TPR, TNR, and combined metrics)