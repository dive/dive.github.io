+++
title = "Note: Xcode 10.2, macOS Mojave 10.14.4, iOS 12.1 and other betas"
publishDate = 2019-01-22T00:00:00+00:00
categories = ["apple", "ios", "xcode"]
draft = false
+++

## [Swift 5 for Xcode 10.2 beta](https://developer.apple.com/documentation/xcode%5Frelease%5Fnotes/xcode%5F10%5F2%5Frelease%5Fnotes/swift%5F5%5Frelease%5Fnotes%5Ffor%5Fxcode%5F10%5F2) {#swift-5-for-xcode-10-dot-2-beta}


### Swift {#swift}

First of all, the latest Xcode beta is bundled with the following Swift version:

```bash
Apple Swift version 5.0 (swiftlang-1001.0.45.7 clang-1001.0.37.7)
Target: x86_64-apple-darwin18.2.0
ABI version: 0.6
```

And let's start with the most exciting news:

> Swift apps no longer include dynamically linked libraries for the Swift standard library and Swift SDK overlays in build variants for devices running iOS 12.2, watchOS 5.2, and tvOS 12.2. As a result, Swift apps can be smaller when deployed for testing using TestFlight, or when thinning an app archive for local development distribution.

Application Binary Interface stability is coming! And this is excellent news. I think this is the on of the most significant issues at the moment with Swift. Not because of side-effects but due to previously failed promises. Anyway, I even know people who rewrite their Apple Watch extensions to Objective C to reduce the size of binary (something like 15MB vs ~1MB in Objective C). If you want to know more about the state of ABI follow the links: [Swift - ABI Dashboard](https://swift.org/abi-stability/#data-layout) and [Swift ABI Stability Manifesto](https://github.com/apple/swift/blob/master/docs/ABIStabilityManifesto.md).

> The `@dynamicCallable` attribute lets you call named types like you call functions using a simple syntactic sugar. The primary use case is dynamic language interoperability. ([SE-0216](https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md))

Example:

```swift
@dynamicCallable struct ToyCallable {
    func dynamicallyCall(withArguments: [Int]) {}
    func dynamicallyCall(withKeywordArguments: KeyValuePairs<String, Int>) {}
}

let x = ToyCallable()

x(1, 2, 3)
// Desugars to `x.dynamicallyCall(withArguments: [1, 2, 3])`

x(label: 1, 2)
// Desugars to `x.dynamicallyCall(withKeywordArguments: ["label": 1, "": 2])
```

This is a huge topic, and I have mixed feelings about the feature. So, it's better to read the ["What’s new in Swift 5.0"](https://www.hackingwithswift.com/articles/126/whats-new-in-swift-5-0) post from Paul Hudson if you want to learn more about what is coming.

> Swift 3 mode has been removed. Supported values for the `-swift-version` flag are 4, 4.2, and 5.

The time has come. Source compatibility with Swift 3 is no more. It was expected and announced with Swift 5 Roadmap, but still. I highly recommend you to refresh your memory with ["Swift 5.0 Release Process"](https://swift.org/blog/5-0-release-process/) because Swift 5 is almost here. Be ready.

> In Swift 5 mode, switches over enumerations that are declared in Objective-C or that come from system frameworks are required to handle **unknown cases** — cases that might be added in the future, or that may be defined privately in an Objective-C implementation file. Formally, Objective-C allows storing any value in an enumeration as long as it fits in the underlying type. These unknown cases can be handled by using the new `@unknown default` case, which still provides warnings if any known cases are omitted from the switch. They can also be handled using a normal `default` case.
>
> If you’ve defined your own enumeration in Objective-C and you don’t need clients to handle unknown cases, you can use the `NS_CLOSED_ENUM` macro instead of `NS_ENUM`. The Swift compiler recognizes this and doesn’t require switches to have a default case.
>
> In Swift 4 and 4.2 modes, you can still use `@unknown default`. If you omit it and an unknown value is passed into the switch, the program traps at runtime, which is the same behavior as Swift 4.2 in Xcode 10.1. ([SE-0192](https://github.com/apple/swift-evolution/blob/master/proposals/0192-non-exhaustive-enums.md))

It was, and it is a pain, especially if you prefer **no default** approach within \`switches\`. I remember the ugly workarounds for the new `.provisional` option of `UNAuthorizationOptions` property introduced in iOS 12. Now, with an unknown case it's much easier to handle such scenarios.


### Swift Package Manager {#swift-package-manager}

> Packages can now customize the minimum deployment target setting for Apple platforms when using the Swift 5 Package.swift tools-version. Building a package emits an error if any of the package dependencies of the package specify a minimum deployment target greater than the package’s own minimum deployment target. ([SE-0236](https://github.com/apple/swift-evolution/blob/master/proposals/0236-package-manager-platform-deployment-settings.md))

The most important news to me related to Swift Package Manager. Technically, this change can solve a lot of issues that prevent SPM to be useful in the iOS world. In my previous article "Swift Package Manager builds iOS frameworks" I tried to analyse the current state of SPM in the context of iOS development. And it seems that I have to reevaluate my thoughts and conclusions now.

There are some bad issues as well:

> Some projects might experience compile time regressions from previous releases;

<!--quoteend-->

> Swift command line projects crash on launch with “dyld: Library not loaded” errors.
> **Workaround**: Add a user-defined build setting `SWIFT_FORCE_STATIC_LINK_STDLIB=YES`.

There are a lot of resolved issues and other points in the [changelog](https://developer.apple.com/documentation/xcode%5Frelease%5Fnotes/xcode%5F10%5F2%5Frelease%5Fnotes/swift%5F5%5Frelease%5Fnotes%5Ffor%5Fxcode%5F10%5F2) related to Swift 5, but they are specific to what you do. Check them, maybe you want to use inherit designated initialisers with variadic parameters, or you were blocked by the deadlock problem due to complex recursive type definitions involving classes and generics, or struggle with generic type alias within a `@objc` method.


## [Xcode 10.2 beta](https://developer.apple.com/documentation/xcode%5Frelease%5Fnotes/xcode%5F10%5F2%5Frelease%5Fnotes) {#xcode-10-dot-2-beta}


### Apple Clang Compiler {#apple-clang-compiler}

There are a lot of new warnings for Apple Clang Compiler. And most of them are related to frameworks and modules. It's quite interesting because <span class="underline">guesses begin</span> it can be associated with Swift Package Manager integration as a dependency tool <span class="underline">guesses end</span>. The most important ones, as to me, are:

> A new diagnostic identifies framework headers that use quote includes instead of framework style includes. The warning is off by default but you can enable it by passing `-Wquoted-include-in-framework-header` to `clang`;

<!--quoteend-->

> Public headers in a framework might mistakenly `#import` or `#include` private headers, which causes layering violations and potential module cycles. There’s a new diagnostic that reports such violations. It’s OFF by default in `clang` and is controlled by the `-Wframework-include-private-from-public` flag;

<!--quoteend-->

> The use of `@import` in framework headers prevent headers being used without modules. A new diagnostic detects the use of `@import` in framework headers when you pass the `-fmodules` flag. The diagnostic is OFF by default in `clang` and is controlled using the `-Watimport-in-framework-header` flag;

<!--quoteend-->

> Previously, omitting the `framework` keyword when declaring a module for a framework didn’t affect compilation but silently did the wrong thing. A new diagnostic, `-Wincomplete-framework-module-declaration`, and a new fix-it suggests adding the appropriate keyword. This warning is on by default when you pass the `-fmodules` flag to `clang`.

First of all, how to turn them on: Goto to **Build Settings** for your application target, find **"Apple Clang - Custom Compiler Flags"** and put the desired flag to **"Other C Flags"**.

{{< figure src="/ox-hugo/xcode_10_2_custom_compiler_flags.png" >}}

I tried to build an old, Objective C based application and found a lot of issues with private headers in public framework headers:

{{< figure src="/ox-hugo/xcode_10_2_beta_clang_private_headers.png" >}}

And some issues with double-quoted imports within frameworks:

{{< figure src="/ox-hugo/xcode_10_2_beta_clang_double_quotes.png" >}}

I recommend you to run such diagnostics as well and, at least, create issues for your backlog. One day, all these problems will bring you a real headache.


### Build System {#build-system}

Also, there is a nice new Build System feature:

> Implicit Dependencies now supports finding dependencies in Other Linker Flags for linked frameworks and libraries specified with `-framework`, `-weak_framework`, `-reexport_framework`, `-lazy_framework`, `-weak-l`, `-reexport-l`, `-lazy-l`, and `-l`.

It's intriguing as well. In general, it means that you can define your implicit dependencies via `.xcconfig` or even with `xcodebuild` options and avoid these Link / Embed phases within Xcode.


### Debugging {#debugging}

Debugging got new features:

> UIStackView properties are now presented in the view debugger object inspector;

<!--quoteend-->

> > The view debugger presents a more compact 3D layout.

{{< figure src="/ox-hugo/xcode_10_2_beta_view_debugger.png" >}}

> Xcode can now automatically capture a memory graph if a memory resource exception is encountered while debugging. You can enable memory graph captures in the Diagnostics tab of the scheme’s run settings;

<!--quoteend-->

> On iOS and watchOS, Xcode shows the memory limit for running apps in the Memory Report as you approach the limit;

{{< figure src="/ox-hugo/xcode_10_2_beta_memory_limit.png" >}}

See this red line? Watchdog will send `applicationDidReceiveMemoryWarning(...)` when you reach the edge. I thought it would be more useful, to be honest. Like now looks like just a small nice improvement.


### LLDB Debugger {#lldb-debugger}

And LLDB Debugger got some love as well:

> You can now use `$0`, `$1`, … shorthands in LLDB expression evaluation inside closures;

<!--quoteend-->

> The LLDB debugger has a new command alias, `v`, for the “frame variable” command to print variables in the current stack frame. Because it bypasses the expression evaluator, `v` can be a lot faster and should be preferred over `p` or `po`.

I didn't notice any performance improvements, but `v` produces a better output in some cases but it's not a replacement for `po` in general, it's only about the current stack frame with some limitations. See the examples below.

{{< figure src="/ox-hugo/xcode_10_2_beta_clang_v.png" >}}


### Playgrounds {#playgrounds}

My favourite section - Playgrounds! Let's start with known issues:

> Playgrounds might not execute!

Unfortunately, this is the only news about Playgrounds in the current beta.


### Simulator {#simulator}

Some notes about Simulator:

> Siri **doesn’t work** in watchOS and iOS simulators;

<!--quoteend-->

> Pasteboard synchronization between macOS and simulated iOS devices is more reliable;

I really hope it does.

> You’re now only prompted once to authorize microphone access to all simulator devices

This is a nice improvement because many people have issues with CI and build agents due to this problem. Now a workaround can be automated or, at least, we can update out guides to set up build agents with "Run a simulator once" step.


### Testing {#testing}

> `xccov` supports merging multiple coverage reports—and their associated archives—together into an aggregate report and archive. When merging reports together, the aggregate report may be inaccurate for source files that changed in between the time that the original reports were generated. If there were no source changes, the aggregate report and archive will be accurate;

<!--quoteend-->

> `xccov` now supports diffing Xcode coverage reports, which can be used to calculate coverage changes over time. For example, to diff the coverage reports `before.xccovreport` and `after.xccovreport`, invoke `xccov` as follows: `xccov diff --json before.xccovreport after.xccovreport`;

<!--quoteend-->

> Static library and framework targets now appear in the coverage report as top-level entries, with line coverage values that are aggregated across all targets that include the static library or framework. This also resolves an issue where the source files for a static library or framework target would be included in the coverage report even if the target itself was excluded from code coverage in the scheme.

These are excellent news for Continuous Integration. Especially differing. Tell your release engineering team or anyone who is responsible for such things.

Though, there are some limitations related to testing parallelisation:

> Recording doesn’t work from Clones when Parallelization is on;

<!--quoteend-->

> Profiling tests don’t behave correctly when test parallelization is enabled;

Also, there are some promising bug fixes:

> If testing fails due to the test runner crashing on launch, Xcode attempts to generate a rich error message that describes the failure. This failure is present in the test activity log and appears in `stdout` if you’re using `xcodebuild`. The error is also present in the structured logs contained in the result bundle.

We have a lot of such issues, and usually, it's not clear at all what is happening. Sometimes, it's related to incorrect linking, sometimes to the system overload. It should help to reduce flakiness.

> Crash reports collected during testing no longer omit important fields such as the termination reason and description.

No comments, just 😘 and 🥰.

And the last one about Xcode, useful for companies with a lot of developers, Xcode now supports [macOS content caching service](https://support.apple.com/en-gb/guide/mac-help/mchl9388ba1b/mac). It means that you can have a caching server with Xcode application in your local network.


### Issues {#issues}

I faced some problems with the beta. Mostly, with third-party tools. `carthage`, for example, doesn't work with the following error:

```text
 Could not find any available simulators for iOS
```

I checked the available simulator, and it seems that something is broken in the current beta; also it's impossible to download other runtimes from Xcode, the list of available simulators is just empty (a radar filled):

```bash
$ xcrun simctl list devices --json | grep -A16 12.1
    "com.apple.CoreSimulator.SimRuntime.iOS-12-1" : [
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 5s",
        "udid" : "DDD36346-A76F-42E8-80F4-6F11E1EE4BEB",
        "availabilityError" : "runtime profile not found"
      },
      {
        "availability" : "(unavailable, runtime profile not found)",
        "state" : "Shutdown",
        "isAvailable" : false,
        "name" : "iPhone 6",
        "udid" : "21794717-BC89-45E4-9F57-8CF9D14A87D1",
        "availabilityError" : "runtime profile not found"
      },
...
```

It is a beta. And the changelog is enormous. Be patience and reasonable :)


## iOS 12.2 beta {#ios-12-dot-2-beta}

Okay. It seems like they are polishing their tech-debt and applying security patches. Two things are broken:

> You might be unable to authenticate within Wallet after selecting a card;

<!--quoteend-->

> You might be unable to purchase a prepaid data plan using cellular data.

And **Apple News will be available in Canada**.

Stay tuned.


## macOS Mojave 10.14.4 beta {#macos-mojave-10-dot-14-dot-4-beta}

The only new thing here is a potential issue with Safari 12.1 after upgrading from Safari 10.1.2:

> After updating to Safari 12.1 from Safari 10.1.2, web pages might not display. (47335741)
> Workaround: Run the following command in Terminal:
> `defaults delete com.apple.Safari`

With the following consequences:

> **Warning:** You will lose your previous Safari settings after running the command above.


## Final cut {#final-cut}

The article turned out to be much longer than I imagined. So, I put all my thoughts among all the sections above. The short version of the article is - Swift 5 is here!

Stay tuned and hydrated! And thanks for reading.
