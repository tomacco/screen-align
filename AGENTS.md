# Agent instructions

- Swift package: `ScreenAlignCore` (pure logic, tested) and `ScreenAlign` (AppKit app). Keep AppKit out of the core.
- Code standard: Primera Plana, Swift edition (https://github.com/tomacco/primera-plana/blob/main/guides/swift.md). Short public headlines, private leaves in a `// MARK: - Leaves` extension, no force unwraps, `Result` with enum errors, system access behind protocols.
- Test: `make test` (adds the swift-testing plugin path when only the Command Line Tools are installed).
- Build and install the app: `make install`.
- Never press Return in the running app during automated checks: it rewrites the real display arrangement.
