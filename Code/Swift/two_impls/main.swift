// Combined program. It links both Plain and Fancy, i.e. two conformances of
// Double to IPrintable in one process. Swift does not support this: protocol
// conformance is global, and which of the duplicates is used is unspecified.
// Everything printed here is an observation of an unsupported program.
import FancyClient
import PlainClient
import Printable

let y: Double = 4.9

// Each client module was compiled against exactly one provider.
print("PlainClient, concrete call: ", terminator: "")
printPlain(y)
print("FancyClient, concrete call: ", terminator: "")
printFancy(y)
print("PlainClient, generic call:  ", terminator: "")
showPlain(y)
print("FancyClient, generic call:  ", terminator: "")
showFancy(y)

// Run-time lookup of the conformance Double: IPrintable. This file names
// neither provider.
print("main, dynamic cast:         ", terminator: "")
if let p = (y as Any) as? any IPrintable {
    p.output()
} else {
    print("no conformance found")
}
