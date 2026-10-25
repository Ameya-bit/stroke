import Foundation
import simd

struct Sample: Codable, Equatable {
    let position: SIMD3<Float>
    let time: TimeInterval
}

struct Stroke: Codable, Identifiable {
    let id: UUID
    let samples: [Sample]

    init(id: UUID = UUID(), samples: [Sample] = []) {
        self.id = id
        self.samples = samples
    }

    func appending(_ sample: Sample) -> Stroke {
        Stroke(id: id, samples: samples + [sample])
    }

    var last: Sample? { samples.last }
}
