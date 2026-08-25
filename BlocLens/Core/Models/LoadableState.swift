enum LoadableState<Value> {
    case initial
    case loading
    case loaded(Value)
    case empty
    case error(RepositoryError)
    case offlineWithCache(Value)
    case offlineWithoutCache
}
