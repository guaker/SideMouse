import AppKit
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let c = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a).cgColor }
func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil) }
c.saveGState()
c.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: color(0.02,0.08,0.22,0.25))
c.addPath(rounded(CGRect(x: 60,y: 60,width: 904,height: 904),204)); c.setFillColor(color(0.12,0.22,0.55)); c.fillPath()
c.restoreGState()
c.saveGState(); c.addPath(rounded(CGRect(x: 60,y: 60,width: 904,height: 904),204)); c.clip()
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0.12,0.16,0.35),color(0.18,0.36,0.78),color(0.31,0.52,0.97)] as CFArray, locations: [0,0.6,1])!
c.drawLinearGradient(gradient, start: CGPoint(x:100,y:50), end: CGPoint(x:900,y:1000), options: [])
c.restoreGState()
// Recognizable mouse body; two cyan side buttons are the only controls emphasized.
c.saveGState(); c.setShadow(offset: CGSize(width:0,height:-14),blur:28,color:color(0.02,0.06,0.20,0.3))
c.addPath(rounded(CGRect(x:348,y:244,width:328,height:548),156)); c.setFillColor(color(0.96,0.98,1)); c.fillPath(); c.restoreGState()
c.setStrokeColor(color(0.79,0.84,0.93)); c.setLineWidth(8)
c.move(to:CGPoint(x:512,y:782));c.addLine(to:CGPoint(x:512,y:618));c.strokePath()
c.addPath(rounded(CGRect(x:490,y:657,width:44,height:88),22));c.setFillColor(color(0.16,0.27,0.48));c.fillPath()
for y in [568,474] { c.addPath(rounded(CGRect(x:331,y:y,width:38,height:72),17));c.setFillColor(color(0.20,0.90,0.94));c.fillPath() }
// Broad chevrons remain legible at small sizes.
c.setLineWidth(25);c.setLineCap(.round);c.setLineJoin(.round);c.setStrokeColor(color(0.80,0.98,1))
c.move(to:CGPoint(x:258,y:579));c.addLine(to:CGPoint(x:204,y:525));c.addLine(to:CGPoint(x:258,y:471))
c.move(to:CGPoint(x:766,y:579));c.addLine(to:CGPoint(x:820,y:525));c.addLine(to:CGPoint(x:766,y:471));c.strokePath()
let image = c.makeImage()!
let dest = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest,image,nil)
precondition(CGImageDestinationFinalize(dest))
