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
		.package(url: "https://github.com/Sandeep-ydv/Wells", revision: "b7e988b3fd1758d42e01eaee715aff166b3e718b"),
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
