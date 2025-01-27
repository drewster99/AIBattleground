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
        guard !isInternalChange else { return }
        onTextChange(storage.string)
    }
    
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let variable = storage.variableAt(charIndex) {
            print("Clicked variable: \(variable.name)")
            return true
        }
        return false
    }
    
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        // If we're deleting and there's a variable at this location
        if replacementString?.isEmpty == true, let varRange = storage.rangeForVariable(at: affectedCharRange.location) {
            // Delete the entire variable
            textView.shouldChangeText(in: varRange, replacementString: "")
            storage.replaceCharacters(in: varRange, with: "")
            return false
        }
        return true
    }
}

struct VariableTextView: NSViewRepresentable {
    @Binding var text: String
    let storage: VariableTextStorage
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
        if storage.string != text {
            context.coordinator.controller?.updateText(text)
        }
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