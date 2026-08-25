import Foundation

nonisolated enum RemoteSeedIdentifiers {
    static let gyms: [String: String] = [
        "urban-climb-west-end": "10000000-0000-4000-8000-000000000001",
        "urban-climb-newstead": "10000000-0000-4000-8000-000000000002",
        "nine-degrees-enoggera": "10000000-0000-4000-8000-000000000003"
    ]

    static let wallZones: [String: String] = [
        "west-end-slab": "20000000-0000-4000-8000-000000000001",
        "west-end-cave": "20000000-0000-4000-8000-000000000002",
        "west-end-comp": "20000000-0000-4000-8000-000000000003",
        "newstead-island": "20000000-0000-4000-8000-000000000004",
        "newstead-steep": "20000000-0000-4000-8000-000000000005",
        "newstead-vertical": "20000000-0000-4000-8000-000000000006",
        "enoggera-slab": "20000000-0000-4000-8000-000000000007",
        "enoggera-cave": "20000000-0000-4000-8000-000000000008",
        "enoggera-main": "20000000-0000-4000-8000-000000000009"
    ]

    static let routes: [String: String] = Dictionary(
        uniqueKeysWithValues: [
            "west-end-slab-r1", "west-end-slab-r2", "west-end-slab-r3",
            "west-end-cave-r1", "west-end-cave-r2", "west-end-cave-r3",
            "west-end-comp-r1", "west-end-comp-r2", "west-end-comp-r3",
            "newstead-island-r1", "newstead-island-r2", "newstead-island-r3",
            "newstead-steep-r1", "newstead-steep-r2", "newstead-steep-r3",
            "newstead-vertical-r1", "newstead-vertical-r2", "newstead-vertical-r3",
            "enoggera-slab-r1", "enoggera-slab-r2", "enoggera-slab-r3",
            "enoggera-cave-r1", "enoggera-cave-r2", "enoggera-cave-r3",
            "enoggera-main-r1", "enoggera-main-r2", "enoggera-main-r3"
        ].enumerated().map { index, key in
            (key, String(format: "30000000-0000-4000-8000-%012d", index + 1))
        }
    )

    static let betaLinks: [String: String] = [
        "beta-west-end-1-a": "40000000-0000-4000-8000-000000000001",
        "beta-west-end-1-b": "40000000-0000-4000-8000-000000000002",
        "beta-west-end-1-broken": "40000000-0000-4000-8000-000000000003",
        "beta-west-end-1-hidden": "40000000-0000-4000-8000-000000000004",
        "beta-west-end-cave-1": "40000000-0000-4000-8000-000000000005",
        "beta-newstead-1": "40000000-0000-4000-8000-000000000006"
    ]
}
