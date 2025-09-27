# Changelog

## [1.1.2] - 2025-09-27

### Changed
- **BREAKING**: Changed license from CC BY-NC-ND 4.0 to Apache License 2.0
- Updated all license references in README.md
- Commercial use now permitted without restrictions
- Modifications and derivative works now allowed
- Enhanced patent protection for users and contributors

### Benefits
- Enterprise-friendly licensing for commercial adoption
- Compatible with Flutter/Dart ecosystem standards
- Patent litigation protection included
- Easier adoption for businesses and developers

## [1.1.1] - 2025-09-27

### Fixed
- Added explicit license field in pubspec.yaml for proper pub.dev recognition
- Fixed documentation references in ai_init_config.dart to reduce dartdoc warnings
- Updated test dependency to Flutter-compatible version
- Improved pub.dev score compliance

### Documentation
- Better formatted code examples in API documentation
- Reduced dartdoc warnings from 3 to 2

## [1.1.0] - 2025-09-26

### Added
- Unified AI facade API with `AI.text()`, `AI.image()`, `AI.speak()`, `AI.listen()`
- Multi-provider support: OpenAI, Google Gemini, X.AI Grok, Android Native
- Dynamic provider routing with automatic fallback
- YAML configuration support
- Example app with demos for all capabilities
- Comprehensive documentation in Spanish

### Features
- Text generation (GPT-4.1-mini, Gemini 2.5 Flash, Grok-4)
- Image generation (GPT-4.1-mini, Gemini 2.5 Flash Image Preview) 
- Audio generation and transcription (Gemini native TTS/STT, Android native, OpenAI)
- Image analysis (Gemini 2.5 Flash, GPT-4.1-mini, Grok Vision)

## [1.0.0] - 2025-09-25

### Added
- Initial release