# Quick Reference Card

## 🚀 Get Started in 3 Steps

1. **Create GitHub repo**: `opentrack-neuralnet-appimage`
2. **Copy all files** from this directory to your repo
3. **Push to GitHub** - automation starts immediately!

## 📁 Essential Files

| File | Purpose |
|------|---------|
| `.github/workflows/build-appimage.yml` | **Main CI/CD** - Builds AppImages automatically |
| `README.md` | User documentation |
| `test-build.sh` | Test builds locally |
| `.gitignore` | Keep repo clean |

## ⚡ Commands

```bash
# Test locally
./test-build.sh opentrack-2.3.14

# Manual CI trigger (on GitHub)
Actions → Build OpenTrack AppImage → Run workflow

# Check latest release
curl -s https://api.github.com/repos/YOUR_USER/opentrack-neuralnet-appimage/releases/latest | jq -r '.tag_name'
```

## 🔧 Workflow Features

- ✅ Checks daily at 6 AM UTC for new OpenTrack versions
- ✅ Builds only when new version detected
- ✅ Creates GitHub release automatically
- ✅ Supports manual builds via workflow_dispatch
- ✅ Uses Ubuntu 22.04 for compatibility

## 📦 What Gets Built

- OpenTrack (latest or specified version)
- ONNX Runtime 1.17.1 (CPU)
- All Qt dependencies
- All system libraries
- Packaged as portable AppImage

## 🎯 Typical Use Cases

**For users**: Download AppImage from Releases, make executable, run
**For contributors**: Fork, modify, test locally, submit PR
**For automation**: Set it up once, forget it - new builds happen automatically

## 🐛 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Build fails | Check Actions logs, test with `test-build.sh` |
| AppImage won't run | Ensure FUSE installed: `sudo apt install fuse libfuse2` |
| Want specific version | Use workflow_dispatch with version tag |
| Need GPU support | Create separate workflow (not yet implemented) |

## 📝 Customization Points

Edit `.github/workflows/build-appimage.yml` to change:
- Schedule: `cron: '0 6 * * *'`
- ONNX version: `ONNX_VERSION="1.17.1"`
- OpenTrack build flags: `cmake .. -D...`
- Release naming: `OpenTrack-NeuralNet-${VERSION}-x86_64.AppImage`

## 🔗 Useful Links

- OpenTrack: https://github.com/opentrack/opentrack
- ONNX Runtime: https://github.com/microsoft/onnxruntime
- linuxdeploy: https://github.com/linuxdeploy/linuxdeploy
- AppImage docs: https://docs.appimage.org/

---

**Pro tip**: Star the OpenTrack repo and enable notifications to see when they release new versions!
