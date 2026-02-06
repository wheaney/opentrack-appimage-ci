# OpenTrack AppImage Builder

Automated builds of [OpenTrack](https://github.com/opentrack/opentrack) packaged as portable AppImages for Linux, with optional ONNX Runtime (CPU/GPU) support for the neuralnet tracker.

## 🎯 What is this?

This repository automatically monitors OpenTrack releases and builds AppImage packages that include:
- Full OpenTrack functionality
- Optional ONNX Runtime for neural network-based head tracking (neuralnet tracker)
- All dependencies bundled (no installation required)
- Works across most Linux distributions

## 📦 Download

Get the latest build from the [Releases](../../releases) page.

## 🚀 Quick Start

```bash
# Download one of the AppImages from Releases
chmod +x OpenTrack-*-x86_64.AppImage

# Run it
./OpenTrack-*-x86_64.AppImage
```

No installation needed. The AppImage contains everything required to run OpenTrack with neural network support.

## 🔄 Build Process

The GitHub Actions workflow:
1. **Checks daily** for new OpenTrack releases
2. **Builds automatically** when a new version is detected
3. **Builds multiple flavors** in a matrix
4. **Bundles dependencies** using linuxdeploy + linuxdeploy-plugin-qt
5. **Creates AppImages** and publishes them as a GitHub Release

### Output flavors

Each run produces up to three AppImages:

- **NoONNX**: OpenTrack without ONNX Runtime bundled
- **ONNX-CPU**: ONNX Runtime CPU bundled for neuralnet
- **ONNX-GPU**: ONNX Runtime GPU bundled (requires CUDA/NVIDIA runtime libraries on the target system)

## 🛠️ Manual Build Trigger

You can manually trigger a build for a specific OpenTrack version:

1. Go to the [Actions](../../actions) tab
2. Select "Build OpenTrack AppImage"
3. Click "Run workflow"
4. Enter the OpenTrack version tag (e.g., `opentrack-2.3.14`) or leave as "latest"

## 📋 System Requirements

- **OS**: Linux x86_64 (any modern distribution)
- **FUSE**: Typically required to run AppImages. If unavailable, you can often run with `APPIMAGE_EXTRACT_AND_RUN=1`.
- **Webcam**: Or other video input device for head tracking

## ❓ FAQ

### Why AppImage?

AppImages are portable, self-contained applications that run on any Linux distribution without installation. No need to:
- Deal with distribution-specific package managers
- Compile from source
- Hunt down dependencies
- Worry about library conflicts

### CPU vs GPU?

`ONNX-CPU` is the most portable option. `ONNX-GPU` depends on CUDA/TensorRT libraries (e.g. `libcudart`, `libcublas`, `libcudnn`, etc.) being available on the target machine, so it is less portable.

### What's the difference from official OpenTrack?

Official OpenTrack releases may not include neural network support or ONNX Runtime by default. This build ensures ONNX Runtime is compiled in and bundled for easy use of neuralnet trackers.

## 🔧 Building Locally

The canonical build instructions live in the GitHub Actions workflow: [.github/workflows/build-appimage.yml](.github/workflows/build-appimage.yml). If you want to run it locally, mirror the steps from that workflow on an Ubuntu 24.04 environment.

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
