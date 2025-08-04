Pod::Spec.new do |spec|
  spec.name          = 'gemma_wrapper'
  spec.version       = '0.0.1'
  spec.license       = { :file => '../LICENSE' }
  spec.homepage      = 'https://example.com'
  spec.authors       = { 'Your Company' => 'email@example.com' }
  spec.summary       = 'iOS/macOS Flutter plugin for Gemma model inference'
  spec.source        = { :path => '.' }
  spec.source_files  = 'Classes/**/*'
  spec.dependency 'Flutter'
  spec.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  spec.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  spec.swift_version = '5.0'

  # Add MediaPipe dependency
  spec.dependency 'MediaPipeTasksGenAI'
  
  # Link the native C++ library
  spec.vendored_libraries = '**/*.a'
  spec.vendored_frameworks = '**/*.framework'
  
  spec.xcconfig = {
    'OTHER_LDFLAGS' => '-framework MediaPipeTasksGenAI',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end