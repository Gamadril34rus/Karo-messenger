import FlutterMacOSAppDelegate
import Cocoa

@NSApplicationMain
class AppDelegate: FlutterMacOSAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
