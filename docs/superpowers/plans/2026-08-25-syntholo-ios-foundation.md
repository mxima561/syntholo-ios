# Syntholo iOS Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a reproducible, tested native iOS project with Syntholo’s professional visual foundation, four-tab application shell, environment configuration, and continuous integration.

**Architecture:** XcodeGen defines one SwiftUI application target plus unit and UI test targets. App-level state uses Swift Observation and typed routes. A small design-system layer owns color, type, spacing, shape, and reusable controls. Environment values come from checked-in `.xcconfig` files with secret overrides excluded from Git. This slice intentionally has no Firebase or OpenAI runtime dependency.

**Tech Stack:** Xcode 26.6, Swift 6, SwiftUI, Observation, XCTest, XcodeGen, xcconfig, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md` (Book I, DEC-*, Phase 0). Historical PRD sections 3, 4, 11, 15, 16, 22, 28, and 29 are background only.

## Global Constraints

- Deployment target is iOS 17.0 and supported destination is iPhone.
- Use bundle identifier `com.syntholo.ios` and product name `Syntholo`.
- Use system typography, semantic colors, SF Symbols, and restrained motion; do not recreate Mimo’s proprietary assets or layout.
- Learner-facing copy belongs in `Syntholo/Resources/Localizable.xcstrings`.
- Every tappable control has a minimum 44-by-44-point hit target and an accessibility label.
- Do not introduce production networking, authentication, purchases, or credentials in this slice.
- Run commands from the repository root.

---

## File and Responsibility Map

```text
Brewfile                                  Local project generator dependency
project.yml                               Deterministic Xcode project definition
Config/Shared.xcconfig                    Common build identity and Swift settings
Config/Debug.xcconfig                     Development environment selection
Config/Release.xcconfig                   Production environment selection
Syntholo/App/SyntholoApp.swift            Application entry point
Syntholo/App/AppEnvironment.swift         Typed build-environment parsing
Syntholo/App/AppRoute.swift               Four primary destinations
Syntholo/App/AppRouter.swift              Observable navigation state
Syntholo/App/RootView.swift               Tab shell and destination composition
Syntholo/DesignSystem/Tokens.swift         Colors, spacing, radii, animation policy
Syntholo/DesignSystem/Typography.swift     Semantic text styles
Syntholo/DesignSystem/PrimaryButton.swift  Reusable primary action
Syntholo/Features/*/*HomeView.swift        Temporary feature boundaries, not mock products
Syntholo/Resources/Localizable.xcstrings   Localized shell strings
Syntholo/Resources/Assets.xcassets         App tint and App Store icon slots
SyntholoTests/*                            Unit tests
SyntholoUITests/AppShellUITests.swift      Launch and tab navigation smoke tests
scripts/bootstrap.sh                       Install check and project generation
scripts/test.sh                            Reproducible simulator test command
.github/workflows/ios.yml                  CI build and test
```

## Task 1: Define the Reproducible Xcode Project

**Files:**
- Create: `Brewfile`
- Create: `project.yml`
- Create: `Config/Shared.xcconfig`
- Create: `Config/Debug.xcconfig`
- Create: `Config/Release.xcconfig`
- Create: `scripts/bootstrap.sh`
- Modify: `.gitignore`

- [ ] Add the generator dependency to `Brewfile`:

```ruby
brew "xcodegen"
```

- [ ] Add `project.yml` with explicit targets and settings:

```yaml
name: Syntholo
options:
  bundleIdPrefix: com.syntholo
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "26.6"
configs:
  Debug: debug
  Release: release
settings:
  base:
    SWIFT_VERSION: "6.0"
    TARGETED_DEVICE_FAMILY: "1"
    CODE_SIGN_STYLE: Automatic
targets:
  Syntholo:
    type: application
    platform: iOS
    sources:
      - path: Syntholo
    configFiles:
      Debug: Config/Debug.xcconfig
      Release: Config/Release.xcconfig
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.syntholo.ios
        INFOPLIST_KEY_CFBundleDisplayName: Syntholo
        INFOPLIST_KEY_UILaunchScreen_Generation: true
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: true
        GENERATE_INFOPLIST_FILE: true
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
    scheme:
      testTargets:
        - SyntholoTests
        - SyntholoUITests
  SyntholoTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: SyntholoTests
    dependencies:
      - target: Syntholo
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.syntholo.ios.tests
        GENERATE_INFOPLIST_FILE: true
  SyntholoUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: SyntholoUITests
    dependencies:
      - target: Syntholo
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.syntholo.ios.uitests
        GENERATE_INFOPLIST_FILE: true
```

- [ ] Add configuration values:

```xcconfig
// Config/Shared.xcconfig
MARKETING_VERSION = 0.1.0
CURRENT_PROJECT_VERSION = 1
SWIFT_STRICT_CONCURRENCY = complete
```

```xcconfig
// Config/Debug.xcconfig
#include "Shared.xcconfig"
SYNTHOLO_ENV = development
```

```xcconfig
// Config/Release.xcconfig
#include "Shared.xcconfig"
SYNTHOLO_ENV = production
SWIFT_COMPILATION_MODE = wholemodule
```

- [ ] Add `scripts/bootstrap.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required. Run: brew bundle"
  exit 1
fi

xcodegen generate
echo "Generated Syntholo.xcodeproj"
```

- [ ] Add `Syntholo.xcodeproj/`, `DerivedData/`, and `Config/Secrets.xcconfig` to `.gitignore`; make the script executable.
- [ ] Run `brew bundle`, then `./scripts/bootstrap.sh`.
- [ ] Expected: `Syntholo.xcodeproj` is generated and Git ignores it.
- [ ] Commit:

```bash
git add Brewfile project.yml Config scripts/bootstrap.sh .gitignore
git commit -m "build: define reproducible iOS project"
```

## Task 2: Add the App Environment Contract

**Files:**
- Create: `Syntholo/App/AppEnvironment.swift`
- Create: `SyntholoTests/AppEnvironmentTests.swift`

- [ ] Write the failing unit tests:

```swift
import XCTest
@testable import Syntholo

final class AppEnvironmentTests: XCTestCase {
    func testKnownBuildValuesParse() {
        XCTAssertEqual(AppEnvironment(buildValue: "development"), .development)
        XCTAssertEqual(AppEnvironment(buildValue: "staging"), .staging)
        XCTAssertEqual(AppEnvironment(buildValue: "production"), .production)
    }

    func testUnknownBuildValueFallsBackToDevelopment() {
        XCTAssertEqual(AppEnvironment(buildValue: "preview"), .development)
        XCTAssertEqual(AppEnvironment(buildValue: nil), .development)
    }
}
```

- [ ] Generate the project and run:

```bash
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SyntholoTests/AppEnvironmentTests
```

- [ ] Expected: compilation fails because `AppEnvironment` does not exist.
- [ ] Implement the smallest contract:

```swift
import Foundation

enum AppEnvironment: String, Equatable, Sendable {
    case development
    case staging
    case production

    init(buildValue: String?) {
        self = AppEnvironment(rawValue: buildValue ?? "") ?? .development
    }

    static var current: AppEnvironment {
        AppEnvironment(
            buildValue: Bundle.main.object(
                forInfoDictionaryKey: "SYNTHOLO_ENV"
            ) as? String
        )
    }
}
```

- [ ] Add `INFOPLIST_KEY_SYNTHOLO_ENV: $(SYNTHOLO_ENV)` under the app target’s base settings in `project.yml`.
- [ ] Regenerate and rerun the focused test. Expected: pass.
- [ ] Commit:

```bash
git add project.yml Syntholo/App/AppEnvironment.swift SyntholoTests/AppEnvironmentTests.swift
git commit -m "feat: add typed app environment"
```

## Task 3: Define Typed Navigation State

**Files:**
- Create: `Syntholo/App/AppRoute.swift`
- Create: `Syntholo/App/AppRouter.swift`
- Create: `SyntholoTests/AppRouterTests.swift`

- [ ] Write the failing tests:

```swift
import XCTest
@testable import Syntholo

@MainActor
final class AppRouterTests: XCTestCase {
    func testInitialRouteIsLearn() {
        XCTAssertEqual(AppRouter().selectedRoute, .learn)
    }

    func testSelectingAnotherRouteUpdatesState() {
        let router = AppRouter()
        router.select(.practice)
        XCTAssertEqual(router.selectedRoute, .practice)
    }
}
```

- [ ] Run the focused test. Expected: compilation fails because router types do not exist.
- [ ] Implement route and router:

```swift
// AppRoute.swift
enum AppRoute: String, CaseIterable, Hashable, Sendable {
    case learn
    case practice
    case social
    case profile
}
```

```swift
// AppRouter.swift
import Observation

@MainActor
@Observable
final class AppRouter {
    private(set) var selectedRoute: AppRoute = .learn

    func select(_ route: AppRoute) {
        selectedRoute = route
    }
}
```

- [ ] Rerun the focused test. Expected: pass.
- [ ] Commit:

```bash
git add Syntholo/App SyntholoTests/AppRouterTests.swift
git commit -m "feat: add typed app navigation"
```

## Task 4: Establish the Visual Design Tokens

**Files:**
- Create: `Syntholo/DesignSystem/Tokens.swift`
- Create: `Syntholo/DesignSystem/Typography.swift`
- Create: `SyntholoTests/DesignTokenTests.swift`

- [ ] Write contract tests for stable numeric tokens:

```swift
import XCTest
@testable import Syntholo

final class DesignTokenTests: XCTestCase {
    func testSpacingScaleIsStrictlyIncreasing() {
        let values = [Space.xs, .sm, .md, .lg, .xl]
        XCTAssertEqual(values, values.sorted())
        XCTAssertEqual(Set(values).count, values.count)
    }

    func testMinimumControlHeightMeetsAccessibilityTarget() {
        XCTAssertGreaterThanOrEqual(Layout.minimumControlHeight, 44)
    }
}
```

- [ ] Run the focused test. Expected: compilation fails because the tokens do not exist.
- [ ] Implement the token layer:

```swift
import SwiftUI

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let control: CGFloat = 14
    static let card: CGFloat = 20
}

enum Layout {
    static let minimumControlHeight: CGFloat = 48
    static let pageInset: CGFloat = 20
}

enum SyntholoColor {
    static let ink = Color.primary
    static let secondaryInk = Color.secondary
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let accent = Color.accentColor
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
}
```

```swift
import SwiftUI

enum SyntholoTextStyle {
    static let pageTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let sectionTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let body = Font.body
    static let label = Font.callout.weight(.semibold)
    static let caption = Font.caption
}
```

- [ ] Rerun the focused test. Expected: pass.
- [ ] Commit:

```bash
git add Syntholo/DesignSystem SyntholoTests/DesignTokenTests.swift
git commit -m "feat: establish Syntholo design tokens"
```

## Task 5: Build and Test the Primary Button

**Files:**
- Create: `Syntholo/DesignSystem/PrimaryButton.swift`
- Create: `SyntholoTests/PrimaryButtonTests.swift`

- [ ] Write a test for the button’s pure style configuration:

```swift
import XCTest
@testable import Syntholo

final class PrimaryButtonTests: XCTestCase {
    func testConfigurationExposesAccessibleHeight() {
        XCTAssertEqual(PrimaryButtonConfiguration.default.minimumHeight, 48)
    }
}
```

- [ ] Run the test. Expected: compilation fails because configuration does not exist.
- [ ] Implement the configuration and reusable control:

```swift
import SwiftUI

struct PrimaryButtonConfiguration: Equatable, Sendable {
    let minimumHeight: CGFloat
    static let `default` = PrimaryButtonConfiguration(minimumHeight: 48)
}

struct PrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void
    var isEnabled = true
    var configuration = PrimaryButtonConfiguration.default

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SyntholoTextStyle.label)
                .frame(maxWidth: .infinity)
                .frame(minHeight: configuration.minimumHeight)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: Radius.control))
        .disabled(!isEnabled)
        .accessibilityAddTraits(.isButton)
    }
}
```

- [ ] Rerun the test. Expected: pass.
- [ ] Commit:

```bash
git add Syntholo/DesignSystem/PrimaryButton.swift SyntholoTests/PrimaryButtonTests.swift
git commit -m "feat: add accessible primary action"
```

## Task 6: Create Feature Boundaries and the Four-Tab Shell

**Files:**
- Create: `Syntholo/Features/Learn/LearnHomeView.swift`
- Create: `Syntholo/Features/Practice/PracticeHomeView.swift`
- Create: `Syntholo/Features/Social/SocialHomeView.swift`
- Create: `Syntholo/Features/Profile/ProfileHomeView.swift`
- Create: `Syntholo/App/RootView.swift`
- Create: `Syntholo/App/SyntholoApp.swift`

- [ ] Add a reusable page skeleton inside each feature file, using that feature’s title and system image. The Learn implementation must be:

```swift
import SwiftUI

struct LearnHomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Label("Your learning campus", systemImage: "graduationcap.fill")
                        .font(SyntholoTextStyle.pageTitle)
                    Text("Your next lesson and path progress will appear here.")
                        .font(SyntholoTextStyle.body)
                        .foregroundStyle(SyntholoColor.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Layout.pageInset)
            }
            .background(SyntholoColor.canvas)
            .navigationTitle("Learn")
        }
    }
}
```

- [ ] Create equivalent boundaries for Practice (`brain.head.profile`), Social (`person.2.fill`), and Profile (`person.crop.circle`) with honest “coming in the next product slice” copy.
- [ ] Implement the shell:

```swift
import SwiftUI

struct RootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        TabView(
            selection: Binding(
                get: { router.selectedRoute },
                set: { router.select($0) }
            )
        ) {
            LearnHomeView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
                .tag(AppRoute.learn)
            PracticeHomeView()
                .tabItem { Label("Practice", systemImage: "brain.head.profile") }
                .tag(AppRoute.practice)
            SocialHomeView()
                .tabItem { Label("Social", systemImage: "person.2.fill") }
                .tag(AppRoute.social)
            ProfileHomeView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppRoute.profile)
        }
        .tint(SyntholoColor.accent)
    }
}
```

- [ ] Add the app entry point:

```swift
import SwiftUI

@main
struct SyntholoApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView(router: router)
        }
    }
}
```

- [ ] Run `xcodebuild build -project Syntholo.xcodeproj -scheme Syntholo -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`. Expected: build succeeds.
- [ ] Commit:

```bash
git add Syntholo/App Syntholo/Features
git commit -m "feat: build four-tab application shell"
```

## Task 7: Add Localized Shell Copy and Asset Catalogs

**Files:**
- Create: `Syntholo/Resources/Localizable.xcstrings`
- Create: `Syntholo/Resources/Assets.xcassets/Contents.json`
- Create: `Syntholo/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `Syntholo/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] Create a valid String Catalog containing every literal learner-facing shell string from Task 6 with English source values.
- [ ] Create `AccentColor.colorset` with light sRGB `0.16, 0.35, 0.92` and dark sRGB `0.42, 0.59, 1.00` appearances.
- [ ] Create the Xcode 1024-by-1024 universal App Store icon slot without committing a temporary icon image.
- [ ] Run:

```bash
xcodebuild build -project Syntholo.xcodeproj -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- [ ] Expected: the asset compiler and String Catalog compiler finish without warnings about malformed resources.
- [ ] Commit:

```bash
git add Syntholo/Resources
git commit -m "feat: add localized resources and brand slots"
```

## Task 8: Add UI Smoke Tests for Launch and Navigation

**Files:**
- Create: `SyntholoUITests/AppShellUITests.swift`

- [ ] Write the UI tests:

```swift
import XCTest

final class AppShellUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testLaunchesOnLearnAndShowsEveryPrimaryTab() {
        XCTAssertTrue(app.tabBars.buttons["Learn"].exists)
        XCTAssertTrue(app.tabBars.buttons["Practice"].exists)
        XCTAssertTrue(app.tabBars.buttons["Social"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
        XCTAssertTrue(app.navigationBars["Learn"].exists)
    }

    func testEveryPrimaryTabOpensItsDestination() {
        for title in ["Practice", "Social", "Profile", "Learn"] {
            app.tabBars.buttons[title].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 2))
        }
    }
}
```

- [ ] Run:

```bash
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SyntholoUITests/AppShellUITests
```

- [ ] Expected: both UI tests pass.
- [ ] Commit:

```bash
git add SyntholoUITests/AppShellUITests.swift
git commit -m "test: cover application shell navigation"
```

## Task 9: Add a Reproducible Test Script and CI

**Files:**
- Create: `scripts/test.sh`
- Create: `.github/workflows/ios.yml`

- [ ] Add `scripts/test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

./scripts/bootstrap.sh
xcodebuild test \
  -project Syntholo.xcodeproj \
  -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

- [ ] Add the CI workflow:

```yaml
name: iOS
on:
  pull_request:
  push:
    branches: [main]
jobs:
  test:
    runs-on: macos-26
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - name: Install XcodeGen
        run: brew bundle
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_26.6.app
      - name: Test
        run: ./scripts/test.sh
```

- [ ] Make `scripts/test.sh` executable and run it locally.
- [ ] Expected: all unit and UI tests pass.
- [ ] Commit:

```bash
git add scripts/test.sh .github/workflows/ios.yml
git commit -m "ci: test generated iOS project"
```

## Task 10: Verify Foundation Quality and PRD Traceability

**Files:**
- Create: `docs/quality/foundation-verification.md`
- Modify only if a check fails: files introduced in Tasks 1–9

- [ ] Run the complete suite twice to detect generation drift:

```bash
./scripts/test.sh
git status --short
./scripts/test.sh
git status --short
```

- [ ] Expected: both suites pass and both status checks show no generated or modified files.
- [ ] Run placeholder and secret scans:

```bash
rg -n 'TODO|TBD|FIXME|YOUR_API_KEY|sk-[A-Za-z0-9]' Syntholo Config scripts project.yml
```

- [ ] Expected: no matches.
- [ ] Use Accessibility Inspector on all four tabs at the largest accessibility text size with Reduce Motion enabled. Confirm tab labels remain visible, content scrolls, and no control is clipped.
- [ ] Record exact Xcode version, simulator runtime, commands, results, accessibility findings, and PRD coverage in `docs/quality/foundation-verification.md`.
- [ ] Confirm coverage of PRD sections 3 (iPhone/English), 4 (trust principles), 11 (primary navigation), 15 (professional visual foundation), 16 (SwiftUI architecture boundary), and 22 (accessibility baseline).
- [ ] Commit:

```bash
git add docs/quality/foundation-verification.md
git commit -m "docs: verify iOS foundation quality"
```

## Foundation Exit Criteria

- [ ] A clean clone can install XcodeGen, generate the project, and run the entire test suite from documented commands.
- [ ] The app launches on iOS 17 and current iOS simulators with Learn selected.
- [ ] Learn, Practice, Social, and Profile destinations are reachable and accessible.
- [ ] Design primitives reflect the approved light, professional-school direction without copied third-party design assets.
- [ ] No network SDK, credential, production dependency, warning, placeholder, or untracked generated file remains.
- [ ] The foundation verification record is committed and the next plan can build onboarding without restructuring the shell.
