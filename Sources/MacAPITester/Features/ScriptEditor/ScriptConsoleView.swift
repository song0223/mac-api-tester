import SwiftUI

struct ScriptConsoleView: View {
    let output: String
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("控制台")
                    .font(.headline)
                
                Spacer()
                
                Button(isExpanded ? "收起" : "展开") {
                    isExpanded.toggle()
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            
            if isExpanded {
                ScrollView {
                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(minHeight: 150)
                .background(Color.black.opacity(0.05))
            }
        }
    }
}
