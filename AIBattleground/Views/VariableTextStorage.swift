import AppKit

class VariableTextStorage: NSTextStorage, ObservableObject {
    @Published private(set) var variables: [(NSRange, PromptVariable)] = []
    private var storage = NSMutableAttributedString()
    private var variableUpdateHandler: (([VariableReplacement]) -> Void)?
    
    // MARK: - NSTextStorage Required Overrides
    
    override var string: String {
        return storage.string
    }
    
    override var length: Int {
        return storage.length
    }
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return storage.attributes(at: location, effectiveRange: range)
    }
    
    override func replaceCharacters(in range: NSRange, with str: String) {
        print("Replacing range \(range) with text of length \(str.count)")
        beginEditing()
        storage.replaceCharacters(in: range, with: str)
        updateVariableRanges(oldRange: range, replacementLength: str.count)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }
    
    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        beginEditing()
        storage.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
    
    // MARK: - Variable Handling
    
    func setVariableUpdateHandler(_ handler: @escaping ([VariableReplacement]) -> Void) {
        variableUpdateHandler = handler
    }
    
    func insertVariable(_ variable: PromptVariable, at location: Int) {
        print("Inserting variable at location \(location)")
        let marker = "${\(variable.name)}"
        let range = NSRange(location: location, length: marker.count)
        
        beginEditing()
        
        // Insert the variable text
        storage.replaceCharacters(in: NSRange(location: location, length: 0), with: marker)
        
        // Apply variable styling
        let attributes: [NSAttributedString.Key: Any] = [
            .backgroundColor: NSColor.systemBlue.withAlphaComponent(0.2),
            .foregroundColor: NSColor.systemBlue,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium),
            .variableIdentifier: variable.id
        ]
        storage.setAttributes(attributes, range: range)
        
        // Track the variable
        variables.append((range, variable))
        variables.sort { $0.0.location < $1.0.location }
        
        edited(.editedCharacters, range: range, changeInLength: marker.count)
        endEditing()
        
        notifyVariableUpdate()
        print("Current text after variable insertion: '\(string)'")
    }
    
    private func updateVariableRanges(oldRange: NSRange, replacementLength: Int) {
        let delta = replacementLength - oldRange.length
        guard delta != 0 else { return }
        
        print("Updating variable ranges, delta: \(delta)")
        
        // Remove any variables that were completely within the deleted range
        variables = variables.filter { varRange, _ in
            let keep = NSIntersectionRange(oldRange, varRange).length < varRange.length
            if !keep {
                print("Removing variable at range \(varRange)")
            }
            return keep
        }
        
        // Update ranges of remaining variables
        for i in 0..<variables.count {
            let (range, variable) = variables[i]
            if range.location >= oldRange.location + oldRange.length {
                // Variable was after the edit, shift its position
                let newRange = NSRange(location: range.location + delta, length: range.length)
                print("Shifting variable from \(range) to \(newRange)")
                variables[i] = (newRange, variable)
            }
        }
        
        notifyVariableUpdate()
    }
    
    private func notifyVariableUpdate() {
        let replacements = variables.map { range, variable in
            VariableReplacement(id: UUID(), variable: variable, insertionPoint: range.location)
        }
        variableUpdateHandler?(replacements)
    }
    
    func variableAt(_ location: Int) -> PromptVariable? {
        for (range, variable) in variables {
            if NSLocationInRange(location, range) {
                return variable
            }
        }
        return nil
    }
    
    func rangeForVariable(at location: Int) -> NSRange? {
        for (range, _) in variables {
            if NSLocationInRange(location, range) {
                return range
            }
        }
        return nil
    }
}

// MARK: - Custom Attribute Keys

extension NSAttributedString.Key {
    static let variableIdentifier = NSAttributedString.Key("variableIdentifier")
} 