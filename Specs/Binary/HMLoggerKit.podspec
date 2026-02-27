Pod::Spec.new do |s|
  s.name             = "HMLoggerKit"
  s.module_name      = "LoggerKit"
  s.version          = "0.2.7"
  s.summary          = "LoggerKit binary XCFramework distribution."
  s.description      = <<-DESC
LoggerKit binary XCFramework distribution for validating release artifacts.
  DESC

  s.homepage         = "https://github.com/HeminWon/LoggerKit"
  s.license          = { :type => "MIT" }
  s.author           = { "HeminWon" => "heminwmh@gmail.com" }

  s.swift_version    = "5.9"
  s.platforms        = {
    :ios => "15.0",
    :osx => "12.0",
    :watchos => "8.0",
    :tvos => "15.0"
  }

  s.source           = {
    :http => "https://github.com/HeminWon/LoggerKit/releases/download/v#{s.version}/LoggerKit.xcframework.zip",
    :sha256 => "REPLACE_WITH_RELEASE_CHECKSUM"
  }

  s.vendored_frameworks = "LoggerKit.xcframework"
  s.dependency "SwiftyBeaver", "~> 2.1"
end
