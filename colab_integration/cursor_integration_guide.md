# Cursor IDE + Google Colab Integration Guide

This guide explains how to integrate your EVP-KLEE project with Google Colab and Cursor IDE for cloud-based development.

## Overview

The integration provides:
- **Cloud execution**: Run EVP-KLEE in Google Colab's powerful environment
- **Local editing**: Use Cursor IDE's AI assistance for development
- **Automatic sync**: Results automatically saved to Google Drive
- **No disk space issues**: Bypass local VM storage limitations

## Setup Methods

### Method 1: Direct Colab Execution (Recommended)

1. **Upload your project to Google Drive**:
   ```bash
   cd /home/roxana/VASE-klee/EVP-KLEE/colab_integration
   python3 upload_to_drive.py
   ```

2. **Open in Google Colab**:
   - Go to https://colab.research.google.com
   - Upload `evp_colab_demo.ipynb`
   - Run all cells to execute the EVP-KLEE demo

3. **Download results**:
   - Results are automatically saved to Google Drive
   - Download any specific files you need locally

### Method 2: Cursor IDE + Colab Runtime

1. **Install Jupyter extension in Cursor**:
   - Open Extensions (Ctrl+Shift+X)
   - Search for "Jupyter" and install it

2. **Set up local Jupyter**:
   ```bash
   pip install jupyter notebook
   jupyter notebook --allow-root
   ```

3. **Connect Colab to local runtime**:
   - In Colab: Runtime → Change runtime type
   - Select "Connect to local runtime"
   - Enter the Jupyter URL (usually `http://localhost:8888`)

4. **Open notebook in Cursor**:
   - Open `evp_colab_demo.ipynb` in Cursor
   - Use Cursor's AI features while running in Colab

### Method 3: Hybrid Development

1. **Develop in Cursor**:
   - Edit Python files locally in Cursor
   - Use AI assistance for code development

2. **Test in Colab**:
   - Upload modified files to Google Drive
   - Run tests in Colab environment

3. **Iterate**:
   - Download results from Colab
   - Continue development in Cursor

## Project Structure for Colab

```
EVP-KLEE/
├── colab_integration/
│   ├── evp_colab_demo.ipynb      # Main Colab notebook
│   ├── upload_to_drive.py        # Upload helper script
│   ├── cursor_integration_guide.md
│   └── UPLOAD_INSTRUCTIONS.md
├── automated_demo/
│   ├── evp_pipeline.py           # Main pipeline
│   ├── klee_runner.py            # KLEE execution
│   └── config/
│       └── programs.json         # Program configurations
├── benchmarks/                   # Test programs
├── scripts/                      # Build and setup scripts
└── docs/                        # Documentation
```

## Key Features

### 1. Automated Environment Setup
- Installs all required dependencies (LLVM, STP, Z3, etc.)
- Builds KLEE from source
- Sets up Python environment

### 2. Interactive Results Visualization
- Performance comparison charts
- Success rate analysis
- Detailed metrics display

### 3. Google Drive Integration
- Automatic project upload
- Results backup to Drive
- Easy sharing and collaboration

### 4. Cursor IDE Benefits
- AI-powered code assistance
- Intelligent autocomplete
- Code refactoring suggestions
- Integrated debugging

## Usage Workflow

1. **Initial Setup**:
   ```bash
   # Create project archive
   python3 upload_to_drive.py
   
   # Upload to Google Drive (manual step)
   # Open in Colab and run
   ```

2. **Development Cycle**:
   - Edit code in Cursor IDE
   - Upload changes to Google Drive
   - Run tests in Colab
   - Download results
   - Iterate

3. **Results Analysis**:
   - View interactive charts in Colab
   - Download detailed JSON results
   - Share results via Google Drive

## Troubleshooting

### Common Issues

1. **Upload fails**:
   - Check Google Drive storage space
   - Try uploading individual directories
   - Use the upload helper script

2. **Colab runtime disconnects**:
   - Save work frequently
   - Use Google Drive for persistence
   - Consider Colab Pro for longer sessions

3. **Build failures**:
   - Check dependency installation
   - Verify LLVM version compatibility
   - Review error logs in Colab

4. **Cursor integration issues**:
   - Ensure Jupyter extension is installed
   - Check local Jupyter installation
   - Verify network connectivity

### Performance Tips

1. **Optimize for Colab**:
   - Use smaller test datasets initially
   - Enable GPU runtime for heavy computations
   - Save intermediate results

2. **Efficient development**:
   - Use Cursor for code editing
   - Use Colab for execution and testing
   - Sync frequently via Google Drive

## Advanced Features

### Custom Configurations
- Modify `programs.json` for different test suites
- Adjust KLEE parameters in the notebook
- Add custom visualization code

### Collaboration
- Share notebooks via Google Drive
- Use Colab's commenting features
- Export results for team review

### Integration with Other Tools
- Connect to GitHub for version control
- Use Colab's TensorBoard integration
- Export to various formats (PDF, HTML, etc.)

## Next Steps

1. **Run the upload script** to prepare your project
2. **Upload to Google Drive** following the instructions
3. **Open the notebook in Colab** and run the demo
4. **Download the notebook** and open in Cursor IDE
5. **Start developing** with the hybrid approach

This setup gives you the best of both worlds: Cursor's powerful AI assistance for development and Colab's cloud resources for execution, all while bypassing your local disk space limitations.
