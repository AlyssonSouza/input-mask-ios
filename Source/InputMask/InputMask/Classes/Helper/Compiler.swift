//
// Project «InputMask»
// Created by Jeorge Taflanidi
//


import Foundation


/**
 ### Compiler
 
 Creates a sequence of states from the mask format string.
 
 - seealso: ```State``` class.
 
 - complexity: ```O(formatString.count)``` plus ```FormatSanitizer``` complexity.
 
 - requires: Format string to contain only flat groups of symbols in ```[]``` and ```{}``` brackets without nested
 brackets, like ```[[000]99]```. Also, ```[]``` groups may contain only the specified characters ("0", "9", "A", "a",
 "_", "-" and "…"). Square bracket ```[]``` groups cannot contain mixed types of symbols ("0" and "9" with "A" and "a"
 or "_" and "-").

 ```Compiler``` object is initialized and ```Compiler.compile(formatString:)``` is called during the ```Mask``` instance
 initialization.
 
 ```Compiler``` uses ```FormatSanitizer``` to prepare ```formatString``` for the compilation.
 */
public class Compiler {
    
    /**
     ### CompilerError
     
     Compiler error exception type, thrown when ```formatString``` contains inappropriate character sequences.
     
     ```CompilerError``` is used by the ```Compiler``` and ```FormatSanitizer``` classes.
     */
    public enum CompilerError: Error {
        case wrongFormat
    }
    
    /**
     Compile ```formatString``` into the sequence of states.
     
     * "Free" characters from ```formatString``` are converted to ```FreeState```-s.
     * Characters in square brackets are converted to ```ValueState```-s and ```OptionalValueState```-s.
     * Characters in curly brackets are converted to ```FixedState```-s.
     * End of the formatString line makes ```EOLState```.
     
     For instance,
     ```
     [09]{.}[09]{.}19[00]
     ```
     is converted to sequence:
     ```
     0. ValueState.numeric          [0]
     1. OptionalValueState.Numeric  [9]
     2. FixedState                  {.}
     3. ValueState.numeric          [0]
     4. OptionalValueState.Numeric  [9]
     5. FixedState                  {.}
     6. FreeState                    1
     7. FreeState                    9
     8. ValueState.numeric          [0]
     9. ValueState.numeric          [0]
     ```
     
     - parameter formatString: string with a mask format.
     
     - seealso: ```State``` class.
     
     - complexity: ```O(formatString.count)``` plus ```FormatSanitizer``` complexity.
     
     - requires: Format string to contain only flat groups of symbols in ```[]``` and ```{}``` brackets without nested
     brackets, like ```[[000]99]```. Also, ```[]``` groups may contain only the specified characters ("0", "9", "A", "a",
     "_", "-" and "…").
     
     - returns: Initialized ```State``` object with assigned ```State.child``` chain.
     
     - throws: ```CompilerError``` if ```formatString``` does not conform to the method requirements.
     */
    func compile(formatString string: String) throws -> State {
        let sanitizedFormat: String = try FormatSanitizer().sanitize(formatString: string)
        
        return try self.compile(
            sanitizedFormat,
            valueable: false,
            fixed: false,
            lastCharacter: nil
        )
    }
    
}

private extension Compiler {
    
    func compile(
        _ string: String,
        valueable: Bool,
        fixed: Bool,
        lastCharacter: Character?
    ) throws -> State {
        guard
            let char: Character = string.first
        else {
            return EOLState()
        }
        
        switch char {
            case "[":
                if "\\" == lastCharacter { // escaped [
                    break
                }
                return try self.compile(
                    string.truncateFirst(),
                    valueable: true,
                    fixed: false,
                    lastCharacter: char
                )
            
            case "{":
                if "\\" == lastCharacter { // escaped {
                    break
                }
                return try self.compile(
                    string.truncateFirst(),
                    valueable: false,
                    fixed: true,
                    lastCharacter: char
                )
            
            case "]":
                if "\\" == lastCharacter { // escaped ]
                    break
                }
                return try self.compile(
                    string.truncateFirst(),
                    valueable: false,
                    fixed: false,
                    lastCharacter: char
                )
            
            case "}":
                if "\\" == lastCharacter { // escaped }
                    break
                }
                return try self.compile(
                    string.truncateFirst(),
                    valueable: false,
                    fixed: false,
                    lastCharacter: char
                )
            
            case "\\": // the escapting character
                if "\\" == lastCharacter { // escaped «\» character
                    break
                }
                return try self.compile(
                    string.truncateFirst(),
                    valueable: valueable,
                    fixed: fixed,
                    lastCharacter: char
                )
            
            default: break
        }
        
        if valueable {
            return try compileValueable(char, string: string, lastCharacter: lastCharacter)
        }
        
        if fixed {
            return FixedState(
                child: try self.compile(
                    string.truncateFirst(),
                    valueable: false,
                    fixed: true,
                    lastCharacter: char
                ),
                ownCharacter: char
            )
        }
        
        return FreeState(
            child: try self.compile(
                string.truncateFirst(),
                valueable: false,
                fixed: false,
                lastCharacter: char
            ),
            ownCharacter: char
        )
    }
    
    func compileValueable(_ char: Character, string: String, lastCharacter: Character?) throws -> State {
        switch char {
            case "0":
                return ValueState(
                    child: try self.compile(
                        string.truncateFirst(),
                        valueable: true,
                        fixed: false,
                        lastCharacter: char
                    ),
                    type: ValueState.StateType.numeric
                )
            
            case "A":
                return ValueState(
                    child: try self.compile(
                        string.truncateFirst(),
                        valueable: true,
                        fixed: false,
                        lastCharacter: char
                    ),
                    type: ValueState.StateType.literal
                )
            
            case "_":
                return ValueState(
                    child: try self.compile(
                        string.truncateFirst(),
                        valueable: true,
                        fixed: false,
                        lastCharacter: char
                    ),
                    type: ValueState.StateType.alphaNumeric
                )
            
            case "…":
                return ValueState(inheritedType: try self.determineInheritedType(forLastCharacter: lastCharacter))
            
            case "9":
                return OptionalValueState(
                    child: try self.compile(
                        string.truncateFirst(),
                        valueable: true,
                        fixed: false,
                        lastCharacter: char
                    ),
                    type: OptionalValueState.StateType.Numeric
                )
            
            case "a":
                return OptionalValueState(
                    child: try self.compile(
                        string.truncateFirst(),
                        valueable: true,
                        fixed: false,
                        lastCharacter: char
                    ),
                    type: OptionalValueState.StateType.Literal
                )
            
            case "-":
                return OptionalValueState(
                    child: try self.compile(
                        string.truncateFirst(),
                        valueable: true,
                        fixed: false,
                        lastCharacter: char
                    ),
                    type: OptionalValueState.StateType.AlphaNumeric
                )
            
            default: throw CompilerError.wrongFormat
        }
    }
    
    func determineInheritedType(forLastCharacter character: Character?) throws -> ValueState.StateType {
        guard
            let character: Character = character,
            String(character) != ""
        else {
            throw CompilerError.wrongFormat
        }
        
        switch character {
            case "0", "9":
                return ValueState.StateType.numeric
            
            case "A", "a":
                return ValueState.StateType.literal
            
            case "_", "-":
                return ValueState.StateType.alphaNumeric
            
            case "…":
                return ValueState.StateType.alphaNumeric
            
            case "[":
                return ValueState.StateType.alphaNumeric
            
            default: throw CompilerError.wrongFormat
        }
    }
    
}
