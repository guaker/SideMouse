import Foundation
import Darwin

typealias MainConnection = @convention(c) () -> UInt32
typealias CopySpaces = @convention(c) (UInt32) -> Unmanaged<CFArray>?
typealias SetSpace = @convention(c) (UInt32, CFString, CFDictionary) -> Int32

let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
guard let handle,
      let mainSym = dlsym(handle, "CGSMainConnectionID"),
      let copySym = dlsym(handle, "CGSCopyManagedDisplaySpaces"),
      let setSym = dlsym(handle, "CGSManagedDisplaySetCurrentSpace") else { fatalError("no SkyLight") }
let main = unsafeBitCast(mainSym, to: MainConnection.self)
let copy = unsafeBitCast(copySym, to: CopySpaces.self)
let set = unsafeBitCast(setSym, to: SetSpace.self)
let c = main()
guard let unmanaged = copy(c) else { fatalError("no spaces") }
let displays = unmanaged.takeRetainedValue() as! [[String: Any]]
for d in displays {
    print(d.keys)
    print(d)
}
let d = displays[0]
let display = d["Display Identifier"] as! String as CFString
let spaces = d["Spaces"] as! [[String: Any]]
let currentID = (d["Current Space"] as! [String: Any])["ManagedSpaceID"] as! Int
if let index = spaces.firstIndex(where: { ($0["ManagedSpaceID"] as? Int) == currentID }) {
    let next = spaces[(index + 1) % spaces.count] as NSDictionary
    let result = set(c, display, next)
    let nextID = next["ManagedSpaceID"] ?? -1
    print("switched from \(currentID) to \(nextID), result=\(result)")
}
