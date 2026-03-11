import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var messages: [ParsedMessage] = []
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isLoading = false
    @State private var showInstructions = false

    private var conversationCount: Int {
        Set(messages.map(\.chatIdentifier)).count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if messages.isEmpty {
                    emptyStateView
                } else {
                    resultsView
                }
            }
            .padding()
            .navigationTitle("SMS Scraper")
            .toolbar {
                if !messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            messages = []
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.database, .data, .item],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .sheet(isPresented: $isExporting) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .sheet(isPresented: $showInstructions) {
                instructionsSheet
            }
            .overlay {
                if isLoading {
                    ProgressView("Parsing messages...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "message.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Import your chat.db")
                .font(.title2.bold())

            Text("Import the iMessage/SMS database from an iPhone or Mac backup to extract all messages into a text file.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button {
                isImporting = true
            } label: {
                Label("Import chat.db", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Button("How do I get chat.db?") {
                showInstructions = true
            }
            .font(.subheadline)

            Spacer()
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 16) {
            // Stats
            HStack(spacing: 20) {
                StatCard(title: "Messages", value: "\(messages.count)", icon: "message.fill")
                StatCard(title: "Conversations", value: "\(conversationCount)", icon: "person.2.fill")
            }

            // Export buttons
            VStack(spacing: 12) {
                Button {
                    exportAsText()
                } label: {
                    Label("Export as Text File", systemImage: "doc.text")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)

                Button {
                    exportAsCSV()
                } label: {
                    Label("Export as CSV", systemImage: "tablecells")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
            }

            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.headline)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(messages.prefix(200)) { msg in
                            HStack(alignment: .top, spacing: 8) {
                                Text(msg.isFromMe ? "Me" : msg.handle)
                                    .font(.caption.bold())
                                    .foregroundStyle(msg.isFromMe ? .blue : .green)
                                    .frame(width: 80, alignment: .trailing)

                                Text(msg.text)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                        }
                        if messages.count > 200 {
                            Text("... and \(messages.count - 200) more messages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(8)
                }
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Instructions Sheet

    private var instructionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    instructionSection(
                        title: "Option 1: From a Mac with iMessage",
                        steps: [
                            "On your Mac, open Finder",
                            "Press Cmd+Shift+G and go to:\n~/Library/Messages/",
                            "Copy the chat.db file",
                            "AirDrop or transfer it to your iPhone",
                            "Open it with this app from Files"
                        ]
                    )

                    instructionSection(
                        title: "Option 2: From an iPhone Backup",
                        steps: [
                            "Connect iPhone to Mac and make a local backup (not encrypted) via Finder",
                            "The backup is stored in:\n~/Library/Application Support/MobileSync/Backup/",
                            "Inside the backup folder, find the file named:\n3d0d7e5fb2ce288813306e4d4636395e047a3d28",
                            "This is the chat.db file — rename it to chat.db",
                            "Transfer to your iPhone and open with this app"
                        ]
                    )

                    instructionSection(
                        title: "Option 3: Using iMazing or 3uTools",
                        steps: [
                            "Download iMazing (trial works) on your Mac/PC",
                            "Connect your iPhone",
                            "Browse the file system and navigate to SMS",
                            "Export the chat.db database file",
                            "Transfer to iPhone and open with this app"
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("Getting chat.db")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showInstructions = false }
                }
            }
        }
    }

    private func instructionSection(title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    Text(step)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isLoading = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let parser = ChatDBParser()
                    let parsed = try parser.parse(fileURL: url)
                    DispatchQueue.main.async {
                        self.messages = parsed
                        self.isLoading = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                        self.isLoading = false
                    }
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func exportAsText() {
        do {
            let url = try MessageExporter.exportToTextFile(messages: messages)
            exportURL = url
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func exportAsCSV() {
        do {
            let url = try MessageExporter.exportToCSV(messages: messages)
            exportURL = url
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - UTType Extension

extension UTType {
    static let database = UTType(filenameExtension: "db") ?? .data
}
