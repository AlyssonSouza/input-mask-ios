//
// Project «InputMask»
// Created by Jeorge Taflanidi
//


import Foundation


/**
 ### Mask
 
 Iterates over user input. Creates formatted strings from it. Extracts value specified by mask format.
 
 Provided mask format string is translated by the ```Compiler``` class into a set of states, which define the formatting
 and value extraction.
 
 - seealso: ```Compiler```, ```State``` and ```CaretString``` classes.
 */
public class Mask: CustomDebugStringConvertible, CustomStringConvertible {
    
    /**
     ### Result
     
     The end result of mask application to the user input string.
     */
    public struct Result: CustomDebugStringConvertible, CustomStringConvertible {
        
        /**
         Formatted text with updated caret position.
         */
        public let formattedText: CaretString
        
        /**
         Value, extracted from formatted text according to mask format.
         */
        public let extractedValue: String
        
        /**
         Calculated absolute affinity value between the mask format and input text.
         */
        public let affinity: Int
        
        /**
         User input is complete.
         */
        public let complete: Bool
        
        public var debugDescription: String {
            get {
                return "FORMATTED TEXT: \(self.formattedText)\nEXTRACTED VALUE: \(self.extractedValue)\nAFFINITY: \(self.affinity)\nCOMPLETE: \(self.complete)"
            }
        }
        
        public var description: String {
            get {
                return self.debugDescription
            }
        }
    }
    
    private let initialState: State
    private static var cache: [String : Mask] = [:]
    
    /**
     Constructor.
     
     - parameter format: mask format.
     
     - returns: Initialized ```Mask``` instance.
     
     - throws: ```CompilerError``` if format string is incorrect.
     */
    public required init(format: String) throws {
        self.initialState = try Compiler().compile(formatString: format)
    }
    
    /**
     Constructor.
     
     Operates over own ```Mask``` cache where initialized ```Mask``` objects are stored under corresponding format key:
     ```[format : mask]```
     
     - returns: Previously cached ```Mask``` object for requested format string. If such it doesn't exist in cache, the
     object is constructed, cached and returned.
     */
    public static func getOrCreate(withFormat format: String) throws -> Mask {
        if let cachedMask: Mask = cache[format] {
            return cachedMask
        } else {
            let mask: Mask = try Mask(format: format)
            cache[format] = mask
            return mask
        }
    }
    
    /**
     Apply mask to the user input string.
     
     - parameter toText: user input string with current cursor position
     
     - returns: Formatted text with extracted value an adjusted cursor position.
     */
    public func apply(toText text: CaretString, autocomplete: Bool = false) -> Result {
        let iterator: CaretStringIterator = CaretStringIterator(caretString: text)
        
        var affinity:               Int     = 0
        var extractedValue:         String  = ""
        var modifiedString:         String  = ""
        var modifiedCaretPosition:  Int     =
            text.string.distance(from: text.string.startIndex, to: text.caretPosition) 
        
        var state:       State      = self.initialState
        var beforeCaret: Bool       = iterator.beforeCaret()
        var character:   Character? = iterator.next()
        
        while let char: Character = character {
            if let next: Next = state.accept(character: char) {
                state = next.state
                modifiedString += nil != next.insert ? String(next.insert!) : ""
                extractedValue += nil != next.value  ? String(next.value!)  : ""
                if next.pass {
                    beforeCaret = iterator.beforeCaret()
                    character   = iterator.next()
                    affinity   += 1
                } else {
                    if beforeCaret && nil != next.insert {
                        modifiedCaretPosition += 1
                    }
                    affinity -= 1
                }
            } else {
                if iterator.beforeCaret() {
                    modifiedCaretPosition -= 1
                }
                beforeCaret = iterator.beforeCaret()
                character   = iterator.next()
                affinity   -= 1
            }
        }
        
        while autocomplete && beforeCaret, let next: Next = state.autocomplete() {
            state = next.state
            modifiedString += nil != next.insert ? String(next.insert!) : ""
            extractedValue += nil != next.value  ? String(next.value!)  : ""
            if nil != next.insert {
                modifiedCaretPosition += 1
            }
        }
        
        return Result(
            formattedText: CaretString(
                string: modifiedString,
                caretPosition: modifiedString.index(modifiedString.startIndex, offsetBy: modifiedCaretPosition)
            ),
            extractedValue: extractedValue,
            affinity: affinity,
            complete: self.noMandatoryCharactersLeftAfterState(state)
        )
    }
    
    /**
     Generate placeholder.
     
     - returns: Placeholder string.
     */
    public var placeholder: String {
        return self.appendPlaceholder(withState: self.initialState, placeholder: "")
    }
    
    /**
     Minimal length of the text inside the field to fill all mandatory characters in the mask.
     
     - returns: Minimal satisfying count of characters inside the text field.
     */
    public var acceptableTextLength: Int {
        return self.countStates(ofTypes: [FixedState.self, FreeState.self, ValueState.self])
    }
    
    /**
     Maximal length of the text inside the field.
     
     - returns: Total available count of mandatory and optional characters inside the text field.
     */
    public var totalTextLength: Int {
        return self.countStates(ofTypes: [FixedState.self, FreeState.self, ValueState.self, OptionalValueState.self])
    }
    
    /**
     Minimal length of the extracted value with all mandatory characters filled.
     
     - returns: Minimal satisfying count of characters in extracted value.
     */
    public var acceptableValueLength: Int {
        var state: State? = self.initialState
        var length: Int = 0
        while let s: State = state, !(state is EOLState) {
            if s is FixedState || s is ValueState {
                length += 1
            }
            state = s.child
        }
        
        return length
    }
    
    /**
     Maximal length of the extracted value.
     
     - returns: Total available count of mandatory and optional characters for extracted value.
     */
    public var totalValueLength: Int {
        var state: State? = self.initialState
        var length: Int = 0
        while let s: State = state, !(state is EOLState) {
            if s is FixedState || s is ValueState || s is OptionalValueState {
                length += 1
            }
            state = s.child
        }
        
        return length
    }
    
    public var debugDescription: String {
        get {
            return self.initialState.debugDescription
        }
    }
    
    public var description: String {
        get {
            return self.debugDescription
        }
    }
    
}


private extension Mask {
    
    func appendPlaceholder(withState state: State?, placeholder: String) -> String {
        guard let state: State = state
        else { return placeholder }
        
        if state is EOLState {
            return placeholder
        }
        
        if let state = state as? FixedState {
            return self.appendPlaceholder(withState: state.child, placeholder: placeholder + String(state.ownCharacter))
        }
        
        if let state = state as? FreeState {
            return self.appendPlaceholder(withState: state.child, placeholder: placeholder + String(state.ownCharacter))
        }
        
        if let state = state as? OptionalValueState {
            switch state.type {
                case .AlphaNumeric:
                    return self.appendPlaceholder(withState: state.child, placeholder: placeholder + "-")
                
                case .Literal:
                    return self.appendPlaceholder(withState: state.child, placeholder: placeholder + "a")
                
                case .Numeric:
                    return self.appendPlaceholder(withState: state.child, placeholder: placeholder + "0")
            }
        }
        
        if let state = state as? ValueState {
            switch state.type {
                case .alphaNumeric:
                    return self.appendPlaceholder(withState: state.child, placeholder: placeholder + "-")
                    
                case .literal:
                    return self.appendPlaceholder(withState: state.child, placeholder: placeholder + "a")
                    
                case .numeric:
                    return self.appendPlaceholder(withState: state.child, placeholder: placeholder + "0")
                
                case .ellipsis:
                    return placeholder
            }
        }
        
        return placeholder
    }
    
    func noMandatoryCharactersLeftAfterState(_ state: State) -> Bool {
        if (state is EOLState) {
            return true
        } else if let valueState = state as? ValueState {
            return valueState.isElliptical
        } else if (state is FixedState || state is FreeState) {
            return false
        } else {
            return self.noMandatoryCharactersLeftAfterState(state.nextState())
        }
    }
        
    func countStates(ofTypes stateTypes: [State.Type]) -> Int {
        var state: State? = self.initialState
        var length: Int = 0
        while let s: State = state, !(state is EOLState) {
            for stateType in stateTypes {
                if type(of: s) == stateType {
                    length += 1
                }
            }
            state = s.child
        }
        
        return length
    }
    
}
