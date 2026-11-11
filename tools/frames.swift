import AVFoundation
import AppKit
let args = CommandLine.arguments
let url = URL(fileURLWithPath: args[1])
let outDir = args[2]
let fps = Double(args[3]) ?? 24
let asset = AVURLAsset(url: url)
let gen = AVAssetImageGenerator(asset: asset)
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
gen.appliesPreferredTrackTransform = true
let dur = CMTimeGetSeconds(asset.duration)
var i = 0
var t = 0.0
while t < dur {
    let time = CMTime(seconds: t, preferredTimescale: 600)
    if let cg = try? gen.copyCGImage(at: time, actualTime: nil) {
        let rep = NSBitmapImageRep(cgImage: cg)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: String(format: "%@/f%03d.png", outDir, i)))
        }
    }
    i += 1
    t += 1.0 / fps
}
print("frames", i, "duration", dur)
