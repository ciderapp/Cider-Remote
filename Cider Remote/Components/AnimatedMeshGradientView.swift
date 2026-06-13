// Made by Lumaa

import SwiftUI

struct AnimatedMeshGradientView: View {
    @State private var points: [SIMD2<Float>] = initialPoints()

    @Binding var colors: [Color]

    var amplify: Float = 1.0

    static var length: Int = 5

    var body: some View {
        MeshGradient(
            width: Self.length,
            height: Self.length,
            points: points,
            colors: colors
        )
        .onAppear {
            animate()
        }
    }
    
    private static func initialPoints() -> [SIMD2<Float>] {
        var pts: [SIMD2<Float>] = []
        for y in 0..<Self.length {
            for x in 0..<Self.length {
                pts.append(SIMD2(Float(x) / Float(Self.length - 1), Float(y) / Float(Self.length - 1)))
            }
        }
        return pts
    }

    private func randomPoints() -> [SIMD2<Float>] {
        let innerCount = Self.length - 2
        var targetPoints = Array(repeating: SIMD2<Float>(0, 0), count: Self.length * Self.length)

        // Set x coordinates
        for j in 0..<Self.length {
            if j == 0 || j == Self.length - 1 {
                // Boundary rows: fixed uniform positions
                for i in 0..<Self.length {
                    targetPoints[j * Self.length + i].x = Float(i) / Float(Self.length - 1)
                }
            } else {
                // Interior rows: fixed edges, scaled random inners
                targetPoints[j * Self.length + 0].x = 0
                targetPoints[j * Self.length + (Self.length - 1)].x = 1

                var uniformInnerX: [Float] = []
                for ii in 1...innerCount {
                    uniformInnerX.append(Float(ii) / Float(Self.length - 1))
                }

                let randomInnerX = (0..<innerCount).map { _ in Float.random(in: 0..<1) }.sorted()

                var scaledInnerX: [Float] = []
                for k in 0..<innerCount {
                    scaledInnerX.append(uniformInnerX[k] + amplify * (randomInnerX[k] - uniformInnerX[k]))
                }

                for ii in 0..<innerCount {
                    targetPoints[j * Self.length + (ii + 1)].x = scaledInnerX[ii]
                }
            }
        }

        // Set y coordinates
        for i in 0..<Self.length {
            if i == 0 || i == Self.length - 1 {
                // Boundary columns: fixed uniform positions
                for j in 0..<Self.length {
                    targetPoints[j * Self.length + i].y = Float(j) / Float(Self.length - 1)
                }
            } else {
                // Interior columns: fixed edges, scaled random inners
                targetPoints[0 * Self.length + i].y = 0
                targetPoints[(Self.length - 1) * Self.length + i].y = 1

                var uniformInnerY: [Float] = []
                for jj in 1...innerCount {
                    uniformInnerY.append(Float(jj) / Float(Self.length - 1))
                }

                let randomInnerY = (0..<innerCount).map { _ in Float.random(in: 0..<1) }.sorted()

                var scaledInnerY: [Float] = []
                for k in 0..<innerCount {
                    scaledInnerY.append(uniformInnerY[k] + amplify * (randomInnerY[k] - uniformInnerY[k]))
                }

                for jj in 0..<innerCount {
                    targetPoints[(jj + 1) * Self.length + i].y = scaledInnerY[jj]
                }
            }
        }

        return targetPoints
    }

    private func animate() {
        let newPoints = randomPoints()
        withAnimation(.easeInOut(duration: 8)) {
            points = newPoints
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            animate()
        }
    }
}
