extension RouteGuide {
  func runServer() async throws {
    let features = try Self.loadFeatures()
    let routeGuide = RouteGuideService(features: features)
  }
}
