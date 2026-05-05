import Foundation
import SwiftUI
import simd

enum SVGImporterError: Error {
    case invalidUTF8
    case parseFailed
}

struct SVGImporter {
    func importSVG(from url: URL) throws -> [ImportedVectorShape] {
        let data = try Data(contentsOf: url)
        return try importSVG(from: data)
    }

    func importSVG(from data: Data) throws -> [ImportedVectorShape] {
        let parserDelegate = SVGLineParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate

        guard parser.parse() else {
            throw parser.parserError ?? SVGImporterError.parseFailed
        }

        return parserDelegate.shapes.map { shape in
            let vectorShape = VectorShape(
                canvasSize: parserDelegate.canvasSize,
                viewBoxOrigin: shape.viewBoxOrigin ?? parserDelegate.viewBoxOrigin,
                viewBoxSize: shape.viewBoxSize ?? parserDelegate.viewBoxSize,
                fillColor: shape.fillColor,
                pathSegments: shape.pathSegments
            )
            let vectorPath = shape.pathData.map {
                VectorPath(
                    path: $0,
                    viewBoxOrigin: shape.viewBoxOrigin ?? parserDelegate.viewBoxOrigin,
                    viewBoxSize: shape.viewBoxSize ?? parserDelegate.viewBoxSize
                    ,
                    usesAutomaticViewBox: shape.usesAutomaticViewBox
                )
            }

            return ImportedVectorShape(
                vectorShape: vectorShape,
                vectorPath: vectorPath
            )
        }
    }
}

private final class SVGLineParserDelegate: NSObject, XMLParserDelegate {
    private(set) var canvasSize = SIMD2<Float>(1024, 1024)
    private(set) var viewBoxOrigin = SIMD2<Float>(0, 0)
    private(set) var viewBoxSize = SIMD2<Float>(1024, 1024)
    private(set) var hasExplicitViewBox = false
    private(set) var shapes: [ParsedShape] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "svg":
            parseCanvasSize(attributes: attributeDict)
        case "line":
            parseLine(attributes: attributeDict)
        case "rect":
            parseRect(attributes: attributeDict)
        case "circle":
            parseCircle(attributes: attributeDict)
        case "ellipse":
            parseEllipse(attributes: attributeDict)
        case "path":
            parsePath(attributes: attributeDict)
        default:
            break
        }
    }

    private func parseCanvasSize(attributes: [String: String]) {
        let parsedWidth = parseFloat(attributes["width"])
        let parsedHeight = parseFloat(attributes["height"])

        if
            let viewBox = attributes["viewBox"],
            let parsedViewBox = parseViewBox(viewBox)
        {
            viewBoxOrigin = parsedViewBox.origin
            viewBoxSize = parsedViewBox.size
            hasExplicitViewBox = true
        } else if let parsedWidth, let parsedHeight {
            viewBoxOrigin = .zero
            viewBoxSize = SIMD2(parsedWidth, parsedHeight)
        }

        let width = parsedWidth ?? viewBoxSize.x
        let height = parsedHeight ?? viewBoxSize.y
        canvasSize = SIMD2(width, height)
    }

    private func parseLine(attributes: [String: String]) {
        guard
            let x1 = parseFloat(attributes["x1"]),
            let y1 = parseFloat(attributes["y1"]),
            let x2 = parseFloat(attributes["x2"]),
            let y2 = parseFloat(attributes["y2"])
        else {
            return
        }

        let fillColor = resolvedStrokeColor(
            stroke: attributes["stroke"],
            opacity: attributes["opacity"]
        ) ?? Color.white

        shapes.append(
            ParsedShape(
                fillColor: fillColor,
                viewBoxOrigin: nil,
                viewBoxSize: nil,
                pathData: "M \(x1) \(y1) L \(x2) \(y2)",
                usesAutomaticViewBox: !hasExplicitViewBox,
                pathSegments: [
                    .line(
                        VectorSegment(
                            start: SIMD2(x1, y1),
                            end: SIMD2(x2, y2)
                        )
                    )
                ]
            )
        )
    }

    private func parsePath(attributes: [String: String]) {
        guard let data = attributes["d"] else {
            return
        }

        let fillColor = resolvedFillColor(
            fill: attributes["fill"],
            opacity: attributes["opacity"],
            defaultWhenMissing: true
        )

        guard fillColor != nil else {
            return
        }
        let parser = SVGPathDataParser(pathData: data)
        let pathSegments = parser.makeSegments()

        guard !pathSegments.isEmpty else {
            return
        }

        let automaticBounds = !hasExplicitViewBox ? pathBounds(for: pathSegments) : nil

        shapes.append(
            ParsedShape(
                fillColor: fillColor,
                viewBoxOrigin: automaticBounds?.origin,
                viewBoxSize: automaticBounds?.size,
                pathData: data,
                usesAutomaticViewBox: !hasExplicitViewBox,
                pathSegments: pathSegments
            )
        )
    }

    private func parseRect(attributes: [String: String]) {
        let x = parseFloat(attributes["x"]) ?? 0
        let y = parseFloat(attributes["y"]) ?? 0

        guard
            let width = parseFloat(attributes["width"]),
            let height = parseFloat(attributes["height"]),
            width > 0,
            height > 0
        else {
            return
        }

        let path = """
        M \(x) \(y) \
        L \(x + width) \(y) \
        L \(x + width) \(y + height) \
        L \(x) \(y + height) Z
        """
        parsePath(attributes: attributes.merging(["d": path]) { _, new in new })
    }

    private func parseCircle(attributes: [String: String]) {
        guard
            let cx = parseFloat(attributes["cx"]),
            let cy = parseFloat(attributes["cy"]),
            let radius = parseFloat(attributes["r"]),
            radius > 0
        else {
            return
        }

        parseEllipsePath(cx: cx, cy: cy, rx: radius, ry: radius, attributes: attributes)
    }

    private func parseEllipse(attributes: [String: String]) {
        guard
            let cx = parseFloat(attributes["cx"]),
            let cy = parseFloat(attributes["cy"]),
            let rx = parseFloat(attributes["rx"]),
            let ry = parseFloat(attributes["ry"]),
            rx > 0,
            ry > 0
        else {
            return
        }

        parseEllipsePath(cx: cx, cy: cy, rx: rx, ry: ry, attributes: attributes)
    }

    private func parseEllipsePath(
        cx: Float,
        cy: Float,
        rx: Float,
        ry: Float,
        attributes: [String: String]
    ) {
        let kappa: Float = 0.55228475
        let controlX = rx * kappa
        let controlY = ry * kappa

        let path = """
        M \(cx) \(cy - ry) \
        C \(cx + controlX) \(cy - ry) \(cx + rx) \(cy - controlY) \(cx + rx) \(cy) \
        C \(cx + rx) \(cy + controlY) \(cx + controlX) \(cy + ry) \(cx) \(cy + ry) \
        C \(cx - controlX) \(cy + ry) \(cx - rx) \(cy + controlY) \(cx - rx) \(cy) \
        C \(cx - rx) \(cy - controlY) \(cx - controlX) \(cy - ry) \(cx) \(cy - ry) Z
        """
        parsePath(attributes: attributes.merging(["d": path]) { _, new in new })
    }

    private func parseViewBox(_ value: String) -> SVGViewBox? {
        let parts = value
            .split(whereSeparator: \.isWhitespace)
            .compactMap { Float($0) }

        guard parts.count == 4 else {
            return nil
        }

        return SVGViewBox(
            origin: SIMD2(parts[0], parts[1]),
            size: SIMD2(parts[2], parts[3])
        )
    }

    private func parseFloat(_ value: String?) -> Float? {
        guard let trimmedValue = value?
            .replacingOccurrences(of: "px", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return nil
        }

        return Float(trimmedValue)
    }

    private func parseColor(_ value: String?) -> Color? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue == "none" {
            return nil
        }

        guard trimmedValue.hasPrefix("#") else {
            return nil
        }

        let hex = String(trimmedValue.dropFirst())

        guard hex.count == 6, let rawValue = UInt32(hex, radix: 16) else {
            return nil
        }

        let red = Double((rawValue >> 16) & 0xff) / 255
        let green = Double((rawValue >> 8) & 0xff) / 255
        let blue = Double(rawValue & 0xff) / 255

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    private func resolvedStrokeColor(
        stroke: String?,
        opacity: String?
    ) -> Color? {
        guard var color = parseColor(stroke) else {
            return nil
        }

        if let opacity = parseFloat(opacity) {
            color = color.opacity(Double(opacity))
        }

        return color
    }

    private func resolvedFillColor(
        fill: String?,
        opacity: String?,
        defaultWhenMissing: Bool = false
    ) -> Color? {
        var color: Color?

        if let fill {
            color = parseColor(fill)
        } else if defaultWhenMissing {
            color = .black
        }

        guard var color else {
            return nil
        }

        if let opacity = parseFloat(opacity) {
            color = color.opacity(Double(opacity))
        }

        return color
    }
}

private struct ParsedShape {
    let fillColor: Color?
    let viewBoxOrigin: SIMD2<Float>?
    let viewBoxSize: SIMD2<Float>?
    let pathData: String?
    let usesAutomaticViewBox: Bool
    let pathSegments: [VectorPathSegment]
}

struct SVGViewBox {
    let origin: SIMD2<Float>
    let size: SIMD2<Float>
}

struct ImportedVectorShape {
    let vectorShape: VectorShape
    let vectorPath: VectorPath?
}

func parseVectorPathData(_ pathData: String) -> [VectorPathSegment] {
    SVGPathDataParser(pathData: pathData).makeSegments()
}

func pathBounds(for pathSegments: [VectorPathSegment]) -> SVGViewBox? {
    let segments = pathSegments.flatMap { $0.flattenedSegments(canvasScale: SIMD2<Float>(1, 1)) }
    guard !segments.isEmpty else {
        return nil
    }

    let xs = segments.flatMap { [$0.start.x, $0.end.x] }
    let ys = segments.flatMap { [$0.start.y, $0.end.y] }

    guard
        let minX = xs.min(),
        let maxX = xs.max(),
        let minY = ys.min(),
        let maxY = ys.max()
    else {
        return nil
    }

    return SVGViewBox(
        origin: SIMD2(minX, minY),
        size: SIMD2(max(maxX - minX, 1), max(maxY - minY, 1))
    )
}

private struct SVGPathDataParser {
    private let pathData: String

    init(pathData: String) {
        self.pathData = pathData
    }

    func makeSegments() -> [VectorPathSegment] {
        let tokens = tokenize(pathData)
        var index = 0
        var segments: [VectorPathSegment] = []
        var currentPoint = SIMD2<Float>(repeating: 0)
        var subpathStart = SIMD2<Float>(repeating: 0)
        var activeCommand: Character?
        var previousCubicControl: SIMD2<Float>?

        while index < tokens.count {
            if let command = tokens[index].command {
                activeCommand = command
                index += 1
            }

            guard let command = activeCommand else {
                break
            }

            switch command {
            case "M", "m":
                guard
                    let x = tokens[safe: index]?.number,
                    let y = tokens[safe: index + 1]?.number
                else {
                    return segments
                }

                let point = command == "m"
                    ? currentPoint + SIMD2(x, y)
                    : SIMD2(x, y)
                currentPoint = point
                subpathStart = point
                previousCubicControl = nil
                index += 2
                activeCommand = command == "m" ? "l" : "L"

            case "L", "l":
                guard
                    let x = tokens[safe: index]?.number,
                    let y = tokens[safe: index + 1]?.number
                else {
                    return segments
                }

                let nextPoint = command == "l"
                    ? currentPoint + SIMD2(x, y)
                    : SIMD2(x, y)
                segments.append(
                    .line(
                        VectorSegment(
                            start: currentPoint,
                            end: nextPoint
                        )
                    )
                )
                currentPoint = nextPoint
                previousCubicControl = nil
                index += 2

            case "H", "h":
                guard let x = tokens[safe: index]?.number else {
                    return segments
                }

                let nextPoint = SIMD2<Float>(
                    command == "h" ? currentPoint.x + x : x,
                    currentPoint.y
                )
                segments.append(
                    .line(
                        VectorSegment(
                            start: currentPoint,
                            end: nextPoint
                        )
                    )
                )
                currentPoint = nextPoint
                previousCubicControl = nil
                index += 1

            case "V", "v":
                guard let y = tokens[safe: index]?.number else {
                    return segments
                }

                let nextPoint = SIMD2<Float>(
                    currentPoint.x,
                    command == "v" ? currentPoint.y + y : y
                )
                segments.append(
                    .line(
                        VectorSegment(
                            start: currentPoint,
                            end: nextPoint
                        )
                    )
                )
                currentPoint = nextPoint
                previousCubicControl = nil
                index += 1

            case "Q", "q":
                guard
                    let cx = tokens[safe: index]?.number,
                    let cy = tokens[safe: index + 1]?.number,
                    let x = tokens[safe: index + 2]?.number,
                    let y = tokens[safe: index + 3]?.number
                else {
                    return segments
                }

                let control = command == "q"
                    ? currentPoint + SIMD2(cx, cy)
                    : SIMD2(cx, cy)
                let nextPoint = command == "q"
                    ? currentPoint + SIMD2(x, y)
                    : SIMD2(x, y)
                segments.append(
                    .quadratic(
                        VectorQuadraticSegment(
                            start: currentPoint,
                            control: control,
                            end: nextPoint
                        )
                    )
                )
                currentPoint = nextPoint
                previousCubicControl = nil
                index += 4

            case "C", "c":
                guard
                    let c1x = tokens[safe: index]?.number,
                    let c1y = tokens[safe: index + 1]?.number,
                    let c2x = tokens[safe: index + 2]?.number,
                    let c2y = tokens[safe: index + 3]?.number,
                    let x = tokens[safe: index + 4]?.number,
                    let y = tokens[safe: index + 5]?.number
                else {
                    return segments
                }

                let control1 = command == "c"
                    ? currentPoint + SIMD2(c1x, c1y)
                    : SIMD2(c1x, c1y)
                let control2 = command == "c"
                    ? currentPoint + SIMD2(c2x, c2y)
                    : SIMD2(c2x, c2y)
                let nextPoint = command == "c"
                    ? currentPoint + SIMD2(x, y)
                    : SIMD2(x, y)
                segments.append(
                    .cubic(
                        VectorCubicSegment(
                            start: currentPoint,
                            control1: control1,
                            control2: control2,
                            end: nextPoint
                        )
                    )
                )
                currentPoint = nextPoint
                previousCubicControl = control2
                index += 6

            case "S", "s":
                guard
                    let c2x = tokens[safe: index]?.number,
                    let c2y = tokens[safe: index + 1]?.number,
                    let x = tokens[safe: index + 2]?.number,
                    let y = tokens[safe: index + 3]?.number
                else {
                    return segments
                }

                let control1 = if let previousCubicControl {
                    currentPoint + (currentPoint - previousCubicControl)
                } else {
                    currentPoint
                }
                let control2 = command == "s"
                    ? currentPoint + SIMD2(c2x, c2y)
                    : SIMD2(c2x, c2y)
                let nextPoint = command == "s"
                    ? currentPoint + SIMD2(x, y)
                    : SIMD2(x, y)
                segments.append(
                    .cubic(
                        VectorCubicSegment(
                            start: currentPoint,
                            control1: control1,
                            control2: control2,
                            end: nextPoint
                        )
                    )
                )
                currentPoint = nextPoint
                previousCubicControl = control2
                index += 4

            case "Z", "z":
                segments.append(
                    .line(
                        VectorSegment(
                            start: currentPoint,
                            end: subpathStart
                        )
                    )
                )
                currentPoint = subpathStart
                previousCubicControl = nil

            default:
                return segments
            }
        }

        return segments
    }

    private func tokenize(_ value: String) -> [PathToken] {
        var tokens: [PathToken] = []
        var currentNumber = ""

        func flushNumber() {
            guard !currentNumber.isEmpty, let number = Float(currentNumber) else {
                currentNumber = ""
                return
            }

            tokens.append(.number(number))
            currentNumber = ""
        }

        for scalar in value.unicodeScalars {
            let character = Character(scalar)

            if character.isSVGPathCommand {
                flushNumber()
                tokens.append(.command(character))
                continue
            }

            if character == "-" {
                flushNumber()
                currentNumber.append(character)
                continue
            }

            if character == "." {
                if currentNumber.contains(".") {
                    flushNumber()
                }
                currentNumber.append(character)
                continue
            }

            if character.isWholeNumber {
                currentNumber.append(character)
                continue
            }

            if character == "," || character.isWhitespace {
                flushNumber()
            }
        }

        flushNumber()
        return tokens
    }
}

private enum PathToken {
    case command(Character)
    case number(Float)

    var command: Character? {
        if case let .command(value) = self {
            return value
        }

        return nil
    }

    var number: Float? {
        if case let .number(value) = self {
            return value
        }

        return nil
    }
}

private extension Character {
    var isSVGPathCommand: Bool {
        "MmLlHhVvQqCcSsZz".contains(self)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}
