// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "MPVKit",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13)],
    products: [
        .library(
            name: "MPVKit",
            targets: ["_MPVKit"]
        ),
        .library(
            name: "MPVKit-GPL",
            targets: ["_MPVKit-GPL"]
        ),
    ],
    targets: [
        .target(
            name: "_MPVKit",
            dependencies: [
                "Libmpv", "_FFmpeg", "Libuchardet", "Libbluray",
                .target(name: "Libluajit", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/_MPVKit",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
            ]
        ),
        .target(
            name: "_FFmpeg",
            dependencies: [
                "Libavcodec", "Libavdevice", "Libavfilter", "Libavformat", "Libavutil", "Libswresample", "Libswscale",
                "Libssl", "Libcrypto", "Libass", "Libfreetype", "Libfribidi", "Libharfbuzz",
                "MoltenVK", "Libshaderc_combined", "lcms2", "Libplacebo", "Libdovi", "Libunibreak",
                "gmp", "nettle", "hogweed", "gnutls", "Libdav1d", "Libuavs3d"
            ],
            path: "Sources/_FFmpeg",
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("Metal"),
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
        .target(
            name: "_MPVKit-GPL",
            dependencies: [
                "Libmpv-GPL", "_FFmpeg-GPL", "Libuchardet", "Libbluray",
                .target(name: "Libluajit", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/_MPVKit-GPL",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
            ]
        ),
        .target(
            name: "_FFmpeg-GPL",
            dependencies: [
                "Libavcodec-GPL", "Libavdevice-GPL", "Libavfilter-GPL", "Libavformat-GPL", "Libavutil-GPL", "Libswresample-GPL", "Libswscale-GPL",
                "Libssl", "Libcrypto", "Libass", "Libfreetype", "Libfribidi", "Libharfbuzz",
                "MoltenVK", "Libshaderc_combined", "lcms2", "Libplacebo", "Libdovi", "Libunibreak",
                "Libsmbclient", "gmp", "nettle", "hogweed", "gnutls", "Libdav1d", "Libuavs3d"
            ],
            path: "Sources/_FFmpeg-GPL",
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("Metal"),
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

        .binaryTarget(
            name: "Libmpv-GPL",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libmpv-GPL.xcframework.zip",
            checksum: "fbbe9194c723d527e40a64672e0b371362bf2e98e1e55863a2b559db4cdc83b4"
        ),
        .binaryTarget(
            name: "Libavcodec-GPL",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libavcodec-GPL.xcframework.zip",
            checksum: "9c060baf3c4d3d73292482d8e72074e0af691160f526d3537945cdd9ef1bfc8b"
        ),
        .binaryTarget(
            name: "Libavdevice-GPL",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libavdevice-GPL.xcframework.zip",
            checksum: "5b2ed39f1b5417259f66bf4ca91145101f8beacc3297f8d2095c5c6e505e6bd5"
        ),
        .binaryTarget(
            name: "Libavformat-GPL",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libavformat-GPL.xcframework.zip",
            checksum: "dc85184178999df8f8f422383915b930c89680f75ff01dbee7f898e42f768ecb"
        ),
        .binaryTarget(
            name: "Libavfilter-GPL",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libavfilter-GPL.xcframework.zip",
            checksum: "2e960b71f23540e8362a9e66a148f5bdb530c3b4efbeae89a2c2a58cf74033bf"
        ),
        .binaryTarget(
            name: "Libavutil-GPL",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libavutil-GPL.xcframework.zip",
            checksum: "623cca2e8c3bde6e992981470808d7b6e354bef60404f822ae21b83d187396e4"
        ),
        .binaryTarget(
            name: "Libswresample-GPL",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libswresample-GPL.xcframework.zip",
            checksum: "39c81b82b3ad276d66709809ce87a8e63bfad7af0ea82b86e8a864da29996653"
        ),
        .binaryTarget(
            name: "Libswscale-GPL",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libswscale-GPL.xcframework.zip",
            checksum: "8f1a91579981b069812d6928382b576d2fb216279d137425e900ee24daf4c831"
        ),
        //AUTO_GENERATE_TARGETS_BEGIN//

        .binaryTarget(
            name: "Libcrypto",
            url: "https://github.com/mpvkit/openssl-build/releases/download/3.2.0/Libcrypto.xcframework.zip",
            checksum: "89989ea14f7297d98083eb8adfba9b389f5b4886cb54fb3d5b6e8b915b7adf1d"
        ),
        .binaryTarget(
            name: "Libssl",
            url: "https://github.com/mpvkit/openssl-build/releases/download/3.2.0/Libssl.xcframework.zip",
            checksum: "46ad8e8fa5a6efe7bd31c9b3c56b20c1bc29a581083588d86e941d261d7dbe98"
        ),

        .binaryTarget(
            name: "gmp",
            url: "https://github.com/mpvkit/gnutls-build/releases/download/3.8.3/gmp.xcframework.zip",
            checksum: "defd5623e6786543588001b8f33026395960a561540738deb6df6996d39f957d"
        ),

        .binaryTarget(
            name: "nettle",
            url: "https://github.com/mpvkit/gnutls-build/releases/download/3.8.3/nettle.xcframework.zip",
            checksum: "c3b8f506fa32bcb3f9bf65096b0556c4f5973f846ee964577d783edbe8e6969d"
        ),
        .binaryTarget(
            name: "hogweed",
            url: "https://github.com/mpvkit/gnutls-build/releases/download/3.8.3/hogweed.xcframework.zip",
            checksum: "47a34e7877f7ebd9175f5645059030e553276faa9a21b91e29fb7463b94e8daf"
        ),

        .binaryTarget(
            name: "gnutls",
            url: "https://github.com/mpvkit/gnutls-build/releases/download/3.8.3/gnutls.xcframework.zip",
            checksum: "5f5cf903a2d52157c29ad304260709f618ce086afea02061241982f8425a6fb0"
        ),

        .binaryTarget(
            name: "Libunibreak",
            url: "https://github.com/mpvkit/libass-build/releases/download/0.17.3/Libunibreak.xcframework.zip",
            checksum: "430ed1a8ff1a230bd93b6868021cde2aafb23c8cb2d586525836cac47c4f310f"
        ),

        .binaryTarget(
            name: "Libfreetype",
            url: "https://github.com/mpvkit/libass-build/releases/download/0.17.3/Libfreetype.xcframework.zip",
            checksum: "300d2966c914e06f0211d8da0ea6208a345709b888e9cbbf1cdd94df26330359"
        ),

        .binaryTarget(
            name: "Libfribidi",
            url: "https://github.com/mpvkit/libass-build/releases/download/0.17.3/Libfribidi.xcframework.zip",
            checksum: "4a3122a2027f021937ed0fa07173dca7f2c1c4c4202b7caf8043fa80408c0953"
        ),

        .binaryTarget(
            name: "Libharfbuzz",
            url: "https://github.com/mpvkit/libass-build/releases/download/0.17.3/Libharfbuzz.xcframework.zip",
            checksum: "f607773598caa72435d8b19ce6a9d54fa7f26cde126b6b66c0a3d2804f084c68"
        ),

        .binaryTarget(
            name: "Libass",
            url: "https://github.com/mpvkit/libass-build/releases/download/0.17.3/Libass.xcframework.zip",
            checksum: "af24cd1429069153f0ca5c650e0b374c27ae38283aca47cbbbc9edb3165b182e"
        ),

        .binaryTarget(
            name: "Libsmbclient",
            url: "https://github.com/mpvkit/libsmbclient-build/releases/download/4.15.13/Libsmbclient.xcframework.zip",
            checksum: "589db9c241e6cc274f2825bee542add273febd0666ebd7ea8a402574ed76e9af"
        ),

        .binaryTarget(
            name: "Libbluray",
            url: "https://github.com/mpvkit/libbluray-build/releases/download/1.3.4/Libbluray.xcframework.zip",
            checksum: "68540747670e734e9b9063da3e5ccb139d34e8b40e1d5ec3177392603d93dfec"
        ),

        .binaryTarget(
            name: "Libuavs3d",
            url: "https://github.com/mpvkit/libuavs3d-build/releases/download/1.2.1/Libuavs3d.xcframework.zip",
            checksum: "893257fc73c61b87fb45ee9de7df6ac4a6967062d7cac2c8d136cd2774a04971"
        ),

        .binaryTarget(
            name: "Libdovi",
            url: "https://github.com/mpvkit/libdovi-build/releases/download/3.3.0/Libdovi.xcframework.zip",
            checksum: "ca4382ea4e17103fbcc979d0ddee69a6eb8967c0ab235cb786ffa96da5f512ed"
        ),

        .binaryTarget(
            name: "MoltenVK",
            url: "https://github.com/mpvkit/moltenvk-build/releases/download/1.2.11/MoltenVK.xcframework.zip",
            checksum: "903b476d4d89d35ed0ce413f7514f54e3d8db9f3e7bd126896f74d07fa4134a1"
        ),

        .binaryTarget(
            name: "Libshaderc_combined",
            url: "https://github.com/mpvkit/libshaderc-build/releases/download/2024.2.0/Libshaderc_combined.xcframework.zip",
            checksum: "1ccd9fce68ea29af030dceb824716fc16d1f4dcdc0b912ba366d5cb91d7b1add"
        ),

        .binaryTarget(
            name: "lcms2",
            url: "https://github.com/mpvkit/libplacebo-build/releases/download/7.349.0/lcms2.xcframework.zip",
            checksum: "bd2c27366f8b7adfe7bf652a922599891c55b82f5c519bcc4eece1ccff57c889"
        ),

        .binaryTarget(
            name: "Libplacebo",
            url: "https://github.com/mpvkit/libplacebo-build/releases/download/7.349.0/Libplacebo.xcframework.zip",
            checksum: "f32d20351289a080cd7288742747cd927553fde8c217f63263b838083d07a01a"
        ),

        .binaryTarget(
            name: "Libdav1d",
            url: "https://github.com/mpvkit/libdav1d-build/releases/download/1.4.3/Libdav1d.xcframework.zip",
            checksum: "eccfe37da9418e350bc6c1566890fa5b9585fbb87b8ceb664de77800ef17fe04"
        ),

        .binaryTarget(
            name: "Libavcodec",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libavcodec.xcframework.zip",
            checksum: "c895c3fb25a42faf25686d73e4f90979e9ee3ee1de7808d1575a2a79cd24739a"
        ),
        .binaryTarget(
            name: "Libavdevice",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libavdevice.xcframework.zip",
            checksum: "b92f6156ab11c0e72e34d24f9dd1b45e361e74556fadae9d98e72f90f39129fc"
        ),
        .binaryTarget(
            name: "Libavformat",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libavformat.xcframework.zip",
            checksum: "a63f7c08f61e3ade1d9dcba0d2a77c98c479d8eedb5a3a1218c98f170bb25a86"
        ),
        .binaryTarget(
            name: "Libavfilter",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libavfilter.xcframework.zip",
            checksum: "f2311b33e0b56ff50499c026d0a8e993cb1c1177aa79b6b0105077393eccae79"
        ),
        .binaryTarget(
            name: "Libavutil",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libavutil.xcframework.zip",
            checksum: "712dfba389ac2e67e64dd8d96d0448b725162218efeddd3be9e21ee9267b1120"
        ),
        .binaryTarget(
            name: "Libswresample",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libswresample.xcframework.zip",
            checksum: "4e36f9001f66af087bd2ce9441417c86e7732947abc185ab2024e69b9c1e73ad"
        ),
        .binaryTarget(
            name: "Libswscale",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libswscale.xcframework.zip",
            checksum: "d7b412ba6ab306cbe3c375389f646eb2e44a3ce07a69179a7c99cbbefa3ad954"
        ),

        .binaryTarget(
            name: "Libuchardet",
            url: "https://github.com/mpvkit/libuchardet-build/releases/download/0.0.8/Libuchardet.xcframework.zip",
            checksum: "80b14d8080c2531ced6d6b234a826c13f0be459a8c751815f68e0eefd34afa30"
        ),

        .binaryTarget(
            name: "Libluajit",
            url: "https://github.com/mpvkit/libluajit-build/releases/download/2.1.0/Libluajit.xcframework.zip",
            checksum: "3765d7c6392b4f9a945b334ed593747b8adb9345078717ecfb6d7d12114a0f9e"
        ),

        .binaryTarget(
            name: "Libmpv",
            url: "https://github.com/mpvkit/MPVKit/releases/download/0.39.0-resize1/Libmpv.xcframework.zip",
            checksum: "f9a5d58ea9271c94ac7800ef655e929ae8370ccbcdc3f69fcc98bdd3afdd6cf2"
        ),
        //AUTO_GENERATE_TARGETS_END//
    ]
)
