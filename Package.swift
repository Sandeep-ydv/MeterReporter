// swift-tools-version: 5.8

import PackageDescription

let package = Package(
	name: "MeterReporter",
	platforms: [
		.macOS(.v11),
		.macCatalyst(.v13),
		.iOS(.v13),
		.tvOS(.v12),
		.watchOS(.v4)
	],
	products: [
		.library(name: "MeterReporter", targets: ["MeterReporter"]),
	],
	dependencies: [
		.package(url: "https://github.com/ChimeHQ/Meter", from: "0.4.0"),
		.package(url: "https://github.com/Sandeep-ydv/Wells", revision: "5219f4e800469541185bd2d92c199475e677eef9"),
	],
	targets: [
		.target(name: "MeterReporter", dependencies: ["Meter", "Wells"]),
	]
)

let swiftSettings: [SwiftSetting] = [
	.enableExperimentalFeature("StrictConcurrency")
]

for target in package.targets {
	var settings = target.swiftSettings ?? []
	settings.append(contentsOf: swiftSettings)
	target.swiftSettings = settings
}
