import SwiftUI
import AppKit
import SwiftUI
import AppKit

class VariableTextViewController: NSViewController {
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private let storage: VariableTextStorage
    private let onTextChange: (String) -> Void
    private let onInsertVariable: () -> Void
    private var isInternalChange = false
    private var keyboardMonitor: Any?

    init(text: String, storage: VariableTextStorage, onTextChange: @escaping (String) -> Void, onInsertVariable: @escaping () -> Void) {
        self.storage = storage
        self.onTextChange = onTextChange
        self.onInsertVariable = onInsertVariable
        super.init(nibName: nil, bundle: nil)

        // Initialize the storage with the text
        isInternalChange = true
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
        isInternalChange = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.focusRingType = .none

        // Create text view with our custom storage
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer()
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)

        textView = NSTextView(frame: .zero, textContainer: container)
        textView.allowsUndo = true
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isFieldEditor = false
        textView.focusRingType = .none

        // Set default text attributes
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ]
        textView.typingAttributes = defaultAttributes
        storage.setAttributes(defaultAttributes, range: NSRange(location: 0, length: storage.length))

        // Set up text view
        textView.delegate = self
        textView.textContainerInset = NSSize(width: 5, height: 5)

        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalRuler = false
        scrollView.hasHorizontalRuler = false
        scrollView.drawsBackground = true

        // Set up keyboard monitoring for Command-4
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "4" {
                self?.handleInsertVariable()
                return nil
            }
            return event
        }

        self.view = scrollView
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.textView)
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc private func handleInsertVariable() {
        print("Insert variable requested")
        onInsertVariable()
    }

    func updateText(_ newText: String) {
        print("updateText: \(newText)")
        guard storage.string != newText else { return }
        isInternalChange = true
        let selectedRanges = textView.selectedRanges
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: newText)

        // Ensure text color is maintained
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.textColor,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ]
        storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))

        textView.selectedRanges = selectedRanges
        isInternalChange = false
    }
}

extension VariableTextViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        print("textDidChange notification")
        guard !isInternalChange else { return }
        if storage.string != textView.string {
            onTextChange(textView.string)
        }
    }

    public func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView,
              let string = textView.textStorage?.string else {
            return
        }

        if let nsRange = textView.selectedRanges.first as? NSRange,
           let range = Range(nsRange, in: string),
           let oldNSRange = notification.userInfo?["NSOldSelectedCharacterRange"] as? NSRange,
           let oldRange = Range(oldNSRange, in: string) {
            if let varRange = storage.rangeForVariable(at: nsRange.location) {
                // we are in a variable
                // if we just moved from left to right, jump to end of token.  else jump to beginning

                if nsRange.location == varRange.location {
                    // We are at the start of the variable's range -- to the left of its first character
                    // We don't need to do anything in this case
                } else {
                    // We are inside the variable placeholder text -- figure out how we got here..
                    if oldNSRange.location < nsRange.location {
                        // Moving left to right - jump to end of varRange
                        textView.setSelectedRange(NSRange(location: varRange.upperBound, length: 0), affinity: .downstream, stillSelecting: false)
                    } else {
                        // Moving right to left or maybe up or down a row or something - jump to beginning
                        textView.setSelectedRange(NSRange(location: varRange.lowerBound, length: 0), affinity: .upstream, stillSelecting: true)
                    }
                }
            }
            print("*** RANGE: \(oldRange.lowerBound.utf16Offset(in: string)) - \(oldRange.upperBound.utf16Offset(in: string)) ---> \(range.lowerBound.utf16Offset(in: string)) - \(range.upperBound.utf16Offset(in: string))")
//            print(range.lowerBound, range.upperBound)
            // If we're 
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        print("textView clickedOnLInk at charIndex \(charIndex)")
        if let variable = storage.variableAt(charIndex) {
            print("Clicked variable: \(variable.name)")
            return true
        }
        return false
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        print("textView shouldChangeTextIn \(affectedCharRange), replacementString: \(replacementString ?? "<nil>")")
        // If we're deleting and there's a variable at this location
        if replacementString?.isEmpty == true, let varRange = storage.rangeForVariable(at: affectedCharRange.location) {
            // Delete the entire variable
            print("Deleting a variable")
//            textView.replaceCharacters(in: varRange, with: "")
//            textView.shouldChangeText(in: varRange, replacementString: "")
            storage.replaceCharacters(in: varRange, with: "")
            return false
        }
        return true
    }
}

struct VariableTextView: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var storage: VariableTextStorage
    let onInsertVariable: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let controller = VariableTextViewController(
            text: text,
            storage: storage,
            onTextChange: { newText in
                text = newText
            },
            onInsertVariable: onInsertVariable
        )
        controller.loadView()
        context.coordinator.controller = controller
        return controller.view as! NSScrollView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
//        if storage.string != text {
//            context.coordinator.controller?.updateText(text)
//        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: ()) {
        (nsView.documentView as? NSTextView)?.delegate = nil
    }

    class Coordinator {
        var controller: VariableTextViewController?
    }
}

struct VariableTextViewWithButton: View {
    @Binding var text: String
    let storage: VariableTextStorage
    let onInsertVariable: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VariableTextView(text: $text, storage: storage, onInsertVariable: onInsertVariable)
            Button(action: onInsertVariable) {
                Label("Insert Variable", systemImage: "plus.square")
            }
            .controlSize(.small)
        }
    }
} 
