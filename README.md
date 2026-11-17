# TrainBoard

A live train departure board for the macOS desktop, built as a WidgetKit widget.

Track a train (say the 12:50 from London Waterloo that a friend is on) and your home station's board pins its arrival time at the top and picks it out in the list, so you know when it gets in without opening an app.

UK trains, with data from the [traini.ac API](https://traini.ac/developers).

![TrainBoard widget](docs/versions/widget-6-wider-system-colours.png)

## Download

**[Download TrainBoard for Mac](https://github.com/Joseph2475/trainboard-v1/releases/latest/download/TrainBoard.zip)** (macOS 15 or later)

1. Open the download and drag **TrainBoard V1** into Applications.
2. Open it once. This is also where you track a train.
3. Right-click the desktop, choose **Edit Widgets** and add **TrainBoard**. Right-click the widget and choose **Edit** to pick its station. Click the widget to open the app and track a train.

To update, download it again and replace the app in Applications.

## Releasing an update

```sh
scripts/release.sh 1.1
```

Builds, signs and notarizes the app and publishes it as a GitHub release, which the Download link above always points to. Needs the Developer ID certificate and the `trainboard` notary profile in this Mac's keychain.

## Build from source

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project TrainBoardV1.xcodeproj -scheme TrainBoardV1 -configuration Release -derivedDataPath build build
```

## Tests

```sh
xcodebuild -project TrainBoardV1.xcodeproj -scheme TrainBoardV1 -derivedDataPath build build-for-testing
xcrun xctest build/Build/Products/Debug/TrainBoardV1Tests.xctest
```

The tests run on saved API answers in `Tests/Fixtures`, and save a picture of every widget size to a `trainboard-renders` folder in the temp directory.

## Code

| File | What it does |
|---|---|
| `Shared/Trainiac.swift` | The API client and the shapes it returns |
| `Shared/TrackedTrain.swift` | The train being tracked, shared between app and widget |
| `Shared/BoardEntry.swift` | What one board shows at one moment |
| `Shared/BoardView.swift` | The board itself |
| `Widget/TrainBoardWidget.swift` | The widget, its timeline and station picker |
| `App/TrainBoardApp.swift` | The app window, where you pick a train to track |
| `scripts/release.sh` | Publishes a signed, notarized release for the Download link |

## How this was built

Built with AI coding tools, with me making the product and design calls. [PROCESS.md](PROCESS.md) is the running log: what I asked for, what the AI did, and where I disagreed with it and changed course.
