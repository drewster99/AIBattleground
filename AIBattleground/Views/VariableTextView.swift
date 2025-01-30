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

        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        self.textView = textView
        self.scrollView = scrollView
        storage.addLayoutManager(textView.layoutManager!)
        textView.string = storage.string

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.focusRingType = .none
        scrollView.hasVerticalRuler = false
        scrollView.hasHorizontalRuler = false

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
        textView.drawsBackground = true
        textView.insertionPointColor = NSColor.systemOrange
        
        // Configure selection behavior
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor
//            .foregroundColor: NSColor.selectedTextColor
        ]

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

        self.view = scrollView
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.textView)
        }
        // Set up keyboard monitoring for Command-4
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "4" {
                self?.handleInsertVariable()
                return nil
            }
            return event
        }

    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
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

        print(">>>> textViewDidChangeSelection: CURRENT: \(textView.selectedRanges), OLD: \(notification.userInfo?["NSOldSelectedCharacterRanges"] ?? "N/A")")
        if let nsRange = textView.selectedRanges.first as? NSRange,
           let range = Range(nsRange, in: string),
           let oldNSRange = notification.userInfo?["NSOldSelectedCharacterRange"] as? NSRange,
           let oldRange = Range(oldNSRange, in: string) {
            
            // First check for cursor movement (no selection)
            if nsRange.length == 0 {
                print(">>>> MOVING")
                if let varRange = storage.rangeForVariable(at: nsRange.location) {
                    if nsRange.location == varRange.location {
                        // At start of variable - leave it alone
                        return
                    }
                    // Inside variable - jump to appropriate edge
                    if oldNSRange.location < nsRange.location {
                        // moving to the right - jump over the variable
                        textView.setSelectedRange(NSRange(location: varRange.upperBound, length: 0), 
                            affinity: .downstream, stillSelecting: false)
                    } else {
                        // moving to the left or some other direction
                        textView.setSelectedRange(NSRange(location: varRange.lowerBound, length: 0), 
                            affinity: .upstream, stillSelecting: false)
                    }
                }
                return
            }
            
            // Handle selection/deselection
            for (varRange, _) in storage.variables {
                if NSIntersectionRange(nsRange, varRange).length > 0 {
                    // We have some overlap with a variable
                    let isDeselectingFromRight = (nsRange.length < oldNSRange.length) && (nsRange.location == oldNSRange.location)
                    let isDeselectingFromLeft = (nsRange.length < oldNSRange.length) && (nsRange.location > oldNSRange.location)
                    let isDeselecting = isDeselectingFromLeft || isDeselectingFromRight
                    
                    if isDeselecting {
                        print(">>>> DE-SELECTING")
                        // If variable is only partially selected, remove it from selection entirely
                        if NSIntersectionRange(nsRange, varRange).length < varRange.length {
                            // Create new selection that excludes this variable
                            if isDeselectingFromRight {
                                // Deselecting from right, keep everything before the variable
                                textView.setSelectedRange(NSRange(location: nsRange.location, length: varRange.location - nsRange.location),
                                    affinity: .downstream, stillSelecting: true)
                            } else {
                                // Deselecting from left, keep everything after the variable
                                let endOfVar = varRange.location + varRange.length
                                textView.setSelectedRange(NSRange(location: endOfVar, 
                                                               length: (nsRange.location + nsRange.length) - endOfVar),
                                    affinity: .downstream, stillSelecting: true)
                            }
                            return
                        }
                    }
                    
                    // Selection - extend to include whole variable if intersecting
                    let newStart = min(nsRange.location, varRange.location)
                    let newEnd = max(nsRange.location + nsRange.length, varRange.location + varRange.length)
                    let newRange = NSRange(location: newStart, length: newEnd - newStart)
                    if newRange != nsRange {
                        print(">>>> SELECTING VARIABLE (newRange = \(newRange)")
                        textView.setSelectedRange(newRange)
                    }
                    break
                }
            }
            
            print("*** RANGE: \(oldRange.lowerBound.utf16Offset(in: string)) - \(oldRange.upperBound.utf16Offset(in: string)) ---> \(range.lowerBound.utf16Offset(in: string)) - \(range.upperBound.utf16Offset(in: string))")
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
