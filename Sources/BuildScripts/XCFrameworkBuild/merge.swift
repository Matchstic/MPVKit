import Foundation

/// Links every static archive the per-library builds produced into ONE dynamic
/// `MPVKit.framework` per slice, then assembles `MPVKit.xcframework`.
///
/// Why one dynamic framework rather than a pile of static ones: five of the
/// linked libraries are LGPL (FFmpeg, libmpv, libplacebo, libfribidi,
/// libuchardet). LGPLv2.1 §6 wants a recipient to be able to relink. A single
/// dynamic binary discharges that for all of them at once -- static archives
/// could not -- and it costs one dyld load at launch instead of a dozen.
///
/// Why the merged framework must be the *only* thing consumers depend on: while
/// the per-library binaryTargets were still listed alongside it, every consumer
/// linked a second, static copy of each library on top of the dylib that already
/// contained them. That is not merely wasteful. The dylib exports
/// `___isPlatformVersionAtLeast` weakly, and ld loads an archive member that
/// strongly defines a weak dylib export -- so libdovi's Rust std object got
/// pulled into the app unbidden, dragging ~1000 symbols behind it, and
/// libshaderc leaked two glslang objects the same way via `std::length_error` /
/// `std::out_of_range` typeinfo. Those Rust symbols then had to bind back across
/// images, and since libdovi is compiled per-arch each slice carries its own
/// crate disambiguator: on arm64e Apple TV hardware dyld picked the arm64e slice
/// for an arm64 process and the app died at launch on a missing
/// `__RNv...core3net11socket_addr` symbol. `Library.targets` therefore emits
/// `MPVKit_dynamic` and nothing else for every library merged in here.
///
/// This is a port of Cue's `Scripts/mpvkit-link-dynamic.sh` and
/// `Scripts/mpvkit-package-framework.sh`, which proved the approach out of tree.
enum MergeMPVKit {
    /// The slices the merged framework ships. macOS is deliberately absent: the
    /// out-of-tree scripts never covered it and the shipped xcframework has no
    /// macos slice, so adding one here would be untested. A macOS consumer of
    /// this package is unsupported today, exactly as before this port.
    static let mergedPlatforms: [PlatformType] = [.ios, .isimulator, .tvos, .tvsimulator, .maccatalyst, .macos]

    /// FFmpeg + mpv: force-loaded, because consumers call their public API
    /// directly and normal archive semantics would drop anything mpv itself did
    /// not happen to reference.
    static let forcedFFmpegArchives = ["libavutil.a", "libavcodec.a", "libavformat.a"]
    static let plainFFmpegArchives = ["libavfilter.a", "libavdevice.a", "libswresample.a", "libswscale.a"]

    /// Everything else: plain-linked, so only the members actually needed come
    /// in. Their public API still ends up exported, because mpv/FFmpeg reference
    /// it and a plain-loaded member's globals are exported by the dylib.
    static let plainLibraries: [Library] = [
        .libass, .libplacebo, .libfribidi, .libfreetype, .libharfbuzz,
        .libunibreak, .libuchardet, .libdav1d, .libuavs3d, .libdovi, .lcms2,
    ]
    static let plainNamedArchives: [(library: Library, archive: String)] = [
        (.libshaderc, "libshaderc_combined.a"),
        (.vulkan, "libMoltenVK.a"),
        (.openssl, "libcrypto.a"),
        (.openssl, "libssl.a"),
    ]

    /// The floor the merged framework is linked against and declares, kept
    /// deliberately separate from `PlatformType.minVersion` (14.0), which is what
    /// the individual static archives are compiled for and is upstream's
    /// compatibility target. Linking those older objects into a newer dylib is
    /// fine; the reverse would warn. Change this one constant to move the
    /// framework's floor -- it feeds both the link target triple and
    /// Info.plist's MinimumOSVersion, which must agree.
    
    #if os(macOS)
    static let deploymentTarget = "14.0"
    #else
    static let deploymentTarget = "18.0"
    #endif

    /// tvOS is arm64-only, no arm64e. The per-arch crate-disambiguator hazard
    /// that made this necessary is gone now that consumers link no static
    /// libdovi, but arm64 and arm64e share a cputype -- so on arm64e hardware
    /// dyld can still pick the arm64e slice for an arm64 process. tvOS apps are
    /// arm64, so an arm64e slice exists only to be mis-selected. Every other
    /// slice pairs archs with distinct cputypes (arm64/x86_64), where dyld can
    /// only ever choose the one the app was linked against.
    static func architectures(_ platform: PlatformType) -> [ArchType] {
        switch platform {
        case .tvos:
            return [.arm64]
        default:
            return platform.architectures
        }
    }

    static func run() throws {
        let platforms = BaseBuild.platforms.filter { mergedPlatforms.contains($0) }
        guard !platforms.isEmpty else {
            print("MPVKit merge: no mergeable platform was built, skipping")
            return
        }

        let workRoot = URL.currentDirectory + "MPVKit-merge"
        try? FileManager.default.removeItem(at: workRoot)
        try FileManager.default.createDirectory(at: workRoot, withIntermediateDirectories: true, attributes: nil)

        var frameworkPaths: [String] = []
        for platform in platforms {
            if let path = try mergeSlice(platform: platform, workRoot: workRoot) {
                frameworkPaths.append(path)
            }
        }

        guard !frameworkPaths.isEmpty else {
            print("MPVKit merge: nothing linked, skipping xcframework")
            return
        }

        try createXCFramework(frameworkPaths: frameworkPaths)
        try packageRelease()
    }

    // MARK: - one slice

    private static func mergeSlice(platform: PlatformType, workRoot: URL) throws -> String? {
        let archs = architectures(platform)
        let ffmpegLib = libDir(.FFmpeg, platform, archs[0])
        guard FileManager.default.fileExists(atPath: ffmpegLib.path) else {
            print("MPVKit merge: \(platform.rawValue) was not built, skipping")
            return nil
        }

        let sdk = platform.sdk.lowercased()
        let sysroot = try Utility.launch(
            path: "/usr/bin/xcrun", arguments: ["--sdk", sdk, "--show-sdk-path"], isOutput: true
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        var thinBinaries: [URL] = []
        for arch in archs {
            let thin = workRoot + [platform.rawValue, "MPVKit-\(arch.rawValue)"]
            try FileManager.default.createDirectory(
                at: thin.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try link(platform: platform, arch: arch, sdk: sdk, sysroot: sysroot, output: thin, workRoot: workRoot)
            thinBinaries.append(thin)
            print("  linked \(platform.rawValue)/\(arch.rawValue)")
        }

        let fat = workRoot + [platform.rawValue, "MPVKit"]
        if thinBinaries.count > 1 {
            var args = ["-create"]
            args.append(contentsOf: thinBinaries.map { $0.path })
            args.append(contentsOf: ["-output", fat.path])
            try Utility.launch(path: "/usr/bin/lipo", arguments: args)
        } else {
            try? FileManager.default.removeItem(at: fat)
            try FileManager.default.copyItem(at: thinBinaries[0], to: fat)
        }

        return try packageFramework(platform: platform, arch: archs[0], binary: fat, workRoot: workRoot)
    }

    private static func link(
        platform: PlatformType, arch: ArchType, sdk: String, sysroot: String, output: URL, workRoot: URL
    ) throws {
        let ffmpegLib = libDir(.FFmpeg, platform, arch)

        // FFmpeg compiles vulkan.o into BOTH libavutil.a and libavcodec.a,
        // byte-identical. Both archives must be -force_load, so drop the
        // duplicate member rather than lose an export to a duplicate-symbol
        // error. Note the archives share many other member *names* (utils.o,
        // 4xm.o, ...) with different contents -- a filename collision is not a
        // symbol collision, and only vulkan.o actually clashes.
        let scratch = workRoot + [platform.rawValue, "ar-\(arch.rawValue)"]
        try? FileManager.default.removeItem(at: scratch)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true, attributes: nil)
        let patchedAvcodec = scratch + "libavcodec.a"
        try FileManager.default.copyItem(at: ffmpegLib + "libavcodec.a", to: patchedAvcodec)
        let members = try Utility.launch(path: "/usr/bin/ar", arguments: ["t", patchedAvcodec.path], isOutput: true)
        if members.split(separator: "\n").contains("vulkan.o") {
            try Utility.launch(path: "/usr/bin/ar", arguments: ["d", patchedAvcodec.path, "vulkan.o"])
            _ = try? Utility.launch(path: "/usr/bin/ranlib", arguments: [patchedAvcodec.path])
        }

        var forced: [URL] = [ffmpegLib + "libavutil.a", patchedAvcodec, ffmpegLib + "libavformat.a"]
        forced.append(libDir(.libmpv, platform, arch) + "libmpv.a")

        var plain: [URL] = plainFFmpegArchives.map { ffmpegLib + $0 }
        for library in plainLibraries {
            let dir = libDir(library, platform, arch)
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { continue }
            for entry in entries.sorted() where entry.hasSuffix(".a") {
                plain.append(dir + entry)
            }
        }
        for item in plainNamedArchives {
            let archive = libDir(item.library, platform, arch) + item.archive
            if FileManager.default.fileExists(atPath: archive.path) {
                plain.append(archive)
            }
        }

        // UIKit/OpenGLES differ by platform; keep the list per-slice rather than
        // guessing. IOKit: MoltenVK enumerates the GPU through IOServiceMatching
        // on Catalyst.
        var frameworks = [
            "AVFoundation", "AudioToolbox", "CoreAudio", "CoreMedia", "CoreVideo", "VideoToolbox",
            "Metal", "MetalKit", "QuartzCore", "CoreGraphics", "CoreImage", "CoreText", "Foundation",
            "Security", "IOSurface", "CFNetwork",
        ]
        switch platform {
        case .maccatalyst:
            frameworks.append(contentsOf: ["UIKit", "IOKit"])
        case .macos:
            frameworks.append(contentsOf: ["IOKit"])
        default:
            frameworks.append(contentsOf: ["UIKit", "OpenGLES"])
        }

        var arguments = ["--sdk", sdk, "clang", "-dynamiclib", "-arch", arch.rawValue, "-isysroot", sysroot]
        arguments.append(contentsOf: ["-target", targetTriple(platform: platform, arch: arch)])
        arguments.append(contentsOf: ["-install_name", "@rpath/MPVKit.framework/MPVKit"])
        arguments.append(contentsOf: ["-o", output.path])

        // Catalyst's UIKit lives under iOSSupport, not the macOS SDK root. Same
        // flag the per-library build applies in its .maccatalyst branch.
        if platform == .maccatalyst {
            arguments.append(contentsOf: ["-iframework", "\(sysroot)/System/iOSSupport/System/Library/Frameworks"])
        }

        for archive in forced {
            arguments.append(contentsOf: ["-force_load", archive.path])
        }
        arguments.append(contentsOf: plain.map { $0.path })
        for framework in frameworks {
            arguments.append(contentsOf: ["-framework", framework])
        }
        arguments.append(contentsOf: ["-lz", "-lbz2", "-liconv", "-lc++", "-lresolv", "-lxml2"])

        try Utility.launch(path: "/usr/bin/xcrun", arguments: arguments)
    }

    /// Built from `deploymentTarget` rather than `PlatformType.deploymentTarget`,
    /// which would pin the dylib to the archives' 14.0 floor.
    private static func targetTriple(platform: PlatformType, arch: ArchType) -> String {
        let cpu = arch.targetCpu
        switch platform {
        case .ios:
            return "\(cpu)-apple-ios\(deploymentTarget)"
        case .isimulator:
            return "\(cpu)-apple-ios\(deploymentTarget)-simulator"
        case .tvos:
            return "\(cpu)-apple-tvos\(deploymentTarget)"
        case .tvsimulator:
            return "\(cpu)-apple-tvos\(deploymentTarget)-simulator"
        case .maccatalyst:
            return "\(cpu)-apple-ios\(deploymentTarget)-macabi"
        case .macos:
            return "\(cpu)-apple-macos\(deploymentTarget)"
        default:
            return platform.deploymentTarget(arch)
        }
    }

    // MARK: - framework assembly

    private static func packageFramework(
        platform: PlatformType, arch: ArchType, binary: URL, workRoot: URL
    ) throws -> String {
        let framework = workRoot + [platform.rawValue, "MPVKit.framework"]
        try? FileManager.default.removeItem(at: framework)
        let headers = framework + "Headers"
        let modules = framework + "Modules"
        
        try FileManager.default.createDirectory(at: headers, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true, attributes: nil)
        
        if platform == .macos {
            let versionsA = framework + ["Versions", "A"]
            try FileManager.default.createDirectory(at: versionsA, withIntermediateDirectories: true, attributes: nil)
            
            // Link Versions/Current to Versions/A
            let versionsCurrent = framework + ["Versions", "Current"]
            try FileManager.default.createSymbolicLink(atPath: versionsCurrent.path, withDestinationPath: "A")
            
            // Write binary to Versions/A/MPVKit
            try FileManager.default.copyItem(at: binary, to: versionsA + "MPVKit")
            
            // Link binary from framework root
            let binaryRoot = framework + "MPVKit"
            try FileManager.default.createSymbolicLink(atPath: binaryRoot.path, withDestinationPath: "Versions/Current/MPVKit")
        } else {
            try FileManager.default.copyItem(at: binary, to: framework + "MPVKit")
        }

        // Headers in FFmpeg's natural layout (Headers/libavutil/..., Headers/mpv/...),
        // NOT flat. FFmpeg headers cross-include as "libavutil/x.h", and in the old
        // per-library setup that resolved only because a separate Libavutil.framework
        // happened to sit on the framework search path (Clang's Foo/bar.h ->
        // Foo.framework mapping, matching case-insensitively on APFS). Merging removes
        // that crutch, so the real directory layout has to do the work instead.
        for library in [Library.FFmpeg, Library.libmpv] {
            let include = thinDir(library, platform, arch) + "include"
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: include.path) else { continue }
            for entry in entries {
                try? FileManager.default.removeItem(at: headers + entry)
                try FileManager.default.copyItem(at: include + entry, to: headers + entry)
            }
        }

        // A quoted include resolves relative to the *including file's* directory,
        // and a framework's Headers root is not on the quoted search path -- so
        // inside Headers/libavcodec/ the lookup fails. Rewrite the cross-includes
        // to ../libavutil/x.h, which resolves purely by directory position: no
        // consumer -I flag, and no symlinks for `umbrella "."` to walk into twice.
        // Every FFmpeg header is exactly one level deep, so ../ is always right.
        // NB: '@' delimiter, not '|' -- the pattern contains an alternation.
        Utility.shell(
            "find \(Utility.shellQuote(headers.path)) -mindepth 2 -name '*.h' -exec "
                + "sed -i '' -E 's@#include \"(lib(av|sw)[a-z]+)/@#include \"../\\1/@g' {} +")

        // Excludes: headers that #include an SDK Apple platforms do not ship. The
        // AMF one is the trap that bites on every framework re-copy; the rest are
        // carried over from the per-library modulemaps this replaces.
        let modulemap = """
        framework module MPVKit [system] {
            umbrella "."

            exclude header "libavutil/hwcontext_vulkan.h"
            exclude header "libavutil/hwcontext_vdpau.h"
            exclude header "libavutil/hwcontext_vaapi.h"
            exclude header "libavutil/hwcontext_qsv.h"
            exclude header "libavutil/hwcontext_opencl.h"
            exclude header "libavutil/hwcontext_dxva2.h"
            exclude header "libavutil/hwcontext_d3d11va.h"
            exclude header "libavutil/hwcontext_d3d12va.h"
            exclude header "libavutil/hwcontext_cuda.h"
            exclude header "libavutil/hwcontext_amf.h"

            exclude header "libavcodec/xvmc.h"
            exclude header "libavcodec/vdpau.h"
            exclude header "libavcodec/qsv.h"
            exclude header "libavcodec/dxva2.h"
            exclude header "libavcodec/d3d11va.h"
            exclude header "libavcodec/d3d12va.h"

            export *
        }

        """
        try modulemap.write(to: modules + "module.modulemap", atomically: true, encoding: .utf8)

        let version = BaseBuild.options.releaseVersion
        let minimumOS = deploymentTarget
        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>CFBundleDevelopmentRegion</key><string>en</string>
          <key>CFBundleExecutable</key><string>MPVKit</string>
          <key>CFBundleIdentifier</key><string>com.mpvkit.MPVKit</string>
          <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
          <key>CFBundleName</key><string>MPVKit</string>
          <key>CFBundlePackageType</key><string>FMWK</string>
          <key>CFBundleShortVersionString</key><string>\(version)</string>
          <key>CFBundleVersion</key><string>\(version)</string>
          <key>CFBundleSupportedPlatforms</key><array><string>\(platform.sdk)</string></array>
          <key>MinimumOSVersion</key><string>\(minimumOS)</string>
        </dict></plist>

        """
        
        if platform == .macos {
            let resources = framework + ["Versions", "A", "Resources"]
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true, attributes: nil)
            
            // Link Resources to Versions/Current/Resources
            let resourcesRoot = framework + ["Resources"]
            try FileManager.default.createSymbolicLink(atPath: resourcesRoot.path, withDestinationPath: "Versions/Current/Resources")
            
            // Write plist to Versions/A/Resources/Info.plist
            let infoPlistURL = resources + "Info.plist"
            try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
            
            try Utility.launch(path: "/usr/bin/plutil", arguments: ["-lint", infoPlistURL.path])
        } else {
            let infoPlistURL = framework + "Info.plist"
            try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
            
            try Utility.launch(path: "/usr/bin/plutil", arguments: ["-lint", infoPlistURL.path])
        }

        let headerCount = Utility.listAllFiles(in: headers).filter { $0.pathExtension == "h" }.count
        print("  packaged \(platform.rawValue): \(headerCount) headers")
        return framework.path
    }

    // MARK: - xcframework + release

    private static func createXCFramework(frameworkPaths: [String]) throws {
        let xcframeworkDirectoryURL = URL.currentDirectory + ["release", "xcframework"]
        try? FileManager.default.createDirectory(
            at: xcframeworkDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let output = xcframeworkDirectoryURL + "MPVKit.xcframework"
        try? FileManager.default.removeItem(at: output)

        var arguments = ["-create-xcframework"]
        for path in frameworkPaths {
            arguments.append(contentsOf: ["-framework", path])
        }
        arguments.append(contentsOf: ["-output", output.path])
        try Utility.launch(path: "/usr/bin/xcodebuild", arguments: arguments)
        print("MPVKit.xcframework: \(frameworkPaths.count) slices")
    }

    private static func packageRelease() throws {
        let releaseDirPath = URL.currentDirectory + ["release"]
        let xcframeworkDirectoryURL = releaseDirPath + "xcframework"
        let zipFile = releaseDirPath + "MPVKit.xcframework.zip"
        let checksumFile = releaseDirPath + "MPVKit.xcframework.checksum.txt"
        try? FileManager.default.removeItem(at: zipFile)
        try? FileManager.default.removeItem(at: checksumFile)
        try Utility.launch(
            path: "/usr/bin/zip", arguments: ["-qry", zipFile.path, "MPVKit.xcframework"],
            currentDirectoryURL: xcframeworkDirectoryURL)
        Utility.shell(
            "swift package compute-checksum \(Utility.shellQuote(zipFile.path)) > \(Utility.shellQuote(checksumFile.path))")

        let checksum = try String(contentsOf: checksumFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try appendPackageManifestEntry(checksum: checksum, releaseDirPath: releaseDirPath)
    }

    /// `BaseBuild.generatePackageManagerFile` emits one binaryTarget per entry in
    /// `Library.targets`, which cannot describe MPVKit_dynamic: it is not any one
    /// library's artifact, and it does not exist until every library has been
    /// built. So the merge step appends its own entry, in the same
    /// //AUTO_GENERATE_TARGETS_END// region and the same format.
    private static func appendPackageManifestEntry(checksum: String, releaseDirPath: URL) throws {
        let packageFile = releaseDirPath + "Package.swift"
        if !FileManager.default.fileExists(atPath: packageFile.path) {
            let template = URL.currentDirectory + ["../docs/Package.template.swift"]
            try FileManager.default.createDirectory(
                at: releaseDirPath, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.copyItem(at: template, to: packageFile)
        }

        let url =
            "https://github.com/edde746/MPVKit/releases/download/\(BaseBuild.options.releaseVersion)/MPVKit.xcframework.zip"
        let entry = """

                .binaryTarget(
                    name: "MPVKit_dynamic",
                    url: "\(url)",
                    checksum: "\(checksum)"
                ),
        """

        guard let data = FileManager.default.contents(atPath: packageFile.path),
            var str = String(data: data, encoding: .utf8)
        else { return }
        let placeholder = "        //AUTO_GENERATE_TARGETS_END//"
        guard str.contains(placeholder) else {
            throw NSError(
                domain: "release/Package.swift has no //AUTO_GENERATE_TARGETS_END// marker", code: 1)
        }
        str = str.replacingOccurrences(of: placeholder, with: entry + "\n" + placeholder)
        try str.write(toFile: packageFile.path, atomically: true, encoding: .utf8)
        print("release/Package.swift: MPVKit_dynamic \(checksum)")
    }

    // MARK: - paths

    private static func thinDir(_ library: Library, _ platform: PlatformType, _ arch: ArchType) -> URL {
        URL.currentDirectory + [library.rawValue, platform.rawValue, "thin", arch.rawValue]
    }

    private static func libDir(_ library: Library, _ platform: PlatformType, _ arch: ArchType) -> URL {
        thinDir(library, platform, arch) + "lib"
    }
}
