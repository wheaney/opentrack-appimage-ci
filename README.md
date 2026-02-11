# OpenTrack AppImage Builder

Automated builds of [OpenTrack](https://github.com/opentrack/opentrack) packaged as portable AppImages for Linux, with optional ONNX Runtime (CPU/GPU) support for the neuralnet tracker.

## What is this?

This repository automatically monitors OpenTrack releases and builds AppImage packages that include:
- Full OpenTrack functionality
- Optional ONNX Runtime for neural network-based head tracking (neuralnet tracker)
- All dependencies bundled (no installation required)
- Works across most Linux distributions

## Setup

### Download

Get the latest build from the [Releases](../../releases) page.

You'll find three different flavors:

- **NoONNX**: OpenTrack without NeuralNet (no ONNX Runtime bundled)
- **ONNX-CPU**: OpenTrack with NeuralNet (ONNX Runtime CPU bundled)
- **ONNX-GPU**: OpenTrack with GPU-based NeuralNet processing (ONNX Runtime GPU bundled)

### Run
```bash
# Make it executable
chmod +x OpenTrack-*-x86_64.AppImage

# Run it
./OpenTrack-*-x86_64.AppImage
```

No installation needed. The AppImage contains everything required to run OpenTrack (with optional NeuralNet support).