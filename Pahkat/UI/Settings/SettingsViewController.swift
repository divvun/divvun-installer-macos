//
//  SettingsViewController.swift
//  Pahkat
//
//  Created by Anton Malmquist on 2018-02-23.
//  Copyright © 2018 Divvun. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

extension Repository.Channels {
    var description: String {
        switch self {
        case .alpha:
            return "Alpha" //Strings.alpha
        case .beta:
            return "Beta" //Strings.beta
        case .nightly:
            return "Nightly" //Strings.nightly
        case .stable:
            return "Stable" // Strings.stable
        }
    }
}

struct RepositoryTableRowData {
    let name: String
    let url: URL
    let channel: Repository.Channels
}

class SettingsViewController: DisposableViewController<SettingsView>, SettingsViewable {
    private(set) var tableDelegate: RepositoryTableDelegate! = nil
    private lazy var presenter = { SettingsPresenter(view: self) }()
    
    var onAddRepoButtonTapped: Driver<Void> {
        return contentView.repoAddButton.rx.tap.asDriver()
    }
    
    var onRemoveRepoButtonTapped: Driver<Void> {
        return contentView.repoRemoveButton.rx.tap.asDriver()
    }
    
    func addBlankRepositoryRow() {
        let rows = self.contentView.repoTableView.numberOfRows
        self.contentView.repoTableView.beginUpdates()
        self.contentView.repoTableView.insertRows(at: IndexSet(integer: rows), withAnimation: .effectFade)
        self.contentView.repoTableView.endUpdates()
        self.contentView.repoTableView.selectRowIndexes(IndexSet(integer: rows), byExtendingSelection: false)
    }
    
    func promptRemoveRepositoryRow() {
        let row = self.contentView.repoTableView.selectedRow
        if row < 0 {
            return
        }
        let alert = NSAlert()
        alert.messageText = "Gonna delete?"
        alert.informativeText = "It will be delete."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Pls no")
        alert.beginSheetModal(for: self.contentView.window!, completionHandler: {
            if $0 == NSApplication.ModalResponse.alertFirstButtonReturn {
                self.contentView.repoTableView.beginUpdates()
                self.contentView.repoTableView.removeRows(at: IndexSet(integer: row), withAnimation: .effectFade)
                self.contentView.repoTableView.endUpdates()
            }
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = Strings.settings
        
        UpdateFrequency.bind(to: contentView.frequencyPopUp.menu!)
        Repository.Channels.bind(to: contentView.repoChannelColumn.menu!)
        
        contentView.repoAddButton.rx.tap.subscribe(onNext: { [weak self] in
            guard let `self` = self else { return }
            self.addBlankRepositoryRow()
        }).disposed(by: bag)
        
        contentView.repoRemoveButton.rx.tap.subscribe(onNext: { [weak self] in
            guard let `self` = self else { return }
            self.promptRemoveRepositoryRow()
        }).disposed(by: bag)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        presenter.start().disposed(by: bag)
    }
    
    func setRepositories(repositories: [RepositoryTableRowData]) {
        self.tableDelegate = RepositoryTableDelegate(with: repositories)
        contentView.repoTableView.delegate = self.tableDelegate
        contentView.repoTableView.dataSource = self.tableDelegate
    }
}

enum RepositoryTableColumns: String {
    case url
    case name
    case channel
    
    init?(identifier: NSUserInterfaceItemIdentifier) {
        if let value = RepositoryTableColumns(rawValue: identifier.rawValue) {
            self = value
        } else {
            return nil
        }
    }
}

class RepositoryTableDelegate: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    private var configs: [RepositoryTableRowData]
    
    init(with configs: [RepositoryTableRowData]) {
        self.configs = configs
        super.init()
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let tableColumn = tableColumn else { return nil }
        guard let column = RepositoryTableColumns(identifier: tableColumn.identifier) else { return nil }
        
        if row >= configs.count {
            return nil
        }
        
        let config = configs[row]
        
        switch column {
        case .url:
            return config.url.absoluteString
        case .name:
            return config.name
        case .channel:
            guard let cell = tableColumn.dataCell as? NSPopUpButtonCell else { return nil }
            guard let index = cell.menu?.items.index(where: { $0.representedObject as! Repository.Channels == config.channel }) else { return nil }
            return index
        }
    }
    
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard let tableColumn = tableColumn else { return }
        guard let column = RepositoryTableColumns(identifier: tableColumn.identifier) else { return }
        
        if row >= configs.count {
            return
        }
        
        switch column {
        case .url:
            break
        case .name:
            break
        case .channel:
            guard let cell = tableColumn.dataCell as? NSPopUpButtonCell else { return }
            guard let index = object as? Int else { return }
            guard let menuItem = cell.menu?.item(at: index) else { return }
            guard let channel = menuItem.representedObject as? Repository.Channels else { return }
            
            // Required or UI does a weird blinking thing.
            self.configs[row] = RepositoryTableRowData(name: configs[row].name, url: configs[row].url, channel: channel)
            
            AppContext.settings.dispatch(event: SettingsEvent.updateRepoConfig(configs[row].url, channel))
            break
        }
    }
    
//    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
//        guard let tableColumn = tableColumn else { return nil }
//        guard let column = RepositoryTableColumns(identifier: tableColumn.identifier) else { return nil }
//
//        let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as! NSTableCellView
//        let config = configs[row]
//
//        switch column {
//        case .url:
//            cell.textField?.isEditable = true
//            cell.textField?.stringValue = config.0.url.absoluteString
//        case .name:
//            cell.textField?.isEditable = false
//            cell.textField?.stringValue = config.1 ?? Strings.loading
//        case .channel:
//            cell.textField?.isEditable = true
//            cell.textField?.stringValue = config.0.channel
//        }
//
//        return cell
//    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.configs.count
    }
    
}


fileprivate extension UpdateFrequency {
    private static func createMenuItem(_ thingo: UpdateFrequency) -> NSMenuItem {
        return NSMenuItem(title: thingo.description, value: thingo)
    }
    
    static func asMenuItems() -> [NSMenuItem] {
        return [
            UpdateFrequency.createMenuItem(.daily),
            UpdateFrequency.createMenuItem(.weekly),
            UpdateFrequency.createMenuItem(.fortnightly),
            UpdateFrequency.createMenuItem(.monthly),
            UpdateFrequency.createMenuItem(.never)
        ]
    }
    
    static func bind(to menu: NSMenu) {
        self.asMenuItems().forEach(menu.addItem(_:))
    }
}

fileprivate extension Repository.Channels {
    private static func createMenuItem(_ thingo: Repository.Channels) -> NSMenuItem {
        return NSMenuItem(title: thingo.description, value: thingo)
    }
    
    static func asMenuItems() -> [NSMenuItem] {
        return [
            createMenuItem(.stable),
            createMenuItem(.alpha),
            createMenuItem(.beta),
            createMenuItem(.nightly),
        ]
    }
    
    static func bind(to menu: NSMenu) {
        self.asMenuItems().forEach(menu.addItem(_:))
    }
}

