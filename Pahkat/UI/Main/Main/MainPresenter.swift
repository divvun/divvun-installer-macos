//
//  MainPresenter.swift
//  Pahkat
//
//  Created by Brendan Molloy on 2018-02-06.
//  Copyright © 2018 Divvun. All rights reserved.
//

import Foundation
import RxSwift

class MainPresenter {
    private unowned var view: MainViewable
    
    init(view: MainViewable) {
        self.view = view
    }
    
//    private func bindPrimaryButtonLabel() -> Disposable {
//
//    }
    
    private func bindUpdatePackageList() -> Disposable {
        return AppContext.store.state
            .filter { $0.repository != nil }
            .map { $0.repository! }
            .distinctUntilChanged()
            .subscribe(onNext: { repo in
                // TODO: do what is needed to cause the outline view to update.
                print(repo.meta)
            }, onError: { [weak self] in self?.view.handle(error: $0) })
    }
    
//    private func bindPackageToggled() -> Disposable {
//
//    }
//
//    private func bindGroupToggled() -> Disposable {
//
//    }
//
    private func bindPrimaryButton() -> Disposable {
        return view.onPrimaryButtonPressed.drive(onNext: {
            let mainWindow = AppContext.windows.get(MainWindowController.self)
            mainWindow.contentWindow.set(viewController: DownloadViewController(packages: []))
        })
    }
    
    func start() -> Disposable {
        //guard let view = view else { return Disposables.create() }
        
        view.update(title: Strings.loading)
        
        return CompositeDisposable(disposables: [
//            bindPrimaryButtonLabel(),
            bindUpdatePackageList(),
//            bindPackageToggled(),
//            bindGroupToggled(),
            bindPrimaryButton()
        ])
        
//        return view.onPrimaryButtonPressed.drive(onNext: {
//
//        }, onCompleted: nil, onDisposed: nil)
    }
}
