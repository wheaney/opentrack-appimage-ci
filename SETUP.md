# Repository Structure

```
opentrack-neuralnet-appimage/
├── .github/
│   └── workflows/
│       └── build-appimage.yml    # Main CI/CD workflow
├── .gitignore                     # Git ignore patterns
├── README.md                      # Main documentation
├── CONTRIBUTING.md                # Contribution guidelines
├── LICENSE                        # MIT license for build scripts
├── test-build.sh                  # Local testing script
└── build-opentrack-appimage.sh    # Legacy standalone build script (optional)
```

## Quick Setup Instructions

### 1. Create a new GitHub repository

```bash
# On GitHub, create a new repository named "opentrack-neuralnet-appimage"
# Then clone it locally:
git clone https://github.com/YOUR_USERNAME/opentrack-neuralnet-appimage.git
cd opentrack-neuralnet-appimage
```

### 2. Copy these files to your repository

Copy all the files from this directory:
- `.github/workflows/build-appimage.yml`
- `.gitignore`
- `README.md`
- `CONTRIBUTING.md`
- `LICENSE`
- `test-build.sh`
- (optional) `build-opentrack-appimage.sh`

### 3. Push to GitHub

```bash
git add .
git commit -m "Initial commit: automated OpenTrack AppImage builder"
git push origin main
```

### 4. Enable GitHub Actions

1. Go to your repository on GitHub
2. Click on the "Actions" tab
3. If prompted, enable Actions for this repository

### 5. The workflow will now:

- ✅ Check daily for new OpenTrack releases (6 AM UTC)
- ✅ Automatically build AppImages when new versions are released
- ✅ Create GitHub releases with the AppImage attached
- ✅ Allow manual builds via workflow_dispatch

### 6. Manual trigger (optional)

To build immediately:
1. Go to Actions → Build OpenTrack AppImage
2. Click "Run workflow"
3. Choose a specific version or leave as "latest"
4. Click "Run workflow" button

## What each file does

### `.github/workflows/build-appimage.yml`
The heart of the automation. This GitHub Actions workflow:
- Monitors OpenTrack for new releases
- Builds OpenTrack from source with ONNX Runtime
- Creates an AppImage with all dependencies bundled
- Publishes releases automatically

### `test-build.sh`
Local testing script that mimics the CI build process. Useful for:
- Testing changes before pushing to CI
- Debugging build issues locally
- Understanding the build process

### `build-opentrack-appimage.sh`
Standalone build script for manual AppImage creation. Can be used independently of the GitHub Actions workflow.

### `README.md`
User-facing documentation explaining:
- What the project does
- How to download and use AppImages
- System requirements
- FAQ

### `CONTRIBUTING.md`
Guidelines for contributors on:
- Reporting issues
- Testing changes locally
- Submitting pull requests

## Customization Options

### Change check schedule
Edit `.github/workflows/build-appimage.yml`:
```yaml
schedule:
  - cron: '0 6 * * *'  # Change this cron expression
```

### Use different ONNX Runtime version
Edit the workflow:
```yaml
ONNX_VERSION="1.17.1"  # Change version here
```

### Build specific OpenTrack versions only
Modify the `check-version` job to filter by version pattern.

### Add GPU support
Create a separate workflow or add a matrix build strategy with CUDA support.

## Troubleshooting

### Builds failing?
1. Check the Actions tab for error logs
2. Test locally with `./test-build.sh`
3. Verify OpenTrack repository is accessible
4. Check ONNX Runtime download URLs are valid

### AppImage not working on some distros?
1. Test in Docker: `docker run -it ubuntu:22.04`
2. Check for missing FUSE support
3. Verify all libraries are bundled: `./AppImage --appimage-extract`

### Want to build older versions?
Use workflow_dispatch and specify the exact tag like `opentrack-2.3.13`
