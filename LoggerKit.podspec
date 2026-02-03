Pod::Spec.new do |s|
  s.name             = "LoggerKit"
  s.version          = "0.2.0"
  s.summary          = "High-performance logging framework based on SwiftyBeaver."
  s.description      = <<-DESC
LoggerKit is a high-performance, multi-platform logging framework based on SwiftyBeaver.
It supports dependency injection, multiple destinations (console and file), log rotation,
JSON log files, SwiftUI Environment integration, and a built-in log viewer UI.
  DESC

  s.homepage         = "https://github.com/HeminWon/LoggerKit"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "HeminWon" => "heminwon@gmail.com" }
  s.source           = { :git => "https://github.com/HeminWon/LoggerKit.git", :tag => s.version.to_s }

  s.swift_version    = "5.9"
  s.platforms        = {
    :ios => "15.0",
    :osx => "12.0",
    :watchos => "8.0",
    :tvos => "15.0"
  }

  s.source_files     = "Sources/LoggerKit/**/*.{swift}"
  s.resource_bundles = {
    "LoggerKit" => ["Sources/LoggerKit/Resources/**/*"]
  }

  s.dependency "SwiftyBeaver", "~> 2.1"
end
