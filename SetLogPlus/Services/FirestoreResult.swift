import Foundation

extension Result where Success == Void, Failure == Error {
    /// Bridges Firebase's `(Error?) -> Void` callbacks into `Result`.
    init(error: Error?) {
        if let error {
            self = .failure(error)
        } else {
            self = .success(())
        }
    }
}
