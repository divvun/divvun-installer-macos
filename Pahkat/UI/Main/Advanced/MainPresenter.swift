//
//  MainPresenter.swift
//  Pahkat
//
//  Created by Brendan Molloy on 2018-02-06.
//  Copyright © 2018 Divvun. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa


typealias PackageOutlineMap = Map<OutlineGroup, SortedSet<OutlinePackage>>
typealias MainOutlineMap = Map<OutlineRepository, PackageOutlineMap>

fileprivate func categoryFilter(outlineRepo: OutlineRepository) -> PackageOutlineMap {
    var data = PackageOutlineMap()
    let repo = outlineRepo.repo

    repo.descriptors.values.forEach { (descriptor: Descriptor) in
        let release = descriptor.release.lastItem // TODO: ensure this is actually the latest release
//        let target = release.target[0]! // TODO: also probably wrong
        guard let target = release.macosTarget else {
            // this package doesn't have a macos target
            return
        }

        let categoryId = descriptor.tags.first(where: { $0.starts(with: "cat:") }) ?? "cat:unknown"
        let category = categoryId // TODO: make native, human readable
        let key = OutlineGroup(id: categoryId, value: category, repo: outlineRepo)

        if !data.keys.contains(key) {
            data[key] = []
        }

        let outlinePackage = OutlinePackage(package: descriptor,
                                            release: release,
                                            target: target,
                                            status: (PackageStatus.notInstalled, SystemTarget.user), // TODO: get this from reality
                                            group: key,
                                            repo: outlineRepo,
                                            selection: nil)
        data[key]!.insert(outlinePackage)
    }

    return data
//    todo()
}

fileprivate func languageFilter(outlineRepo: OutlineRepository) -> PackageOutlineMap {
//    var data = PackageOutlineMap()
//    let repo = outlineRepo.repo
//
//    repo.packages.values.forEach { package in
//        package.languages.forEach { language in
//            let value: String
//            if language == "zxx" {
//                value = "—"
//            } else {
//                value = ISO639.get(tag: language)?.autonymOrName ?? language
//            }
//
//            let key = OutlineGroup(id: language, value: value, repo: outlineRepo)
//            if !data.keys.contains(key) {
//                data[key] = []
//            }
//
//            data[key]!.insert(OutlinePackage(package: package, group: key, repo: outlineRepo, selection: nil))
//        }
//    }
//
//    return data
    todo()
}

class MainPresenter {
    private let bag = DisposeBag()
    private unowned let view: MainViewable
    private var data: MainOutlineMap = Map()
    private var selectedPackages = [PackageKey: SelectedPackage]()
    
    init(view: MainViewable) {
        self.view = view
    }
    
    private func updateFilters(key: OutlineRepository) {
        switch key.filter {
        case .category:
            data[key] = categoryFilter(outlineRepo: key)
        case .language:
            data[key] = languageFilter(outlineRepo: key)
        }
    }
    
    private func updateData(with repositories: [LoadedRepository]) {
        data = MainOutlineMap()
        
        repositories.forEach { repo in
            print(repo)
            let filter = OutlineFilter.category // TODO: get this from the repo?
            let key = OutlineRepository(filter: filter, repo: repo)
            self.updateFilters(key: key)
        }
    }
    
    private func bindUpdatePackageList() -> Disposable {
        return AppContext.store.state
            .map { $0.repositories }
            .distinctUntilChanged({ (a, b) in a == b })
            .observeOn(MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] repos in
                guard let `self` = self else { return }
                self.updateData(with: repos)
                self.view.updateProgressIndicator(isEnabled: false)
                self.view.setRepositories(data: self.data)

            }, onError: { [weak self] in self?.view.handle(error: $0) })
    }
    
    private func updatePrimaryButton() {
        let packageCount = String(self.selectedPackages.values.count)
        
        let hasInstalls = self.selectedPackages.values.first(where: { $0.isInstalling }) != nil
        let hasUninstalls = self.selectedPackages.values.first(where: { $0.isUninstalling }) != nil
        
        var isEnabled: Bool = true
        let label: String
        
        if hasInstalls && hasUninstalls {
            label = Strings.installUninstallNPackages(count: packageCount)
        } else if hasInstalls {
            label = Strings.installNPackages(count: packageCount)
        } else if hasUninstalls {
            label = Strings.uninstallNPackages(count: packageCount)
        } else {
            isEnabled = false
            label = Strings.noPackagesSelected
        }
        
        self.view.updatePrimaryButton(isEnabled: isEnabled, label: label)
    }
    
    private func bindSettingsButton() -> Disposable {
        return view.onSettingsTapped.drive(onNext: { [weak self] in
            self?.view.showSettings()
        })
    }
    
    private func bindPrimaryButton() -> Disposable {
        return view.onPrimaryButtonPressed.drive(onNext: { [weak self] in
            guard let `self` = self else { return }
            if self.selectedPackages.values.contains(where: { $0.target == .system }) {
                // TODO: something reasonable
//                PahkatAdminReceiver.checkForAdminService().subscribe(onCompleted: {
//                    self.view.showDownloadView(with: self.selectedPackages)
//                }, onError: { error in
//                    self.view.handle(error: error)
//                }).disposed(by: self.bag)
            } else {
                self.view.showDownloadView(with: self.selectedPackages)
            }
        })
    }
    
    enum PackageStateOption {
        case toggle
        case set(SelectedPackage?)
    }
    
    private func setPackageState(to option: PackageStateOption, package: Package, repo: OutlineRepository) {
        guard let packageMap: PackageOutlineMap = self.data[repo] else { return }

        for item in packageMap {
            // TODO: firstRelease may not be what we want
            // TODO: handle non-concrete cases
            guard case let .concrete(descriptor) = package, let installer = descriptor.firstRelease()?.macosTarget else {
                continue
            }

            if let outlinePackage: OutlinePackage = item.1.first(where: { $0.package == descriptor }) /*, let info = repo.repo.status(forPackage: package) */{
                let packageKey = repo.repo.packageKey(for: descriptor)
                switch option {
                case .toggle:
                    if outlinePackage.selection == nil {
                        let (status, target) = outlinePackage.status
                        switch status {
                        case .upToDate:
                            outlinePackage.selection = SelectedPackage(
                                key: packageKey,
                                package: descriptor,
                                action: .uninstall,
                                target: target)
                        default:
//                            let target = installer.targets[0].rawValue == "system" ? InstallerTarget.system : InstallerTarget.user
                            outlinePackage.selection = SelectedPackage(
                                key: packageKey,
                                package: descriptor,
                                action: .install,
                                target: target)
                        }
                    } else {
                        outlinePackage.selection = nil
                    }

                    if let action = outlinePackage.selection {
                        self.selectedPackages[action.key] = action
                    } else {
                        self.selectedPackages[packageKey] = nil
                    }
                case let .set(action):
                    outlinePackage.selection = action
                    if let action = action {

                        self.selectedPackages[action.key] = action
                    }
                }
            }
        }
    }
    
    private func bindUpdatePackagesOnLoad() -> Disposable {
        // Always update the repos on load.
//        return AppContext.settings.state.map { $0.repositories }
//            .observeOn(MainScheduler.instance)
//            .subscribeOn(MainScheduler.instance)
//            .flatMapLatest { [weak self] (configs: [RepoRecord]) -> Observable<[LoadedRepository]> in
//                guard let `self` = self else { return Observable.empty() }
//
//                self.view.updateSettingsButton(isEnabled: false)
//                self.view.updateProgressIndicator(isEnabled: true)
//                try self.client.refreshRepos()
//
//                let repos: [LoadedRepository] = try self.client.repoIndexesWithStatuses()
//
//                if repos.count < configs.count {
//                    var configSet = Set(configs.map { $0.url })
//                    configSet.subtract(Set(repos.map { $0.meta.base }))
//
//                    var failingReposString = ""
//
//                    for failingURL in configSet {
//                        log.debug("Could not load URL \(failingURL)\n")
//                        failingReposString.append(Strings.repositoryErrorBody(message: failingURL.absoluteString))
//                        failingReposString.append("\n\n")
//                    }
//
//                    let alert = NSAlert()
//                    alert.messageText = Strings.repositoryError
//                    alert.informativeText = failingReposString
//                    alert.runModal()
//                }
//
//                return Observable.just(repos)
//            }
//            .subscribe(onNext: { [weak self] repos in
//                log.debug("Refreshed repos in main view.")
//                self?.view.updateSettingsButton(isEnabled: true)
//                AppContext.store.dispatch(event: AppEvent.setRepositories(repos))
//                self?.view.updateProgressIndicator(isEnabled: false)
//            }, onError: { [weak self] error in
//                self?.view.handle(error: error)
//                self?.view.updateSettingsButton(isEnabled: true)
//                self?.view.updateProgressIndicator(isEnabled: false)
//            })
        todo()
    }
    
    private func bindContextMenuEvents() -> Disposable {
//        return view.onPackageEvent
//            .observeOn(MainScheduler.instance)
//            .subscribeOn(MainScheduler.instance)
//            .subscribe(onNext: { [weak self] event in
//            guard let `self` = self else { return }
//
//            switch event {
//            case let .setPackageSelection(action):
//
//                guard let outlineRepo = self.data.keys.first(where: { $0.repo.packages.values.contains(action.package) }) else {
//                    return
//                }
//                self.setPackageState(to: .set(action), package: action.package, repo: outlineRepo)
//                self.updatePrimaryButton()
//                self.view.refreshRepositories()
//            case let .changeFilter(repo, filter):
//                repo.filter = filter
//                self.updateFilters(key: repo)
//                for action in self.selectedPackages.values {
//                    self.setPackageState(to: .set(action), package: action.package, repo: repo)
//                }
//                self.view.setRepositories(data: self.data)
//            default:
//                return
//            }
//        })
        todo()
    }
    
    private func bindPackageToggleEvent() -> Disposable {
//        return view.onPackageEvent
//            .observeOn(MainScheduler.instance)
//            .subscribeOn(MainScheduler.instance)
//            .flatMapLatest { [weak self] (event: OutlineEvent) -> Observable<(OutlineRepository, [Package])> in
//                guard let `self` = self else { return Observable.empty() }
//
//                switch event {
//                case let .togglePackage(item):
//                    return Observable.just((item.repo, [item.package]))
//                case let .toggleGroup(item):
//                    let packages = self.data[item.repo]![item]!
//                    let toggleIds = Set(self.selectedPackages.keys).intersection(packages.map { item.repo.repo.absoluteKey(for: $0.package) })
//                    let x = toggleIds.count > 0
//                        ? toggleIds.map { url in packages.first(where: { url == item.repo.repo.absoluteKey(for: $0.package) })!.package }
//                        : packages.map { $0.package }
//                    return Observable.just((item.repo, x))
//                default:
//                    return Observable.empty()
//                }
//            }
//            .subscribe(onNext: { [weak self] tuple in
//                guard let `self` = self else { return }
//
//                let repo = tuple.0
//                let packages = tuple.1
//
//                for package in packages {
//                    self.setPackageState(to: .toggle, package: package, repo: repo)
//                }
//
//                self.updatePrimaryButton()
//                self.view.refreshRepositories()
//            })
//
        todo()
    }
    
    func start() -> Disposable {
        return CompositeDisposable(disposables: [
            bindSettingsButton(),
            bindUpdatePackageList(),
//            bindPackageToggleEvent(),
//            bindPrimaryButton(),
//            bindContextMenuEvents(),
//            bindUpdatePackagesOnLoad()
        ])
    }
}

