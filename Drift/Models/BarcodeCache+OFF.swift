import Foundation
import DriftCore

/// OpenFoodFacts-coupled convenience initializer for BarcodeCache. The data
/// part of BarcodeCache lives in DriftCore; this initializer references
/// OpenFoodFactsService.Product (still in the iOS app target) and stays here.
extension BarcodeCache {
    init(from product: OpenFoodFactsService.Product) {
        self.init(
            barcode: product.barcode,
            name: product.name,
            brand: product.brand,
            caloriesPer100g: product.calories,
            proteinGPer100g: product.proteinG,
            carbsGPer100g: product.carbsG,
            fatGPer100g: product.fatG,
            fiberGPer100g: product.fiberG,
            servingSizeG: product.servingSizeG,
            servingDescription: product.servingSize,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
