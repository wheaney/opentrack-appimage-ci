# OpenTrack Neural Net AppImage Builder

Automated builds of [OpenTrack](https://github.com/opentrack/opentrack) with ONNX Runtime (CPU) neural network support, packaged as portable AppImages for Linux.

## 🎯 What is this?

This repository automatically monitors OpenTrack releases and builds AppImage packages that include:
- Full OpenTrack functionality
- ONNX Runtime for neural network-based head tracking
- All dependencies bundled (no installation required)
- Works across most Linux distributions

## 📦 Download

Get the latest build from the [Releases](../../releases) page.

## 🚀 Quick Start

```bash
# Download the AppImage from Releases
chmod +x OpenTrack-NeuralNet-*-x86_64.AppImage

# Run it!
./OpenTrack-NeuralNet-*-x86_64.AppImage
```

No installation needed. The AppImage contains everything required to run OpenTrack with neural network support.

## 🔄 Build Process

The GitHub Actions workflow:
1. **Checks daily** for new OpenTrack releases
2. **Builds automatically** when a new version is detected
3. **Compiles OpenTrack** with ONNX Runtime CPU support
4. **Bundles dependencies** using linuxdeploy
5. **Creates AppImage** and publishes as a GitHub Release

## 🛠️ Manual Build Trigger

You can manually trigger a build for a specific OpenTrack version:

1. Go to the [Actions](../../actions) tab
2. Select "Build OpenTrack AppImage"
3. Click "Run workflow"
4. Enter the OpenTrack version tag (e.g., `opentrack-2.3.14`) or leave as "latest"

## 📋 System Requirements

- **OS**: Linux x86_64 (any modern distribution)
- **FUSE**: Required for AppImage support (pre-installed on most distros)
- **Webcam**: Or other video input device for head tracking

## ❓ FAQ

### Why AppImage?

AppImages are portable, self-contained applications that run on any Linux distribution without installation. No need to:
- Deal with distribution-specific package managers
- Compile from source
- Hunt down dependencies
- Worry about library conflicts

### CPU vs GPU?

This build uses **CPU-only** ONNX Runtime, which works universally across all systems. GPU builds require specific CUDA versions and drivers, making them less portable.

CPU performance is sufficient for real-time head tracking on most modern processors.

### What's the difference from official OpenTrack?

Official OpenTrack releases may not include neural network support or ONNX Runtime by default. This build ensures ONNX Runtime is compiled in and bundled for easy use of neuralnet trackers.

## 🔧 Building Locally

If you want to build on your own machine:

```bash
# Install dependencies
sudo apt-get install build-essential cmake git qtbase5-dev qttools5-dev libopencv-dev

# Clone this repo
git clone https://github.com/YOUR_USERNAME/opentrack-neuralnet-appimage.git
cd opentrack-neuralnet-appimage

# The workflow file contains all build steps
# You can extract and run them locally
```

## 📝 License

This repository contains build scripts only. OpenTrack itself is licensed under the ISC license. See the [OpenTrack repository](https://github.com/opentrack/opentrack) for details.

## 🤝 Contributing

Issues and pull requests welcome! Especially:
- Build improvements
- Testing on different distros
- Documentation updates

## 🙏 Credits

- [OpenTrack](https://github.com/opentrack/opentrack) - The amazing head tracking software
- [ONNX Runtime](https://github.com/microsoft/onnxruntime) - Neural network inference engine
- [linuxdeploy](https://github.com/linuxdeploy/linuxdeploy) - AppImage creation tool
