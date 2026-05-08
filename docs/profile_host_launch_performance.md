# Profile to Host Parking Performance Report

## 1. Root Cause Analysis

The pre-optimization launch path blocked navigation from Profile while it resolved auth, checked resumable drafts, optionally loaded multiple draft rows, created or resumed a draft, and updated profile setup state. The user saw no route transition during that network waterfall.

The optimized path makes route transition the first signed-in action. Draft lookup, resume choice, and fresh draft creation now run behind the visible Host setup screen through `HostSetupLaunchController`.

## 2. Bottleneck Timeline

Previous hot path:

1. Tap `Host a parking space`.
2. Await `authControllerProvider.future` if auth is still hydrating.
3. Await `loadHostDraftResumeCandidate()`.
4. Potentially await multiple draft reads and legacy draft lookup.
5. Await `startHostListing()`.
6. Navigate.
7. Destination screen may call `startHostListing()` again.

Optimized hot path:

1. Tap `Host a parking space`.
2. If authenticated, call `context.go('/setup/host-basics?launch=instant')`.
3. Render Step 1 shell.
4. Hydrate resume/fresh draft in the background.
5. Show non-blocking resume banner or enable fresh draft save when ready.

## 3. Profiling Evidence

The code now emits launch telemetry events and a DevTools timeline span:

- `host_launch_tap`
- `host_launch_route_visible`
- `host_launch_first_frame`
- `host_launch_hydration_started`
- `host_launch_resume_available`
- `host_launch_draft_ready`
- `host_launch_failed`
- Timeline span: `host_setup_launch_hydrate`

Capture before/after profiles with Flutter DevTools:

- Timeline flame chart
- CPU profiler
- Memory profiler
- Widget rebuild profiler
- Raster thread analysis
- Shader compilation analysis
- Frame timing analysis

Record:

- Dropped frames
- Main isolate blocking spans
- Raster thread over-budget frames
- Shader compilation during interaction
- GPU overdraw around the route transition
- Memory allocation spikes and GC pauses

## 4. Architecture Problems

The live flow still uses `features/user_setup` screens while `features/host_parking` contains the newer local-first draft architecture. This implementation reduces the launch bottleneck while preserving compatibility with the existing photo/upload/publish path.

Longer-term migration should move all host setup screens to the `features/host_parking` domain model, keeping `user_setup` as a legacy bridge.

## 5. Network Analysis

Implemented:

- Removed pre-route Supabase draft lookup.
- Coalesced in-flight resume lookup requests.
- Coalesced duplicate `startHostListing()` requests with matching arguments.
- Parallelized independent resume candidate reads in `UserSetupRepositoryImpl`.
- Added background prewarm from Profile pointer-down.
- Added partial indexes for draft and linked-photo lookup.

Remaining production follow-up:

- Replace launch-side profile update plus draft ensure with one transactional RPC when the full host v2 migration is complete.

## 6. Rendering Analysis

Implemented:

- Step 1 renders before map initialization.
- `AddressMapPreview` is deferred by one frame on instant launch.
- Map preview is isolated behind a `RepaintBoundary`.
- Host photo and review photo previews use bounded cached image decoding.
- Photo rows are isolated behind repaint boundaries.

## 7. Memory Analysis

Implemented:

- Bounded avatar/photo thumbnail cache dimensions.
- Avoided full-size `Image.network` decoding for small tiles.
- Kept existing timer/controller disposal paths.
- Preserved address search token cancellation for stale autocomplete results.

Profile during device testing:

- GC count during tap to first frame.
- Allocations from map creation.
- Image cache growth after photos/review screens.
- Timer and controller retention after leaving setup.

## 8. Refactor Plan

Completed:

- Added `HostSetupLaunchController`.
- Made `startHostSetup()` navigate immediately for authenticated users.
- Moved resume detection into progressive hydration.
- Replaced blocking resume modal with in-flow resume banner.
- Deferred heavy map work.
- Added request coalescing and targeted indexes.

Next phase:

- Migrate basics/pricing/photos/review screens fully to `HostParkingDraftController`.
- Move photo upload methods into `features/host_parking`.
- Use encrypted per-user local host draft storage.

## 9. Optimized Code

Primary files:

- `lib/features/user_setup/presentation/host_setup_launcher.dart`
- `lib/features/user_setup/presentation/host_setup_launch_controller.dart`
- `lib/features/user_setup/presentation/host_space_basics_screen.dart`
- `lib/features/user_setup/presentation/user_setup_controller.dart`
- `lib/shared/widgets/address_search_map_picker.dart`
- `supabase/migrations/202605080003_host_parking_launch_performance.sql`

## 10. Benchmark Comparison

Benchmark targets:

- Warm tap to route visible: P50 <= 100 ms, P95 <= 250 ms
- Tap to first usable Step 1 frame: P95 <= 500 ms
- Draft ready on healthy network: P95 <= 1.5 s
- Build frame budget: < 16 ms
- Raster budget: < 8 ms
- Zero dropped frames during route transition

Test profiles:

- Cold app launch
- Warm app launch
- Cached session launch
- Slow 3G simulation
- High latency simulation
- Low memory device simulation

## 11. Risk Assessment

Risks:

- Users can see the form before draft hydration completes; save remains blocked until hydration resolves or a resume choice is handled.
- The host flow is still split between old `user_setup` screens and newer `host_parking` domain code.
- Map deferral changes first-frame visual composition but preserves interaction after the next frame.

Mitigations:

- Non-blocking resume banner prevents accidental overwrite of existing drafts.
- Request coalescing prevents duplicate draft bootstraps.
- Existing tests plus new launch tests guard instant navigation and map deferral.

## 12. Scalability Review

The optimized launch path scales better because route visibility no longer depends on Supabase latency. The database indexes reduce lookup cost for active host drafts and linked draft photos. Request coalescing reduces duplicate client traffic during route transitions and provider rebuilds.

## 13. Production Rollout Strategy

1. Ship behind the existing route with no public API change.
2. Monitor `host_launch_*` telemetry P50/P95/P99.
3. Capture DevTools profiles on representative Android devices.
4. Watch launch failures, resume-choice rate, duplicate request count, and draft creation latency.
5. Migrate remaining host setup screens to `features/host_parking` after launch metrics stabilize.
