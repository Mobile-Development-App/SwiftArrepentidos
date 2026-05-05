import Foundation
import Kingfisher

// ─────────────────────────────────────────────────────────────────────────────
// ImageCacheConfig — Sprint 3 (Caching strategy: image cache library).
//
// Cubre la categoría "Glide / Picasso / NetworkCacheImage / KingFisher / Coil"
// de la rúbrica usando **Kingfisher**, la librería estándar de caché de
// imágenes en Swift. Complementa al `LRUCache` (caché genérico in-memory) y
// al `BQCacheService` (caché de 2 capas para snapshots de BQ) — esos dos son
// para datos estructurados; éste es para los `imageURL` de los productos.
//
// Configuración explícita (NO uso defaults, así puedo defender los números):
//   • Memoria : 50 MB     (cap suficiente para 200+ thumbnails de 256 px)
//   • Disco   : 200 MB    (catálogo de imágenes de productos a largo plazo)
//   • TTL disco: 7 días   (las imágenes de productos cambian raro)
//   • Timeout descarga: 15 s
//   • Pre-fetch retry: 3 intentos
//
// Llamado una sola vez desde `InventarIAApp.init` antes del primer uso.
// ─────────────────────────────────────────────────────────────────────────────

enum ImageCacheConfig {

    static func bootstrap() {
        let cache = ImageCache.default

        // Capa de memoria
        cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024   // 50 MB
        cache.memoryStorage.config.countLimit = 200                    // imágenes
        cache.memoryStorage.config.expiration = .seconds(5 * 60)       // 5 min

        // Capa de disco
        cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024         // 200 MB
        cache.diskStorage.config.expiration = .days(7)                 // 1 semana

        // Descargador
        let downloader = ImageDownloader.default
        downloader.downloadTimeout = 15

        // Limpieza al cierre / background
        cache.cleanExpiredMemoryCache()
        cache.cleanExpiredDiskCache()
    }

    /// Tamaño actual de la caché en disco (en bytes). Útil para mostrar un
    /// indicador en pantallas de debug si se quiere.
    static func currentDiskCacheSize() async -> UInt {
        await withCheckedContinuation { continuation in
            ImageCache.default.calculateDiskStorageSize { result in
                switch result {
                case .success(let size): continuation.resume(returning: size)
                case .failure: continuation.resume(returning: 0)
                }
            }
        }
    }

    /// Vacía ambas capas. Llamado en logout.
    static func clear() {
        ImageCache.default.clearMemoryCache()
        ImageCache.default.clearDiskCache()
    }
}
