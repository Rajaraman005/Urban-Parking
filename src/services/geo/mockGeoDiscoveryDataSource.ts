import { geoDiscoveryConfig, type GeoMockLatencyProfile } from "@/config/geoDiscovery";
import { haversineDistanceKm, roundDistanceKm } from "@/core/geo/distance";
import { GeoDiscoveryError } from "@/core/geo/geoError";
import { sleepWithAbort } from "@/core/geo/rateGuard";
import { MOCK_PARKING_SPOTS } from "@/constants/mockParking";
import type { ParkingSpot } from "@/models/parking";
import type {
  AvailabilityStatus,
  GeoDiscoveryBatchResult,
  GeoDiscoveryDataSource,
  GeoDiscoveryEntity,
  GeoDiscoveryFilters,
  GeoDiscoveryNormalizedQuery,
  GeoPoint,
  ServiceType
} from "@/types/geo";

interface MockMarketplaceResource {
  availabilityStatus: AvailabilityStatus;
  currency: "INR";
  id: string;
  imageUrl: string;
  location: GeoPoint;
  price: number;
  rating: number;
  serviceType: ServiceType;
  title: string;
}

const MOCK_RENTALS: MockMarketplaceResource[] = [
  {
    availabilityStatus: "available",
    currency: "INR",
    id: "rental-egmore-scooter-01",
    imageUrl: "https://images.unsplash.com/photo-1558981806-ec527fa84c39",
    location: { latitude: 13.0732, longitude: 80.2609 },
    price: 550,
    rating: 4.86,
    serviceType: "rental",
    title: "Egmore Scooter Rental"
  },
  {
    availabilityStatus: "limited",
    currency: "INR",
    id: "rental-nungambakkam-car-02",
    imageUrl: "https://images.unsplash.com/photo-1503376780353-7e6692767b70",
    location: { latitude: 13.0611, longitude: 80.2469 },
    price: 2200,
    rating: 4.72,
    serviceType: "rental",
    title: "Nungambakkam Compact Car"
  }
];

const MOCK_SERVICES: MockMarketplaceResource[] = [
  {
    availabilityStatus: "available",
    currency: "INR",
    id: "service-egmore-wash-01",
    imageUrl: "https://images.unsplash.com/photo-1607860108855-64acf2078ed9",
    location: { latitude: 13.078, longitude: 80.2633 },
    price: 399,
    rating: 4.9,
    serviceType: "service",
    title: "Doorstep Car Wash"
  },
  {
    availabilityStatus: "available",
    currency: "INR",
    id: "service-kilpauk-repair-02",
    imageUrl: "https://images.unsplash.com/photo-1487754180451-c456f719a1fc",
    location: { latitude: 13.0837, longitude: 80.2405 },
    price: 799,
    rating: 4.66,
    serviceType: "service",
    title: "On-site Mechanic"
  }
];

const latencyRanges: Record<GeoMockLatencyProfile, [number, number]> = {
  fast: [150, 300],
  normal: [500, 900],
  slow: [1200, 1800]
};

const deterministicDelay = (seed: string, profile: GeoMockLatencyProfile) => {
  const [min, max] = latencyRanges[profile];
  const hash = Array.from(seed).reduce((acc, char) => acc + char.charCodeAt(0), 0);
  return min + (hash % (max - min + 1));
};

const cursorFor = (queryFingerprint: string, serviceType: ServiceType, offset: number) =>
  `${queryFingerprint}::${serviceType}::${offset}`;

const parseCursor = (cursor: string, queryFingerprint: string, serviceType: ServiceType) => {
  const [cursorFingerprint, cursorServiceType, offsetText] = cursor.split("::");

  if (cursorFingerprint !== queryFingerprint || cursorServiceType !== serviceType) {
    throw new GeoDiscoveryError("Geo discovery cursor does not match the current query", {
      code: "invalid_cursor",
      retryable: true
    });
  }

  const offset = Number(offsetText);

  if (!Number.isInteger(offset) || offset < 0) {
    throw new GeoDiscoveryError("Geo discovery cursor offset is invalid", {
      code: "invalid_cursor",
      retryable: true
    });
  }

  return offset;
};

const parkingAvailability = (spot: ParkingSpot): AvailabilityStatus => {
  if (spot.slotsAvailable <= 0) {
    return "unavailable";
  }

  return spot.slotsAvailable <= 2 ? "limited" : "available";
};

const toParkingEntity = (spot: ParkingSpot, userLocation: GeoPoint): GeoDiscoveryEntity<ParkingSpot> => {
  const distanceKm = roundDistanceKm(haversineDistanceKm(userLocation, spot.location));

  return {
    availabilityStatus: parkingAvailability(spot),
    currency: spot.currency,
    distanceKm,
    entity: {
      ...spot,
      distanceKm
    },
    id: spot.id,
    imageUrl: spot.imageUrl,
    location: spot.location,
    price: spot.price,
    rating: spot.rating,
    serviceType: "parking",
    title: spot.title
  };
};

const toResourceEntity = (
  resource: MockMarketplaceResource,
  userLocation: GeoPoint,
): GeoDiscoveryEntity<MockMarketplaceResource> => ({
  availabilityStatus: resource.availabilityStatus,
  currency: resource.currency,
  distanceKm: roundDistanceKm(haversineDistanceKm(userLocation, resource.location)),
  entity: resource,
  id: resource.id,
  imageUrl: resource.imageUrl,
  location: resource.location,
  price: resource.price,
  rating: resource.rating,
  serviceType: resource.serviceType,
  title: resource.title
});

const applyFilters = <TEntity>(
  items: GeoDiscoveryEntity<TEntity>[],
  filters?: GeoDiscoveryFilters,
) =>
  items.filter((item) => {
    if (filters?.availability && filters.availability !== "any" && item.availabilityStatus !== filters.availability) {
      return false;
    }

    if (typeof filters?.maxPrice === "number" && typeof item.price === "number" && item.price > filters.maxPrice) {
      return false;
    }

    if (typeof filters?.minRating === "number" && typeof item.rating === "number" && item.rating < filters.minRating) {
      return false;
    }

    return true;
  });

const sortItems = <TEntity>(items: GeoDiscoveryEntity<TEntity>[], sort: GeoDiscoveryNormalizedQuery["sort"]) =>
  [...items].sort((left, right) => {
    if (sort === "price") {
      return (left.price ?? Number.MAX_SAFE_INTEGER) - (right.price ?? Number.MAX_SAFE_INTEGER);
    }

    if (sort === "rating") {
      return (right.rating ?? 0) - (left.rating ?? 0);
    }

    return left.distanceKm - right.distanceKm;
  });

export class MockGeoDiscoveryDataSource implements GeoDiscoveryDataSource {
  async searchNearby<TEntity = unknown>(
    query: GeoDiscoveryNormalizedQuery,
    signal?: AbortSignal,
  ): Promise<GeoDiscoveryBatchResult<TEntity>> {
    await sleepWithAbort(
      deterministicDelay(query.queryFingerprint, geoDiscoveryConfig.mock.latencyProfile),
      signal,
    );

    this.applyScenario(query);

    const center = { latitude: query.latitude, longitude: query.longitude };
    const fetchedAt = new Date().toISOString();
    const results: GeoDiscoveryBatchResult<TEntity>["results"] = {};
    const partialFailures: GeoDiscoveryBatchResult<TEntity>["partialFailures"] = [];

    for (const serviceType of query.serviceTypes) {
      if (geoDiscoveryConfig.mock.scenario === "partialFailure" && serviceType === "rental") {
        partialFailures.push({
          code: "network_error",
          message: "Mock rental vertical failed",
          retryable: true,
          serviceType
        });
        continue;
      }

      const serviceItems =
        geoDiscoveryConfig.mock.scenario === "empty"
          ? []
          : (this.itemsForService(serviceType, center) as GeoDiscoveryEntity<TEntity>[]);
      const filtered = applyFilters(
        serviceItems.filter((item) => item.distanceKm <= query.radiusKm),
        query.filters[serviceType],
      );
      const sorted = sortItems(filtered, query.sort);
      const offset = query.cursors[serviceType]
        ? parseCursor(query.cursors[serviceType] ?? "", query.queryFingerprint, serviceType)
        : 0;
      const pageItems = sorted.slice(offset, offset + query.pageSize);
      const nextOffset = offset + query.pageSize;
      const nextCursor =
        nextOffset < sorted.length ? cursorFor(query.queryFingerprint, serviceType, nextOffset) : undefined;

      results[serviceType] = {
        fetchedAt,
        isStale: false,
        items: pageItems,
        nextCursor,
        queryFingerprint: query.queryFingerprint,
        schemaVersion: query.schemaVersion,
        source: "mock"
      };
    }

    return {
      fetchedAt,
      partialFailures,
      queryFingerprint: query.queryFingerprint,
      results,
      schemaVersion: query.schemaVersion,
      source: "mock"
    };
  }

  private itemsForService(serviceType: ServiceType, center: GeoPoint) {
    if (serviceType === "parking") {
      return MOCK_PARKING_SPOTS.map((spot) => toParkingEntity(spot, center));
    }

    if (serviceType === "rental") {
      return MOCK_RENTALS.map((resource) => toResourceEntity(resource, center));
    }

    return MOCK_SERVICES.map((resource) => toResourceEntity(resource, center));
  }

  private applyScenario(query: GeoDiscoveryNormalizedQuery) {
    switch (geoDiscoveryConfig.mock.scenario) {
      case "empty":
      case "none":
      case "partialFailure":
        return;
      case "malformed":
        throw new GeoDiscoveryError("Mock schema contract mismatch", {
          code: "contract_mismatch",
          retryable: false
        });
      case "rateLimited":
        throw new GeoDiscoveryError("Mock geo discovery rate limited", {
          code: "rate_limited",
          retryAfterMs: 1000,
          retryable: true
        });
      case "serverError":
        throw new GeoDiscoveryError("Mock geo discovery server error", {
          code: "network_error",
          retryable: true
        });
      case "timeout":
        throw new GeoDiscoveryError("Mock geo discovery timed out", {
          code: "backend_timeout",
          retryable: true
        });
      default:
        throw new GeoDiscoveryError(`Unsupported mock scenario for ${query.queryFingerprint}`, {
          code: "unknown",
          retryable: false
        });
    }
  }
}
