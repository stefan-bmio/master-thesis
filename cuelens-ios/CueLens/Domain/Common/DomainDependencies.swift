import Foundation

protocol DateProviding: Sendable {
    var now: Date { get }
}

struct SystemDateProvider: DateProviding {
    var now: Date { Date() }
}

protocol Randomizing: Sendable {
    func shuffled<T>(_ values: [T]) -> [T]
    func nextBoolean() -> Bool
}

struct SystemRandomizer: Randomizing {
    func shuffled<T>(_ values: [T]) -> [T] {
        values.shuffled()
    }

    func nextBoolean() -> Bool {
        Bool.random()
    }
}
