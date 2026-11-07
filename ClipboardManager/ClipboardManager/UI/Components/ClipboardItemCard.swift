import SwiftUI

/// 单条历史记录卡片
/// 点击复制；悬停显示置顶/删除；复制成功有勾选反馈
struct ClipboardItemCard: View {
    let item: ClipboardItem

    @State private var isHovering = false
    @State private var showCopied = false
    @State private var missingFileNames: [String] = []
    @State private var showFileMissingAlert = false

    var body: some View {
        HStack(spacing: 10) {
            if item.isPinned {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.tint)
                    .frame(width: 3)
                    .padding(.vertical, 2)
            }

            HStack(spacing: 6) {
                typeIcon
                Text(item.preview)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            if isHovering {
                HStack(spacing: 4) {
                    Button {
                        ClipboardActions.togglePin(item)
                    } label: {
                        Image(systemName: item.isPinned ? "pin.slash" : "pin")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 20, height: 20)
                    .help(item.isPinned ? "取消置顶" : "置顶")

                    Button {
                        ClipboardActions.delete(item)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 20, height: 20)
                    .help("删除")
                }
            }

            if showCopied {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.05) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture(perform: handleTap)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .alert("文件已被移动或删除", isPresented: $showFileMissingAlert) {
            Button("确定", role: .cancel) {
                ClipboardActions.delete(item)
            }
        } message: {
            Text("无法找到以下文件：\n\(missingFileNames.joined(separator: "\n"))")
        }
    }

    // MARK: - 类型图标

    private var typeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(typeIconColor.opacity(0.15))
                .frame(width: 28, height: 28)
            Image(systemName: typeIconName)
                .font(.caption.weight(.medium))
                .foregroundStyle(typeIconColor)
        }
    }

    private var typeIconColor: Color {
        switch item.type {
        case .text:
            return .blue
        case .image:
            return .green
        case .file:
            if item.isImageFile { return .green }
            switch item.fileExtension {
            case "pdf":
                return .red
            case "doc", "docx", "txt", "rtf":
                return .blue
            case "xls", "xlsx", "csv":
                return .green
            case "ppt", "pptx":
                return .orange
            case "swift", "py", "js", "html", "css", "json":
                return .purple
            default:
                return .gray
            }
        }
    }

    private var typeIconName: String {
        switch item.type {
        case .text:
            return "text.alignleft"
        case .image:
            return "photo"
        case .file:
            if item.isFolder { return "folder" }
            if item.isImageFile { return "photo" }
            switch item.fileExtension {
            case "pdf", "doc", "docx", "txt", "rtf":
                return "doc.text"
            case "xls", "xlsx", "csv":
                return "tablecells"
            case "ppt", "pptx":
                return "rectangle.on.rectangle"
            case "swift", "py", "js", "html", "css", "json":
                return "chevron.left.forward.slash.chevron.right"
            case "zip", "rar", "7z", "tar", "gz":
                return "archivebox"
            default:
                return "doc"
            }
        }
    }

    // MARK: - 交互

    private func handleTap() {
        switch ClipboardActions.copy(item) {
        case .success:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation {
                    showCopied = false
                }
            }
        case .fileMissing(let names):
            missingFileNames = names.isEmpty ? [item.preview] : names
            showFileMissingAlert = true
        }
    }
}

#Preview {
    VStack {
        ClipboardItemCard(item: ClipboardItem(text: "这是一条文本记录预览"))
        ClipboardItemCard(item: ClipboardItem(
            filePaths: ["/tmp/report.pdf"],
            fileNames: ["report.pdf"]
        ))
    }
    .frame(width: 360)
    .padding()
}
