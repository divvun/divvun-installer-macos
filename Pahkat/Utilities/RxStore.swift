//
//  RxStore.swift
//  Pahkat
//
//  Created by Brendan Molloy on 2018-02-06.
//  Copyright © 2018 Divvun. All rights reserved.
//

import Foundation
import RxSwift
import RxFeedback

class RxStore<State, Event> {
    typealias Reducer = (State, Event) -> State
    
    private let dispatcher: PublishSubject<Event>
    let state: Observable<State>
    
    func dispatch(event: Event) {
        dispatcher.onNext(event)
    }
    
    init(initialState: State, reducers: [Reducer]) {
        let dispatcher = PublishSubject<Event>()
        
        state = Observable.system(
            initialState: initialState,
            reduce: { (i: State, e: Event) -> State in
                reducers.reduce(i, { (state: State, next: Reducer) in next(state, e) })
            },
            scheduler: MainScheduler.instance,
            scheduledFeedback: { _ in dispatcher })
            .replay(1).refCount()
        
        self.dispatcher = dispatcher
    }
    
    convenience init(initialState: State, reducers: Reducer...) {
        self.init(initialState: initialState, reducers: reducers)
    }
}
