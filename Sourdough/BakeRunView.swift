import SwiftUI
import SourdoughKit

/// A bake in progress: the step that is due, with its instructions, and the
/// whole sequence with planned and actual times.
struct BakeRunView: View {
    let store: BakeRunStore
    let id: BakeRun.ID
    /// Back to the start screen.
    let onClose: () -> Void
    @State private var confirmCancel = false
    /// The page of a `tip:` link in the instructions, shown as a sheet.
    @State private var linkedTip: TipsTopic.ID?

    var body: some View {
        if let run = store.run(id) {
            content(run)
        }
    }

    private func content(_ run: BakeRun) -> some View {
        Form {
            Section {
                LabeledContent("Anschnittfertig") {
                    Text(ScheduleText.day(run.target, calendar: run.calendar))
                }
                .accessibilityIdentifier("run-target")
            } footer: {
                Text(run.status == .active ? "Läuft seit \(ScheduleText.day(run.startedAt, calendar: run.calendar))."
                     : "Durchgang \(BakeRunText.status(run.status)).")
                    .accessibilityIdentifier("run-status")
            }
            if run.status == .active, let step = run.current {
                currentSection(run, step)
            }
            if run.status == .finished {
                Section {
                    Text("Dein Brot ist anschnittfertig. Guten Appetit!")
                        .accessibilityIdentifier("run-finished")
                    Button("Zum Startbildschirm", action: onClose)
                        .accessibilityIdentifier("run-close")
                    undoButton(run)
                }
            }
            Section("Ablauf") {
                ForEach(Array(BakeProcess.StepID.allCases.enumerated()), id: \.offset) { index, step in
                    stepRow(run, step)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("run-step-\(index)")
                }
            }
            if run.status == .active {
                Section {
                    Button("Durchgang abbrechen", role: .destructive) { confirmCancel = true }
                        .accessibilityIdentifier("run-cancel")
                }
            }
        }
        .navigationTitle(run.bread.germanName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { TipsButton(topic: .run) }
        .environment(\.openURL, OpenURLAction { TipsText.open($0) { linkedTip = $0 } })
        .sheet(item: $linkedTip) { TipsView(initial: $0) }
        .alert("Durchgang abbrechen?", isPresented: $confirmCancel) {
            Button("Abbrechen", role: .destructive) {
                store.cancel(id, at: Date())
                onClose()
            }
            Button("Weiterbacken", role: .cancel) {}
        } message: {
            Text("Der Durchgang bleibt im Backprotokoll.")
        }
    }

    @ViewBuilder
    private func currentSection(_ run: BakeRun, _ step: BakeProcess.StepID) -> some View {
        let answers = BakeProcess.answers(step, setup: run.setup)
        Section {
            Text("Geplant: \(ScheduleText.time(BakeProcess.plannedTime(step, in: run.schedule), calendar: run.calendar))")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("run-planned")
            MarkdownBlocks(markdown: BakeRunText.markdown(run, step), id: "run-text")
            if run.isWaiting, let wait = BakeRunText.waitMarkdown(run, step) {
                MarkdownBlocks(markdown: wait, id: "run-hint")
                    .padding(.vertical, 4)
            }
            if answers.isEmpty {
                Button("Erledigt") { store.complete(id, at: Date()) }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("run-done")
            } else {
                ForEach(answers, id: \.self) { answer in
                    Button(BakeRunText.answer(answer)) { store.answer(id, answer, at: Date()) }
                        .accessibilityIdentifier("run-answer-\(answer.rawValue)")
                }
            }
            undoButton(run)
        } header: {
            Text("Jetzt")
        }
    }

    /// Opens the last done step again, for a tap by mistake.
    @ViewBuilder
    private func undoButton(_ run: BakeRun) -> some View {
        if let previous = run.previous {
            Button {
                store.undo(id)
            } label: {
                Label(BakeRunText.undoLabel(run, previous), systemImage: "arrow.uturn.backward")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("run-undo")
        }
    }

    private func stepRow(_ run: BakeRun, _ step: BakeProcess.StepID) -> some View {
        let planned = BakeProcess.plannedTime(step, in: run.schedule)
        let done = run.done[step]
        return HStack(alignment: .firstTextBaseline) {
            Image(systemName: done == nil ? (step == run.current ? "circle.inset.filled" : "circle") : "checkmark.circle.fill")
                .foregroundStyle(done == nil ? Color.secondary : Color.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(BakeRunText.title(run, step))
                Text(done.map { "erledigt \(ScheduleText.time($0, calendar: run.calendar))" }
                     ?? "geplant \(ScheduleText.time(planned, calendar: run.calendar))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Markdown of the small subset the tips use, as a column of text.
struct MarkdownBlocks: View {
    let markdown: String
    let id: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(TipsParser.parse(markdown).enumerated()), id: \.offset) { _, block in
                TipsBlockView(block: block, compact: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}
