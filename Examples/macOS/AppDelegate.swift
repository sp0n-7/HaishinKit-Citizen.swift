import Cocoa
import HaishinKit194
import Logboard

let logger = LBLogger.with("com.haishinkit.Exsample.macOS")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        LBLogger.with(kHaishinKit194Identifier).level = .info
    }
}
