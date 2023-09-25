//
//  NursingTimer.swift
//  BabyPlus
//
//  Created by Hussein Elbeheiry on 9/25/23.
//

import Factory
import MabyKit
import SwiftUI
import Foundation
import Combine

class NursingTimer: ObservableObject {
    enum State {
        case idle
        case running
    }

    @Injected(Container.eventService) private var eventService
    private var cancellables: Set<AnyCancellable> = []

    @Published var state: State = .idle
    @Published var side: NursingEvent.Breast?
    @Published var startDate: Date?
    @Published var duration: Int = 0
    @Published var nursingEvents: [NursingEvent] = []

    private var timer: Timer?

    func start(side: NursingEvent.Breast) {
        self.state = .running
        self.side = side
        self.startDate = Date()
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.duration += 1
            }
            .store(in: &cancellables)
    }

    func stop() {
        self.timer?.invalidate()
        self.timer = nil
        if let startDate = startDate, let side = side {
            let end = Date()
            let result = eventService.addNursing(start: startDate, end: end, breast: side)
            switch result {
            case .success(let nursingEvent):
                self.nursingEvents.append(nursingEvent)
                self.startDate = nil
                self.side = nil
                self.duration = 0
            case .failure(let error):
                print("Failed to add nursing event: \(error)")
            }
        }
        cancellables.removeAll()
    }

    func canStart() -> Bool {
        return side != nil
    }
}
