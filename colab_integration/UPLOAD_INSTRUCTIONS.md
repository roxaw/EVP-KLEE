
# EVP-KLEE Google Drive Upload Instructions

## Step 1: Upload the Archive
1. Go to https://drive.google.com
2. Create a new folder called "EVP-KLEE"
3. Upload the generated `EVP-KLEE-{timestamp}.tar.gz` file to this folder
4. Extract the archive in Google Drive (right-click → Extract)

## Step 2: Verify Upload
Make sure the following structure exists in your Google Drive:
```
MyDrive/
└── EVP-KLEE/
    ├── automated_demo/
    ├── benchmarks/
    ├── scripts/
    ├── docs/
    ├── klee/
    ├── src/
    ├── include/
    ├── third_party/
    ├── CMakeLists.txt
    ├── Makefile
    ├── README.md
    └── requirements.txt
```

## Step 3: Open in Google Colab
1. Go to https://colab.research.google.com
2. Upload the `evp_colab_demo.ipynb` notebook
3. Run the cells in order to set up and run the EVP-KLEE demo

## Step 4: Cursor IDE Integration
1. Download the `evp_colab_demo.ipynb` notebook to your local machine
2. Open it in Cursor IDE
3. Install the Jupyter extension if not already installed
4. Connect to Google Colab runtime for cloud execution

## Troubleshooting
- If the archive is too large for Google Drive, try uploading individual directories
- Make sure you have enough Google Drive storage space
- The notebook will automatically detect and use the uploaded project files
