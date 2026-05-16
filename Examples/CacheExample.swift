import Foundation
import StateKitCache
import Riverpods

// MARK: - Cache Example: Product Catalog with LRU Caching

/// Demonstrates caching patterns in a product catalog application.
/// This example shows how to use LRUCache and TTLCache with cache-aside pattern
/// to optimize expensive operations like network requests and image loading.

// MARK: - Data Models

struct Product: Sendable, Codable {
    let id: String
    let name: String
    let price: Double
    let description: String
    let imageURL: String
}

struct CatalogState: Sendable {
    var products: [Product] = []
    var isLoading: Bool = false
    var error: String? = nil
    var cacheStats: CacheStats = CacheStats(hits: 0, misses: 0)
}

// MARK: - Simulated API Service

@MainActor
final class ProductService: Sendable {
    private let cache: LRUCache<String, Product>
    private let imageCache: TTLCache<String, Data>

    // Statistics for demonstration
    var networkRequestCount = 0
    var cacheHitCount = 0

    init() {
        self.cache = LRUCache<String, Product>(capacity: 100)
        self.imageCache = TTLCache<String, Data>(ttl: 3600)  // 1 hour
    }

    /// Fetches product using cache-aside pattern.
    func getProduct(id: String) async throws -> Product {
        // Check cache first
        if let cached = cache.get(id) {
            cacheHitCount += 1
            return cached
        }

        // Not in cache, fetch from "API"
        networkRequestCount += 1
        let product = try await fetchFromAPI(id)

        // Store in cache
        cache.set(id, value: product)
        return product
    }

    /// Fetches product image with automatic expiration.
    func getProductImage(url: String) async throws -> Data {
        // Check image cache first
        if let cached = imageCache.get(url) {
            return cached
        }

        // Fetch image data
        networkRequestCount += 1
        let imageData = try await downloadImage(url)

        // Store in cache with TTL
        imageCache.set(url, value: imageData)
        return imageData
    }

    /// Preloads popular products into cache.
    func preloadPopularProducts() async throws {
        let popularIds = ["prod-1", "prod-2", "prod-3", "prod-4", "prod-5"]

        for id in popularIds {
            let product = try await fetchFromAPI(id)
            cache.set(id, value: product)
        }
    }

    /// Gets cache statistics.
    func getCacheStats() -> CacheStats {
        cache.stats
    }

    /// Clears all caches.
    func clearCaches() {
        cache.clear()
        imageCache.clear()
    }

    // MARK: - Simulated API Calls

    private func fetchFromAPI(_ productId: String) async throws -> Product {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        return Product(
            id: productId,
            name: "Product \(productId)",
            price: Double.random(in: 10...500),
            description: "High-quality product with great features",
            imageURL: "https://api.example.com/images/\(productId).jpg"
        )
    }

    private func downloadImage(_ url: String) async throws -> Data {
        // Simulate image download
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        return "image-data-for-\(url)".data(using: .utf8) ?? Data()
    }
}

// MARK: - Provider Definitions (Riverpods Style)

let productServiceProvider = Provider<ProductService> { _ in
    ProductService()
}

let productProvider = FutureProvider<String, Product> { ref, productId in
    let service = ref.watch(productServiceProvider)
    return try await service.getProduct(id: productId)
}

let cacheStatsProvider = Provider<CacheStats> { ref in
    let service = ref.watch(productServiceProvider)
    return service.getCacheStats()
}

// MARK: - Cache Example Demonstration

@main
struct CacheExampleApp {
    static func main() async {
        print("=== StateKit Cache Example ===\n")

        // Create container and service
        let container = ProviderContainer()

        // Get service from provider
        let service = container.read(productServiceProvider)

        // Demo 1: Basic Cache-Aside Pattern
        print("📦 Demo 1: Cache-Aside Pattern")
        print("Fetching product 'prod-123' (first call - miss)...")
        let start1 = Date()
        let product1 = try! await service.getProduct(id: "prod-123")
        let duration1 = Date().timeIntervalSince(start1)
        print("✓ Retrieved: \(product1.name) ($\(product1.price))")
        print("  Time: \(String(format: "%.2f", duration1))s (network request)")
        print("  Cache hits: \(service.cacheHitCount), Network requests: \(service.networkRequestCount)\n")

        // Second fetch should hit cache
        print("Fetching product 'prod-123' again (cache hit)...")
        let start2 = Date()
        let product2 = try! await service.getProduct(id: "prod-123")
        let duration2 = Date().timeIntervalSince(start2)
        print("✓ Retrieved from cache: \(product2.name)")
        print("  Time: \(String(format: "%.2f", duration2))s (cache hit)")
        print("  Cache hits: \(service.cacheHitCount), Network requests: \(service.networkRequestCount)\n")

        // Demo 2: Multiple Products
        print("📦 Demo 2: Multiple Products")
        for id in ["prod-a", "prod-b", "prod-c"] {
            let product = try! await service.getProduct(id: id)
            print("✓ \(product.name)")
        }
        print("  Cache hits: \(service.cacheHitCount), Network requests: \(service.networkRequestCount)\n")

        // Demo 3: Cache Stats
        print("📦 Demo 3: Cache Statistics")
        let stats = service.getCacheStats()
        print("Total requests: \(stats.hits + stats.misses)")
        print("Cache hits: \(stats.hits)")
        print("Cache misses: \(stats.misses)")
        print("Hit rate: \(String(format: "%.1f", stats.hitRate * 100))%\n")

        // Demo 4: Preloading
        print("📦 Demo 4: Cache Preloading")
        print("Preloading popular products...")
        try! await service.preloadPopularProducts()
        print("✓ Preloaded 5 products")
        print("  Cache hits: \(service.cacheHitCount), Network requests: \(service.networkRequestCount)\n")

        // Fetch preloaded product (should hit cache)
        print("Fetching preloaded product 'prod-1'...")
        let start3 = Date()
        let preloadedProduct = try! await service.getProduct(id: "prod-1")
        let duration3 = Date().timeIntervalSince(start3)
        print("✓ Retrieved from cache: \(preloadedProduct.name)")
        print("  Time: \(String(format: "%.2f", duration3))s (cache hit)")
        print("  Final stats - Cache hits: \(service.cacheHitCount), Network requests: \(service.networkRequestCount)\n")

        // Demo 5: Cache Invalidation
        print("📦 Demo 5: Cache Invalidation")
        print("Clearing caches...")
        service.clearCaches()
        print("✓ Caches cleared")
        print("Fetching cleared product (should require network)...")
        let start4 = Date()
        let clearedProduct = try! await service.getProduct(id: "prod-1")
        let duration4 = Date().timeIntervalSince(start4)
        print("✓ Retrieved: \(clearedProduct.name) (network request)")
        print("  Time: \(String(format: "%.2f", duration4))s\n")

        print("✅ Cache example completed!")
        print("Key takeaways:")
        print("• Cache-aside pattern: check cache first, then fetch and store")
        print("• TTL caches: automatic expiration for time-sensitive data")
        print("• Preloading: warm cache with popular items")
        print("• Monitoring: track hit rates for optimization")
    }
}
