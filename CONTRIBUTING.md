# Contributing to OpenTrack Neural Net AppImage Builder

Thanks for your interest in contributing! This project automates building OpenTrack AppImages with neural network support.

## 🐛 Reporting Issues

If you encounter problems with the AppImage:

1. **Check existing issues** to see if it's already reported
2. **Include system information**:
   - Linux distribution and version
   - Output of `uname -a`
   - Any error messages
3. **Describe the issue**:
   - What you expected to happen
   - What actually happened
   - Steps to reproduce

## 🔧 Making Changes

### Testing Locally

Before submitting changes to the workflow, test locally:

```bash
./test-build.sh opentrack-2.3.14
```

This script mimics the CI build process and helps catch issues early.

### Workflow Changes

The main build logic is in `.github/workflows/build-appimage.yml`. When modifying:

1. **Test on your fork** first using workflow_dispatch
2. **Document changes** in your pull request
3. **Consider backward compatibility** with existing releases

### Adding Features

Ideas for contributions:

- **GPU support**: Add CUDA/ROCm builds (separate workflow recommended)
- **ARM64 support**: Build for ARM-based systems
- **Additional trackers**: Include extra tracking plugins
- **Testing**: Add automated tests in Docker containers
- **Documentation**: Improve setup guides, troubleshooting

## 📝 Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly
5. Commit with clear messages
6. Push to your fork
7. Open a pull request with:
   - Clear description of changes
   - Testing performed
   - Any breaking changes

## 🎯 Code Style

- Use 2-space indentation in YAML
- Add comments for non-obvious logic
- Keep workflow steps focused and named clearly

## 📮 Questions?

Open an issue for discussion before starting major changes. This helps ensure your contribution aligns with project goals.

## 📜 License

By contributing, you agree your contributions will be available under the same license as the project (build scripts are MIT, OpenTrack itself has its own license).
