// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "MPVKit",
    platforms: [.macOS(.v11), .iOS(.v14), .tvOS(.v14)],
    products: [
        .library(
            name: "MPVKit",
            targets: ["_MPVKit"]
        ),
    ],
    targets: [
        .target(
            name: "_MPVKit",
            dependencies: [
                // Libbluray removed 2026-08-21: mpv is built -Dlibbluray=disabled,
                // so nothing references it (0 undefined bd_* symbols, was 24), and an
                // iPhone/Apple TV has no optical drive. It is also LGPL-2.1+, so
                // keeping a dead dependency would drag a relinking obligation into
                // the dynamic-framework work for no benefit.
                // DYNAMIC MERGE 2026-08-21: Libmpv + the 7 FFmpeg frameworks are now a
                // single dynamic MPVKit.xcframework. Five linked libraries are LGPL
                // (FFmpeg, mpv, libplacebo, libfribidi, libuchardet); one dynamic
                // binary satisfies LGPLv2.1 relinking for all of them at once, which
                // static archives could not.
                // Libuchardet removed 2026-08-23 for the same reason as _FFmpeg's
                // list below: it is inside MPVKit_dynamic, which exports its whole
                // public API (uchardet_new/_delete/_handle_data/_data_end/_reset/
                // _get_charset) on every slice. As a separate dependency it
                // contributed no objects to consumers and existed only to make
                // Xcode embed a second, empty stub framework in the app bundle.
                "MPVKit_dynamic", "_FFmpeg",
                .target(name: "Libluajit", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/_MPVKit",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("CoreAudio"),
            ]
        ),
        .target(
            name: "_FFmpeg",
            // Empty since 2026-08-23. The 7 FFmpeg frameworks merged into
            // MPVKit_dynamic (see _MPVKit above), and so did every library that
            // used to be listed here: Libssl, Libcrypto, Libass, Libfreetype,
            // Libfribidi, Libharfbuzz, MoltenVK, Libshaderc_combined, lcms2,
            // Libplacebo, Libdovi, Libunibreak, Libdav1d, Libuavs3d. Keeping them
            // as dependencies put a second, static copy of each on every
            // consumer's link line on top of the dylib that already contains them.
            //
            // That was not merely wasteful. MPVKit.framework exports
            // ___isPlatformVersionAtLeast weakly, and ld loads a static archive
            // member that strongly defines a weak dylib export -- so libdovi's
            // Rust std object got pulled in unbidden, dragging 16 more CGUs and
            // 1046 symbols, and Libshaderc_combined leaked 2 glslang objects the
            // same way via std::length_error / std::out_of_range typeinfo. The
            // resulting Rust symbols had to bind back across images to
            // MPVKit.framework, and since libdovi is compiled per-arch each slice
            // carries its own crate disambiguator: on arm64e Apple TV hardware
            // dyld picked MPVKit's arm64e slice for an arm64 process and the app
            // died at launch on a missing __RNv...core3net11socket_addr symbol.
            // Cue/Scripts/mpvkit-link-dynamic.sh works around the symptom by
            // shipping tvOS as arm64-only; this removes the cause.
            //
            // Nothing needs them: the merged dylib has zero undefined symbols not
            // satisfied by a system framework, it exports every library's public
            // API, and it ships headers for FFmpeg and mpv only, so a consumer
            // cannot reference the rest. The target survives for its
            // linkerSettings below.
            dependencies: [],
            path: "Sources/_FFmpeg",
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("Metal"),
                .linkedFramework("Security"),
                .linkedFramework("VideoToolbox"),
                .linkedLibrary("bz2"),
                .linkedLibrary("iconv"),
                .linkedLibrary("expat"),
                .linkedLibrary("resolv"),
                .linkedLibrary("xml2"),
                .linkedLibrary("z"),
                .linkedLibrary("c++"),
            ]
        ),

        //AUTO_GENERATE_TARGETS_BEGIN//

        // Removed 2026-08-23 along with _FFmpeg's dependency list: Libass,
        // Libcrypto, Libdav1d, Libdovi, Libfreetype, Libfribidi, Libharfbuzz,
        // Libplacebo, Libshaderc_combined, Libssl, Libuavs3d, Libunibreak, lcms2,
        // MoltenVK -- and Libuchardet, which hung off _MPVKit rather than
        // _FFmpeg. All fifteen are inside MPVKit_dynamic already. A
        // binaryTarget is downloaded whenever the package resolves, whether or
        // not any target depends on it, so leaving the declarations behind would
        // have kept fetching fourteen xcframework zips for nothing. Their URLs
        // and checksums are in git history if the xcframework is ever rebuilt --
        // Sources/BuildScripts still knows how to produce them.
        //
        // MPVKit_dynamic and Libluajit are all that is left. The pre-merge
        // Libav*/Libsw*/Libmpv xcframeworks and Frameworks/Libuavs3d.xcframework
        // were deleted from Frameworks/ at the same time; `make build` recreates
        // them, and Frameworks/ is .gitignore'd, so nothing tracked was lost.

        // ONE dynamic framework replacing Libmpv + the 7 FFmpeg xcframeworks.
        // Also links libass, libplacebo, libfribidi, libfreetype, libharfbuzz,
        // libunibreak, libuchardet, libdav1d, libuavs3d, libdovi, lcms2, shaderc,
        // MoltenVK and OpenSSL into the same dylib, one per slice.
        //
        // Headers keep FFmpeg's natural include/libavutil/... layout, and their
        // cross-includes are rewritten to ../libavutil/... at package time. In the
        // old per-library setup `#include "libavutil/x.h"` resolved only because a
        // separate Libavutil.framework happened to sit on the framework search path
        // (Clang's Foo/bar.h -> Foo.framework mapping, case-insensitive on APFS).
        // Merging removed that crutch, so directory layout does the work now.
        //
        // Consumers `import MPVKit` instead of Libavutil/Libavcodec/Libavformat/Libmpv.
        .binaryTarget(
            name: "MPVKit_dynamic",
            path: "dist/release/xcframework/MPVKit.xcframework"
        ),

        .binaryTarget(
            name: "Libluajit",
            url: "https://github.com/mpvkit/libluajit-build/releases/download/2.1.0-xcode/Libluajit.xcframework.zip",
            checksum: "8e76f267ee100ff5f3bbde7641b2240566df722241cdf8e135be7ef3d29e237a"
        ),

//AUTO_GENERATE_TARGETS_END//
    ]
)
