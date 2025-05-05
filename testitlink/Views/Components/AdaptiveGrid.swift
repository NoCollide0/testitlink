import SwiftUI

struct AdaptiveGrid<Item: Identifiable, ItemView: View>: View {
    private let items: [Item]
    private let spacing: CGFloat
    private let cellWidth: CGFloat
    private let content: (Item) -> ItemView
    
    init(
        items: [Item],
        spacing: CGFloat = 10,
        cellWidth: CGFloat = 120,
        @ViewBuilder content: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.spacing = spacing
        self.cellWidth = cellWidth
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                let width = geometry.size.width
                let columnsCount = max(1, Int(width / cellWidth))
                let actualCellWidth = (width - (spacing * CGFloat(columnsCount - 1))) / CGFloat(columnsCount)
                
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: spacing),
                        count: columnsCount
                    ),
                    spacing: spacing
                ) {
                    ForEach(items) { item in
                        content(item)
                            .frame(height: actualCellWidth)
                    }
                }
                .padding()
            }
        }
    }
} 