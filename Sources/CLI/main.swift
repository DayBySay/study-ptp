import ArgumentParser

@main
struct PTPTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ptp-tool",
        abstract: "PTP (Picture Transfer Protocol) learning tool",
        version: "0.1.0",
        subcommands: [
            DevicesCommand.self,
            InfoCommand.self,
            ListCommand.self,
            DownloadCommand.self
        ]
    )
}
