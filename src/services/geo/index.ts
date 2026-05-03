import { GeoDiscoveryEngine } from "@/core/geo/GeoDiscoveryEngine";
import { DefaultGeoDiscoveryRepository } from "@/services/geo/geoDiscoveryRepository";
import { HttpGeoDiscoveryDataSource } from "@/services/geo/httpGeoDiscoveryDataSource";
import { MockGeoDiscoveryDataSource } from "@/services/geo/mockGeoDiscoveryDataSource";

export { DefaultGeoDiscoveryRepository } from "@/services/geo/geoDiscoveryRepository";
export { HttpGeoDiscoveryDataSource } from "@/services/geo/httpGeoDiscoveryDataSource";
export { MockGeoDiscoveryDataSource } from "@/services/geo/mockGeoDiscoveryDataSource";

const dataSource = __DEV__ ? new MockGeoDiscoveryDataSource() : new HttpGeoDiscoveryDataSource();

export const geoDiscoveryRepository = new DefaultGeoDiscoveryRepository(dataSource);
export const geoDiscoveryEngine = new GeoDiscoveryEngine(geoDiscoveryRepository);
