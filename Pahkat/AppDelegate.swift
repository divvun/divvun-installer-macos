import Cocoa
import RxSwift
import Sentry
import XCGLogger

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var instance: AppDelegate!
    private let bag = DisposeBag()
    
    @objc func handleReopenEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventManager) {
        if let window = NSApp.windows.filter({ $0.isVisible }).first {
            window.windowController?.showWindow(self)
        } else {
            AppContext.windows.show(MainWindowController.self)
        }
    }
    
    func launchMain() {
        AppContext.windows.show(MainWindowController.self)
        
        log.debug("Setting event handler for core open event")
        
        // Handle event for reopen window because AppDelegate one is never called…
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleReopenEvent(_:withReplyEvent:)),
            forEventClass: kCoreEventClass,
            andEventID: kAEReopenApplication)
    }
    
    private func configureLogging() {
        log.setup(level: .debug, showThreadName: true, showLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: "/tmp/divvun-installer.log", fileLevel: .debug)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureLogging()
        
        // Configure Sentry.io
        do {
            Client.shared = try Client(dsn: "https://554b508acddd44e98c5b3dc70f8641c1@sentry.io/1357390")
            try Client.shared?.startCrashHandler()
        } catch let error {
            log.severe(error)
            // Wrong DSN or KSCrash not installed
        }
        
        AppDelegate.instance = self

        AppContext.packageStore.notifications().subscribe(onNext: {
            print($0)
        }).disposed(by: bag)
        
        launchMain()
    }
}
