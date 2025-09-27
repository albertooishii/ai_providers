# Changelog

## [1.2.0] - 2025-09-27 🏆 PERFECT PUB.DEV SCORE (160/160)

### 🎉 Major Achievement
- **PERFECT PUB.DEV SCORE**: Achieved maximum 160/160 points on pub.dev analysis
- **100% Pass Rate**: All pub.dev scoring criteria now fully satisfied

### 🔧 API & Architecture Improvements
- **API Optimization**: Streamlined public API surface from 16 to 10 essential exports
- **Removed exports**: `ai_provider_config.dart`, `ai_provider_metadata.dart`, `retry_config.dart`
- **Enhanced**: Optimized export organization for better developer experience
- **Maintained**: Full backward compatibility for `AI.*` facade methods

### 📋 Pub.dev Scoring Improvements
- **Follow Dart file conventions**: 30/30 (was 10/30) - Perfect compliance
- **Pass static analysis**: 50/50 (was 40/50) - Zero warnings/errors
- **Support up-to-date dependencies**: 40/40 (was 20/40) - Full compatibility
- **Provide documentation**: 20/20 - Maintained excellent documentation
- **Platform support**: 20/20 - Full multi-platform support

### 🛠️ Technical Optimizations
- **Fixed**: Dependency constraint lower bounds compatibility issues
- **Updated**: Example app dependencies (file_picker 8.3.7 → 10.3.3)
- **Corrected**: Code formatting to match Dart style guidelines
- **Enhanced**: Apache 2.0 license recognition and compliance

### 📊 Quality Metrics
- **Code Quality**: Zero static analysis issues
- **Documentation**: 60.4% API coverage with comprehensive examples
- **Compatibility**: Full downgrade/upgrade dependency testing
- **Performance**: Optimized export structure reduces compilation overhead

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