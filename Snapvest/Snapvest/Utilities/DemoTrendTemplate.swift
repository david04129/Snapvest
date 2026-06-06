//
//  DemoTrendTemplate.swift
//  Snapvest
//
//  離線走勢形狀（比例 0…1），進示範後依 rebuild 首頁快照縮放，不需拉歷史股價。
//

import Foundation

struct DemoTrendShapePoint {
    let netWorthRatio: Double
    let totalAssetsRatio: Double
    let unrealizedRatio: Double
}

enum DemoTrendTemplate {
    static let dayCount = 365

    /// 終點比例皆為 1.0；起點約 0.82～0.86，含平滑波動。
    static func shapePoints() -> [DemoTrendShapePoint] {
        var rawNetWorths: [Double] = []
        var value = 0.82
        var momentum = 0.0

        for index in 0..<dayCount {
            let progress = Double(index) / Double(dayCount - 1)
            let trendDrift = 0.00055 + progress * 0.00035
            let volatility = progress < 0.35 ? 0.012 : (progress < 0.72 ? 0.018 : 0.014)

            let shock = seededNoise(index, salt: 11)
            let clusterShock = seededNoise(index / 4, salt: 73) * 0.55
            momentum = momentum * 0.62 + (shock + clusterShock) * volatility
            let surge = eventPulse(progress, start: 0.42, end: 0.55, amplitude: 0.016)
            let dip = eventPulse(progress, start: 0.56, end: 0.63, amplitude: -0.020)
            let rebound = eventPulse(progress, start: 0.82, end: 0.96, amplitude: 0.014)

            value += trendDrift + momentum + surge + dip + rebound
            rawNetWorths.append(max(0.78, value))
        }

        let rawStart = rawNetWorths.first ?? 0.82
        let rawEnd = rawNetWorths.last ?? 1.0
        let scale = (1.0 - rawStart) / max(0.001, rawEnd - rawStart)

        return rawNetWorths.enumerated().map { index, raw in
            let progress = Double(index) / Double(dayCount - 1)
            let netRatio = rawStart + (raw - rawStart) * scale
            let liabilityShare = 0.088 - progress * 0.012
            let totalAssetsRatio = netRatio + liabilityShare
            let unrealizedBase = 0.72 + (netRatio - rawStart) * 0.35
            let unrealizedRatio = unrealizedBase + seededNoise(index, salt: 701) * 0.06

            return DemoTrendShapePoint(
                netWorthRatio: netRatio,
                totalAssetsRatio: totalAssetsRatio,
                unrealizedRatio: max(0.55, unrealizedRatio)
            )
        }
    }

    private static func seededNoise(_ index: Int, salt: UInt64) -> Double {
        let primary = seededUnit(index, salt: salt) * 2 - 1
        let secondary = seededUnit(index, salt: salt &+ 10_007) * 2 - 1
        return primary * 0.72 + secondary * 0.28
    }

    private static func seededUnit(_ index: Int, salt: UInt64) -> Double {
        var value = UInt64(bitPattern: Int64(index + 1))
        value = value &* 0x9E3779B185EBCA87 &+ salt
        value ^= value >> 30
        value = value &* 0xBF58476D1CE4E5B9
        value ^= value >> 27
        value = value &* 0x94D049BB133111EB
        value ^= value >> 31
        return Double(value & 0xFFFF_FFFF) / Double(UInt32.max)
    }

    private static func eventPulse(_ progress: Double, start: Double, end: Double, amplitude: Double) -> Double {
        guard progress >= start, progress <= end else { return 0 }
        let local = (progress - start) / (end - start)
        return amplitude * sin(local * .pi)
    }
}
