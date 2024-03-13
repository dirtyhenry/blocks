#!/usr/bin/swift

import Foundation

public struct SimpleMessageError: Error {
    let message: String

    public init(message: String) {
        self.message = message
    }
}

extension SimpleMessageError: LocalizedError {
    public var errorDescription: String? {
        message
    }
}

struct DeviceContainer: Codable {
    let devices: [String: [Simulator]]
}

struct Simulator: Codable, Equatable {
    let lastBootedAt: String?
    let dataPath: String
    let dataPathSize: Int
    let logPath: String
    let udid: String
    let isAvailable: Bool
    let logPathSize: Int?
    let deviceTypeIdentifier: String
    let state: String
    let name: String
}

struct ZipOSSimulator: Comparable, CustomStringConvertible {
    let osIdentifier: String
    let simulator: Simulator

    // MARK: - CustomStringConvertible

    var description: String {
        "\(simulator.udid): \(formattedOSAndSimulator)"
    }

    var formattedOS: String {
        (try? formatOSIdentifier(osIdentifier)) ?? "n/a"
    }

    var formattedOSAndSimulator: String {
        "\(formattedOS), \(simulator.name)"
    }

    // MARK: - Comparable

    static func < (lhs: ZipOSSimulator, rhs: ZipOSSimulator) -> Bool {
        lhs.formattedOSAndSimulator < rhs.formattedOSAndSimulator
    }

    private func formatOSIdentifier(_ identifier: String) throws -> String {
        let pattern = #"com\.apple\.CoreSimulator\.SimRuntime\.([a-zA-Z]+)-(\d+)-(\d+)"#

        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsrange = NSRange(identifier.startIndex ..< identifier.endIndex, in: identifier)

        if let match = regex?.firstMatch(in: identifier, options: [], range: nsrange) {
            if let osRange = Range(match.range(at: 1), in: identifier),
               let majorVersionRange = Range(match.range(at: 2), in: identifier),
               let minorVersionRange = Range(match.range(at: 3), in: identifier) {
                let os = identifier[osRange]
                let majorVersion = identifier[majorVersionRange]
                let minorVersion = identifier[minorVersionRange]

                return "\(os) \(majorVersion).\(minorVersion)"
            }
        }

        throw SimpleMessageError(message: "formatDeviceIdentifier could not format \(identifier)")
    }
}

func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.standardInput = nil
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output
}

func find(osName: String?, deviceName: String?, in rawOutput: String) throws -> [ZipOSSimulator] {
    try JSONDecoder()
        .decode(DeviceContainer.self, from: Data(rawOutput.utf8))
        .devices
        .reduce(into: [ZipOSSimulator].init()) { partialResult, newItem in
            partialResult.append(contentsOf: newItem.value.map {
                ZipOSSimulator(osIdentifier: newItem.key,
                               simulator: $0)
            })
        }
        .filter { osName == nil ? true : $0.formattedOS == osName }
        .filter { deviceName == nil ? true : $0.simulator.name == deviceName }
}

if CommandLine.argc != 3 {
    print("Usage: ./\(CommandLine.arguments[0]) \"os\" \"device\"")
} else {
    let rawAvailableDevicesJSON = shell("xcrun simctl list --json devices available")
    let filteredZippedResults = try find(osName: CommandLine.arguments[1], deviceName: CommandLine.arguments[2], in: rawAvailableDevicesJSON)
    precondition(filteredZippedResults.count == 1)
    print(filteredZippedResults.first!.simulator.udid)
}
