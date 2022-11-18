# 🧱 Blocks

## Installation

```swift
let package = Package(
    …
    dependencies: [
        …
        .package(url: "https://github.com/dirtyhenry/blocks", branch: "main")
    ],
    targets: [
        …
        .Target(name: "…", dependencies: [
            …
            .product(name: "Blocks", package: "Blocks")
        ])
    ]
)
```

## License

[MIT](https://choosealicense.com/licenses/mit/)
