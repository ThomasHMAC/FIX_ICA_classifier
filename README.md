# FIX Classifier Training and Visualization Module

This module is designed to train a classifier for Independent Component Analysis (ICA) component classification using FSL's FIX tool. It includes utilities to train new FIX models on HCP-style datasets and visualize model performance.

## Requirements

### Software Dependencies
- [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIX) with FIX tool

### Python Dependencies
- Python 3.x
- `matplotlib`
- `pandas`
- `numpy`

### Required Directory Layout

```
/projects/ttan/BEEST_hcp/SPN20/
├── ica_correct/
│   ├── outputs_label/
│   │   ├── CMH0001_BOLD_1_PA.txt
│   │   ├── CMH0014_BOLD_2_PA.txt
│   │   └── ...
├── ica_dir/
└── sessions/
```

### Hand-Labeled ICA Components

These hand-labeled ICA component files can be created using our interactive ICA labeling app, available [here](https://your-link-here.com). The app allows users to visually inspect ICA components and mark those classified as **noise**.

## Usage

### 1. Train the Classifier

To train a classifier using FIX and a labeled ICA dataset, run:

```bash
bash fix_classifier_model.sh [ROOT_DIR] [PARTICIPANT_FILE] [MODEL_OUTPUT_DIR] [QX_CONTAINER]
```

**Parameters:**
- `ROOT_DIR`: Root directory containing your HCP-style study data
- `PARTICIPANT_FILE`: Text file containing participant for training
- `MODEL_OUTPUT_DIR`: Directory where the trained model will be saved
- `QX_CONTAINER`: Container specification for the execution environment

Use ```fix_classifier_model.sh --help``` for more detail

### 2. Visualize Model Performance

After training, use the Python script to visualize model performance:

```bash
python model_visualization.py /path/to/model_accuracy_results --title "Model Performance"
```

**Note:** The `model_accuracy_results` file can be found in the `[MODEL_OUTPUT_DIR]` directory after training is complete.