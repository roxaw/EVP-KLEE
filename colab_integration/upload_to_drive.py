#!/usr/bin/env python3
"""
Script to help upload EVP-KLEE project to Google Drive for Colab integration.
This script creates a compressed archive of essential project files.
"""

import os
import shutil
import tarfile
from pathlib import Path
from datetime import datetime

def create_project_archive():
    """Create a compressed archive of the EVP-KLEE project for Google Drive upload."""
    
    # Get project root (parent of colab_integration directory)
    project_root = Path(__file__).parent.parent
    print(f"Project root: {project_root}")
    print(f"Current working directory: {os.getcwd()}")
    
    # Verify we're in the right location
    if not (project_root / "automated_demo").exists():
        print("❌ Error: automated_demo directory not found.")
        print(f"Looking for: {project_root / 'automated_demo'}")
        print(f"Available directories: {list(project_root.iterdir())}")
        return None
    
    # Create temporary directory for archive
    temp_dir = Path("/tmp/evp-klee-upload")
    if temp_dir.exists():
        shutil.rmtree(temp_dir)
    temp_dir.mkdir(parents=True)
    
    # Define essential files and directories to include
    essential_items = [
        "automated_demo/",
        "benchmarks/",
        "scripts/",
        "docs/",
        "klee/",
        "src/",
        "include/",
        "third_party/",
        "CMakeLists.txt",
        "Makefile",
        "README.md",
        "requirements.txt",
        "pyrightconfig.json",
        "justfile",
        "CONTRIBUTING.md"
    ]
    
    # Copy essential items to temp directory
    print("Copying essential project files...")
    for item in essential_items:
        src_path = project_root / item
        dst_path = temp_dir / item
        
        if src_path.exists():
            if src_path.is_dir():
                try:
                    shutil.copytree(src_path, dst_path, symlinks=True)
                    print(f"  ✓ Copied directory: {item}")
                except Exception as e:
                    print(f"  ⚠ Error copying directory {item}: {e}")
            else:
                try:
                    dst_path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src_path, dst_path, follow_symlinks=False)
                    print(f"  ✓ Copied file: {item}")
                except Exception as e:
                    print(f"  ⚠ Error copying file {item}: {e}")
        else:
            print(f"  ⚠ Skipped (not found): {item}")
    
    # Create archive
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    archive_name = f"EVP-KLEE-{timestamp}.tar.gz"
    archive_path = project_root / "colab_integration" / archive_name
    
    print(f"\nCreating archive: {archive_name}")
    with tarfile.open(archive_path, "w:gz") as tar:
        tar.add(temp_dir, arcname="EVP-KLEE")
    
    # Clean up temp directory
    shutil.rmtree(temp_dir)
    
    # Get archive size
    archive_size = archive_path.stat().st_size / (1024 * 1024)  # MB
    print(f"✓ Archive created: {archive_path}")
    print(f"✓ Archive size: {archive_size:.2f} MB")
    
    return archive_path

def create_upload_instructions():
    """Create instructions for uploading to Google Drive."""
    
    instructions = """
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
"""
    
    instructions_file = Path(__file__).parent / "UPLOAD_INSTRUCTIONS.md"
    with open(instructions_file, 'w') as f:
        f.write(instructions)
    
    print(f"✓ Upload instructions created: {instructions_file}")

def main():
    """Main function to create project archive and instructions."""
    print("EVP-KLEE Google Drive Upload Helper")
    print("=" * 40)
    
    try:
        # Create project archive
        archive_path = create_project_archive()
        
        # Create upload instructions
        create_upload_instructions()
        
        print("\n" + "=" * 40)
        print("✓ Setup complete!")
        print(f"✓ Archive ready: {archive_path}")
        print("✓ Instructions created: UPLOAD_INSTRUCTIONS.md")
        print("\nNext steps:")
        print("1. Upload the archive to Google Drive")
        print("2. Extract it in your Google Drive")
        print("3. Open evp_colab_demo.ipynb in Google Colab")
        print("4. Run the notebook to execute the EVP-KLEE demo")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
