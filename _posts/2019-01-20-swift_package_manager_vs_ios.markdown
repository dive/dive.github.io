---
layout: default
title:  "Swift Package Manager builds iOS frameworks :nope:"
date:   2019-01-20 13:02:00 +0000
github_comments_issueid: "1"
categories: swift-package-manager ios
excerpt_separator: <!--more-->
---

Swift Package Manager doesn't work with iOS. Probably, that's all you can say about the current state of SPM, but insomnia forced me to extend the answer to the following essay.

### TL;DR

- Yes, you can build iOS frameworks with Swift Package Manager;
- Yes, you can adjust settings via `.xcconfig` and reuse generated `.xcodeproj` in a real iOS application without 3rd party tools to parse a project structure, scripts on Ruby, etc.;
- Yes, you can use `swift build` to build your package but only as a library (though, with some additional limitations);
- No, you can not use `swift test` because you have to spawn a simulator to run them.
<!--more-->

## Current State of Swift Package Manager
* * *

iOS support is a hot topic in [Swift Package Manager][spm] community, and from time to time someone raises this question again, but the reaction can be summarised to the following comments ([full thread][spm_roadmap] on forums.swift.org):

[@Rick Ballard][rick_ballard]
> I think that this will be *best provided by native IDE integration*. However, in the meantime, I'd welcome contributions to help improve Xcode's project generation support.

[@Adrian Kashivskyy][adrian_kashivskyy]
> The last thing I want from a platform-agnostic open-source package manager is built-in integration with a single-platform commercial closed-source IDE. :confused:
> I think this should be done independently by DT team, without any special favouritism by SPM.

And you know what? I agree with these statements. Especially after some researches. In general, SPM is a very 'young' and inflexible project. There are a lot of limitations, especially around `generate-xcodeproj` options of `swift package` tool, and it is understandable. Swift is a language, and all related tools should be platform-agnostic as much as possible. Yeah, iOS is the biggest Swift consumer, and Apple contributes to Swift mostly because of iOS. But. It's almost impossible to grow Swift to a mature technology if you're limited and restricted by Xcode / iOS specific things / etc. And, it seems, this is the primary goal for Swift. Just be a language. The fate of Objective C is a good example of why Apple and Swift's community are trying to be agnostic. They are trying to build something big, and lack of iOS support is the price (among many others) at the moment. :kiss:

Anyway, we have exciting news about SPM and iOS friendship. [SE-0236: Package Manager Platform Deployment Settings][SE-0236] is accepted with some modifications. And the implementation of this proposal will help a lot to move forward in case of iOS. The base goal is clear and straightforward:

> Packages should be able to declare the minimum required platform deployment target version. SwiftPM currently uses a hardcoded value for the macOS deployment target. This creates friction for packages which want to use APIs that were introduced after the hardcoded deployment target version.

Why will it not solve the problem with iOS support at all? Just read the "[This proposal doesn't handle these problems][SE-0236_proposal]" section.

## Is it possible to build an iOS framework with SPM? Yes! Yes, it is!
* * *

So. If you try to search for solutions to build iOS frameworks with SPM on DuckDuckGo, you will find some instructions ([1][how_to_build_1], [2][how_to_build_2]). But all of them have this step that I hate: `sudo gem install xcodeproj` :disgusting:. Can we do better? Let's try.

First of all, let's generate a template:

```bash
swift package init --type library
```

Now we have to convince SPM that we want an iOS project when it generates `xcodeproj`. How? With `xcconfig`, of course. Create a file `ios.xcconfig` and put it to `./Sources` folder. For example, let's start with a basic version:

```bash
SDKROOT = iphoneos
SUPPORTED_PLATFORMS = iphonesimulator iphoneos
IPHONEOS_DEPLOYMENT_TARGET = 12.0

ARCHS = $(ARCHS_STANDARD)
VALID_ARCHS = $(ARCHS_STANDARD)

VALIDATE_PRODUCT = YES
LD_RUNPATH_SEARCH_PATHS = $(inherited) @executable_path/Frameworks
TARGETED_DEVICE_FAMILY = 1, 2
```

Looks good. Let's see what SPM thinks about it:

```bash
swift package generate-xcodeproj --xcconfig-overrides ./Sources/ios.xcconfig
```

Did not know about `xcconfig-overrides`? Me either. It's a hidden and undocumented feature ([commit][xcconfig_overrides_commit]), thanks to [@Daniel Dunbar][daniel_dunbar]! Time to ask Xcode what it thinks about it.

![Xcode Build Results](/assets/images/2019-01-20-swift_package_manager_vs_ios/xcode_spm_build_results.png ){:class="img-responsive"}

It works! Let's celebrate! But nope. We're not on Medium, so let's try to dig deeper. Let's check how the 'Unit Tests' target works, for example:

```sh
spm-tutorial/Tests/spm-tutorialTests/XCTestManifests.swift:4:28: error: use of undeclared type 'XCTestCaseEntry'
public func allTests() -> [XCTestCaseEntry] {
                           ^~~~~~~~~~~~~~~
```

It doesn't. Due to this strange and suspicious `XCTestCaseEntry`. What is this? According to the [swift-corelibs-xctest][swift_corelibs_xctest_xctestcaseentry] source code:

> This is a compound type used by `XCTMain` to represent tests to run. It combines an
> `XCTestCase` subclass type with the list of test case methods to invoke on the class.

And the `typealias` looks like this:

```swift
public typealias XCTestCaseEntry = (testCaseClass: XCTestCase.Type, allTests: [(String, XCTestCaseClosure)])
```

Why it doesn't work? The same:

> CoreLibs XCTest only supports desktop platforms

Thanks to [@larryonoff][larryonoff] and [his work][larryonoff_pullrequest] on multi-platform support. But it's still impossible to use it for our needs. You can join this [Add Unit Testing Infrastructure][add_unit_testing_infrastructure] thread if you want to learn more about the current state of `swift-corelibs-xctest`. We will skip this topic and apply the fix to `XCTestManifests.swift`:

```swift
import XCTest

#if !os(macOS) && !os(iOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(spm_tutorialTests.allTests),
    ]
}
#endif
```

See this `&& !os(iOS)`? It's enough to continue our journey. Run Tests again and... We got what we need.

![Xcode Test Results](/assets/images/2019-01-20-swift_package_manager_vs_ios/xcode_spm_test_results.png ){:class="img-responsive"}

Then I created a simple iOS `ExampleApp` and added the generated `xcodeproj` as a dependency. Of course, I've added some iOS specific code to the framework:

```swift
import UIKit

public final class FrameworkPackage {
    public init () { }
    public func randomColor() -> UIColor {
        return UIColor.random
    }
}

public extension UIColor {
    public static var random: UIColor {
        return UIColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1)
    }
}
```

And then reuse it from the example app:

```swift
import UIKit
import class ios_framework_package.FrameworkPackage

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = FrameworkPackage().randomColor()
    }
    
    @IBAction func pressed(_ button: UIButton) {
        self.view.backgroundColor = FrameworkPackage().randomColor()
    }

}
```

The full example is available on [GitHub][spm-ios-example].
Thanks to `CLANG_MODULES_AUTOLINK`, all iOS frameworks will be linked automatically. I didn't try more complex scenarios (when one iOS module depends on another, etc.) because it's not my goal at the moment. But in general, it just works with some limitations. SPM doesn't set up our `xcconfig` for some targets, and you have to include the SPM-generated `.xcodeproj` to your `.xcodeproj`, but all these tradeoffs seem reasonable for this research and our current goal.

## Back to Swift Package Manager
* * *

See. We can do better 🥳. But we forgot about SPM during this Xcode journey. Let's close our fancy dark-themed Xcode, open Terminal and run `swift build` for our iOS'ish package (I'm going to use the package from the [example project](https://github.com/dive/spm-ios-example) mentioned above):

```bash
Compile Swift Module 'ios_framework_package' (1 sources)
./spm-ios-example/ios-framework-package/Sources/ios-framework-package/ios_framework_package.swift:1:8: error: no such module 'UIKit'
import UIKit
       ^
error: terminated(1): /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-build-tool -f./spm-ios-example/ios-framework-package/.build/debug.yaml main output: ...
```

Okay. `no such module 'UIKit'`. Can we do better? Doubt it. But let's try. First of all, we have to know where SPM gets all these environment variables, we can ask it with `swift build --verbose`:

```bash
xcrun --sdk macosx --show-sdk-path
xcrun --sdk macosx --show-sdk-platform-path
xcrun --find clang
xcrun --sdk macosx --find xctest
sandbox-exec -p '(version 1)
```

Nice. No magic and jigsaws. Let's try to change some `swiftc` options to build the project against proper `sdk` and `target`:

```bash
swift build \
	-Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" \
	-Xswiftc "-target" -Xswiftc "x86_64-apple-ios12.1-simulator"
```

Looks better. We built the binary:

```bash
Compile Swift Module 'ios_framework_package' (1 sources)
```

Let's make some inspections, just to be sure that everything is fine:

```bash
$ lipo -archs .build/x86_64-apple-macosx10.10/debug/ios_framework_package.build/ios_framework_package.swift.o 
x86_64
```

```bash
$ nm -extern-only -defined-only -just-symbol-name .build/x86_64-apple-macosx10.10/debug/ios_framework_package.build/ios_framework_package.swift.o 
_$S12CoreGraphics7CGFloatVACSBAAWL
_$S12CoreGraphics7CGFloatVACSBAAWl
_$S12CoreGraphics7CGFloatVACSLAAWL
_$S12CoreGraphics7CGFloatVACSLAAWl
_$S21ios_framework_package16FrameworkPackageC11randomColorSo7UIColorCyF
_$S21ios_framework_package16FrameworkPackageCACycfC
_$S21ios_framework_package16FrameworkPackageCACycfc
_$S21ios_framework_package16FrameworkPackageCMa
_$S21ios_framework_package16FrameworkPackageCMm
_$S21ios_framework_package16FrameworkPackageCMn
_$S21ios_framework_package16FrameworkPackageCN
_$S21ios_framework_package16FrameworkPackageCfD
_$S21ios_framework_package16FrameworkPackageCfd
_$S21ios_framework_packageMXM
_$SSo7UIColorC21ios_framework_packageE6randomABvgZ
_$SSo7UIColorC3red5green4blue5alphaAB12CoreGraphics7CGFloatV_A3ItcfC
_$SSo7UIColorC3red5green4blue5alphaAB12CoreGraphics7CGFloatV_A3ItcfcTO
_$SSo7UIColorCML
_$SSo7UIColorCMa
___swift_reflection_version
__swift_FORCE_LOAD_$_swiftCoreFoundation_$_ios_framework_package
__swift_FORCE_LOAD_$_swiftCoreGraphics_$_ios_framework_package
__swift_FORCE_LOAD_$_swiftCoreImage_$_ios_framework_package
__swift_FORCE_LOAD_$_swiftDarwin_$_ios_framework_package
__swift_FORCE_LOAD_$_swiftDispatch_$_ios_framework_package
__swift_FORCE_LOAD_$_swiftFoundation_$_ios_framework_package
__swift_FORCE_LOAD_$_swiftMetal_$_ios_framework_package
__swift_FORCE_LOAD_$_swiftObjectiveC_$_ios_framework_package
__swift_FORCE_LOAD_$_swiftQuartzCore_$_ios_framework_package
__swift_FORCE_LOAD_$_swiftUIKit_$_ios_framework_package
_symbolic ____ 21ios_framework_package16FrameworkPackageC
```

`lipo` is a bit useless in this case because we were building for a simulator, but `nm` shows everything we need to know - iOS frameworks symbols are available. Unfortunately, `swift build` doesn't produce `.framework` by default. I think it's doable even in this case but let's postpone it 'till next time'.

## Epilogue: swift test
* * *

And the final call. We already have one unit-test for our package, it uses `UIKit`, and I would mark this experiment as successful if we can run the test target with `swift test`. It's almost impossible, though, because usually, unit-tests for simulator have to spawn to a simulator process. I do not think that it's even possible for _an actual_ iOS project. Anyway.

```bash
swift test \
	-Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" \
	-Xswiftc "-target" -Xswiftc "x86_64-apple-ios12.1-simulator"
```

And we face another problem. `.xctest` bundle is compiled but `xctest` tool is confused with search paths:

```bash
Compile Swift Module 'ios_framework_package' (1 sources)
Compile Swift Module 'ios_framework_packageTests' (2 sources)
Linking ./.build/x86_64-apple-macosx10.10/debug/ios-framework-packagePackageTests.xctest/Contents/MacOS/ios-framework-packagePackageTests
xctest[77129:8746476] The bundle “ios-framework-packagePackageTests.xctest” couldn’t be loaded because it is damaged or missing necessary resources. Try reinstalling the bundle.
xctest[77129:8746476](dlopen_preflight(.build/x86_64-apple-macosx10.10/debug/ios-framework-packagePackageTests.xctest/Contents/MacOS/ios-framework-packagePackageTests): 

  **Library not loaded: /System/Library/Frameworks/UIKit.framework/UIKit**

  Referenced from: .build/x86_64-apple-macosx10.10/debug/ios-framework-packagePackageTests.xctest/Contents/MacOS/ios-framework-packagePackageTests
  Reason: image not found)
```

Likely, `swift build & test` produce beneficial debug information and store it in `.build/debug.yaml` with all passed options and arguments. There are no differences with the options for a module itself, so it's time for our command line friends again:

```bash
$ otool -L .build/debug/ios-framework-packagePackageTests.xctest/Contents/MacOS/ios-framework-packagePackageTests
  /usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
  /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1252.200.5)
======
  /System/Library/Frameworks/UIKit.framework/UIKit (compatibility version 1.0.0, current version 61000.0.0)
======
  @rpath/XCTest.framework/Versions/A/XCTest (compatibility version 1.0.0, current version 14460.20.0)
  @rpath/libswiftCore.dylib (compatibility version 1.0.0, current version 1000.11.42)
  @rpath/libswiftCoreFoundation.dylib (compatibility version 1.0.0, current version 1000.11.42)
  @rpath/libswiftCoreGraphics.dylib (compatibility version 1.0.0, current version 1000.11.42)
  @rpath/libswiftCoreImage.dylib (compatibility version 1.0.0, current version 1000.11.42)
  @rpath/libswiftDarwin.dylib (compatibility version 1.0.0, current version 1000.11.42)
  @rpath/libswiftDispatch.dylib (compatibility version 1.0.0, current version 1000.11.42)
  @rpath/libswiftFoundation.dylib (compatibility version 1.0.0, current version 1000.11.42)
  @rpath/libswiftMetal.dylib (compatibility version 1.0.0, current version 1000.11.42)
  @rpath/libswiftObjectiveC.dylib (compatibility version 1.0.0, current version 1000.11.42)
  @rpath/libswiftQuartzCore.dylib (compatibility version 1.0.0, current version 1000.11.42)
======
  @rpath/libswiftUIKit.dylib (compatibility version 1.0.0, current version 1000.11.42)
======
  @rpath/libswiftXCTest.dylib (compatibility version 1.0.0, current version 1000.11.42)
```

As you can see, for some reasons, it tries to link `UIKit.framework` twice: 

- via `/System/Library/Frameworks` path 
- and via expected `@rpath/libswiftUIKit.dylib`. 

Let's check the information from the module itself with `otool`, to be sure that `load` describes the correct framework to link:

```bash
$ otool -l .build/debug/ios_framework_package.build/ios_framework_package.swift.o
...
Load command 6
     cmd LC_LINKER_OPTION
 cmdsize 32
   count 2
  string #1 -framework
  string #2 UIKit
...
```

Seems correct to me. To remove the confusion, let's pass the linking option directly with `-Xswiftc "-lswiftUIKit"`:

```bash
swift test --verbose \
	-Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" \
	-Xswiftc "-target" -Xswiftc "x86_64-apple-ios12.1-simulator" \
	-Xswiftc "-lswiftUIKit"
```

```bash
xctest[18838:9855653] The bundle “ios-framework-packagePackageTests.xctest” couldn’t be loaded because it is damaged or missing necessary resources. Try reinstalling the bundle.
xctest[18838:9855653](dlopen_preflight(./ios-example/ios-framework-package/.build/x86_64-apple-macosx10.10/debug/ios-framework-packagePackageTests.xctest/Contents/MacOS/ios-framework-packagePackageTests): 

	**Library not loaded: @rpath/libswiftUIKit.dylib**
	...
  	Reason: no suitable image found.  Did find:
	/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator/libswiftUIKit.dylib: mach-o, 
	
	**but built for simulator (not macOS))**
```

This is the end, my only friend. We can link proper frameworks with minimum efforts, but it's impossible to run these tests for iOS device or simulator without SPM support. It seems that even `xcrun` with `xctest` cannot handle it, we need `xcodebuild` assistance here. Enough these weird logs and useless speeches, let's summarise.

## Summary
* * *

Thanks for reading, first of all! And what did we learn?

- We can use SPM in sporadic cases for iOS just for integration, thanks to `.xcconfig`;
- Future of iOS and SPM friendship is foggy even with this [SE-0236][SE-0236] proposal;
- Swift `build` and `test` helpers are useless for us without iOS-specific features and full Xcode support. And it's unlikely to happen. Of course, SPM can be integrated on top of Xcode by Xcode team. For example, they will extend `xcodebuild` functionality. But it will be a different story which partly concerns SPM.

About SPM. I think that it's doable in general, and we can improve SPM to support any platform you want. My best guess at the moment is to introduce pipeline plugins for SPM. Where you can transfer the control flow to a separate tool with expected input and output. Something like Xcode custom build phases but smarter and more flexible. It will allow SPM to be platform-agnostic as now, but Xcode team can create a plugin for the whole iOS flow support. Or Uber. Or Google. Or me. Whatever.

Stay tuned and hydrated!

[spm]: 					https://swift.org/package-manager/
[spm_roadmap]: 			https://forums.swift.org/t/spm-roadmap/6870
[SE-0236]: 				https://forums.swift.org/t/accepted-with-modifications-se-0236-package-manager-platform-deployment-settings/18420
[SE-0236_proposal]:	https://github.com/apple/swift-evolution/blob/master/proposals/0236-package-manager-platform-deployment-settings.md
[rick_ballard]: 		https://forums.swift.org/u/rballard
[adrian_kashivskyy]:	https://forums.swift.org/u/akashivskyy
[how_to_build_1]: 		https://github.com/j-channings/swift-package-manager-ios 
[how_to_build_2]:		https://www.ralfebert.de/ios-examples/xcode/ios-dependency-management-with-swift-package-manager/
[xcconfig_overrides_commit]:	https://github.com/apple/swift-package-manager/commit/713a3e603e6682fe431074617343eb05852d10c5
[daniel_dunbar]:		https://github.com/ddunbar
[swift_corelibs_xctest_xctestcaseentry]:	https://github.com/apple/swift-corelibs-xctest/blob/237d97cadbc3c51d575c705bf8e4d8456a12827a/Sources/XCTest/Public/XCTestCase.swift#L24
[larryonoff]: 			https://github.com/larryonoff 
[larryonoff_pullrequest]:	https://github.com/apple/swift-corelibs-xctest/pull/176
[add_unit_testing_infrastructure]:	https://github.com/apple/swift-corelibs-xctest/pull/61
[spm-ios-example]:		https://github.com/dive/spm-ios-example