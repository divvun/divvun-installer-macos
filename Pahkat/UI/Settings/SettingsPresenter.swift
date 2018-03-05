//
//  SettingsPresenter.swift
//  Pahkat
//
//  Created by Brendan Molloy on 2018-03-02.
//  Copyright © 2018 Divvun. All rights reserved.
//

import Foundation
import RxSwift

class SettingsPresenter {
    private unowned let view: SettingsViewable
    
    init(view: SettingsViewable) {
        self.view = view
    }
    
    private func bindRepositoryTable() -> Disposable {
        return AppContext.settings.state.map { $0.repositories }
            .flatMapLatest { (configs: [RepoConfig]) -> Observable<[RepositoryTableRowData]> in
                return Observable.merge(try configs.map { (config: RepoConfig) -> Observable<RepositoryTableRowData> in
                    return try AppContext.rpc.repository(with: config).asObservable().map { repo in
                        return RepositoryTableRowData(name: repo.meta.nativeName, url: config.url, channel: config.channel)
                    }
                }).toArray()
            }
            .observeOn(MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] rowData in
                self?.view.setRepositories(repositories: rowData)
            })
    }
    
    func start() -> Disposable {
        return CompositeDisposable(disposables: [
            bindRepositoryTable()
        ])
    }
}