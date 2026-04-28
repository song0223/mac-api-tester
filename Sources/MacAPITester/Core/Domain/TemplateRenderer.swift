import Foundation

struct TemplateRenderer {
    func render(_ template: String, variables: [String: String]) throws -> String {
        let pattern = #"\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}"#
        let regex = try NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(template.startIndex..<template.endIndex, in: template)
        let matches = regex.matches(in: template, range: nsRange)

        var result = ""
        var currentIndex = template.startIndex
        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: template),
                  let nameRange = Range(match.range(at: 1), in: template) else {
                continue
            }

            result += template[currentIndex..<fullRange.lowerBound]

            let variableName = String(template[nameRange])
            guard let replacement = variables[variableName] else {
                throw TemplateRendererError.missingVariable(variableName)
            }

            result += replacement
            currentIndex = fullRange.upperBound
        }

        result += template[currentIndex..<template.endIndex]
        return result
    }
}
