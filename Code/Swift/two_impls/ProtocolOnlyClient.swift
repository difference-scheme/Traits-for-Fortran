// EXPECTED TO FAIL TO COMPILE (checked by run.sh):
//   error: value of type 'Double' has no member 'output'
//
// This client imports only the protocol module. run.sh compiles it with
// Plain.swiftmodule on the module search path (-I) and links Plain.o, yet
// Plain's extension of Double stays invisible: neither this file's imports nor
// their dependencies include module Plain.
import Printable

let y: Double = 4.9
y.output()
