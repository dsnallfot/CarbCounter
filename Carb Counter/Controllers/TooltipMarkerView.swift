import UIKit
import DGCharts

class TooltipMarkerView: MarkerView {
    private var text: String?
    private let padding: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        if let meal = entry.data as? MealHistory {
            // Existing code for MealHistory
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM"
            let date = Date(timeIntervalSince1970: entry.x)
            let dateString = dateFormatter.string(from: date)
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: date)
            
            // Construct the tooltip text with additional information
            text = String(format: NSLocalizedString("%@ %@\nKh: %.0f g\nFett: %.0f g\nProtein: %.0f g\nBolus: %.2f E", comment: "tooltip string"),
                          dateString,
                          timeString,
                          entry.y, // Carbs value from entry.y
                          meal.totalNetFat,
                          meal.totalNetProtein,
                          meal.totalNetBolus)
        } else if let foodEntry = entry.data as? FoodItemEntry {
            // New code for FoodItemEntry
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM"
            let date = Date(timeIntervalSince1970: entry.x)
            let dateString = dateFormatter.string(from: date)
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: date)
            
            let portionValue = foodEntry.entryPortionServed - foodEntry.entryNotEaten
            let portionFormat = foodEntry.entryPerPiece ? NSLocalizedString("%.1f st", comment: "Per piece portion format") : NSLocalizedString("%.0f g", comment: "Grams portion format")
            let formattedPortion = String(format: portionFormat, portionValue)
            
            // Construct the tooltip text
            text = String(format: NSLocalizedString("%@ %@\nPortion: %@", comment: "tooltip string"),
                          dateString,
                          timeString,
                          formattedPortion)
        } else {
            // Handle the case where data is not available
            text = NSLocalizedString("Data not available", comment: "Fallback tooltip text when data is missing")
        }
    }
    
    override func draw(context: CGContext, point: CGPoint) {
        guard let chartView = self.chartView, let text = self.text else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]

        let textSize = text.size(withAttributes: attributes)

        let size = CGSize(
            width: textSize.width + padding.left + padding.right,
            height: textSize.height + padding.top + padding.bottom
        )

        let offset = self.offsetForDrawing(atPoint: point)

        let rect = CGRect(
            x: point.x + offset.x,
            y: point.y + offset.y,
            width: size.width,
            height: size.height
        )

        // Create rounded rectangle path
        let cornerRadius: CGFloat = 8.0
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        // Draw background (fill)
        context.saveGState()
        context.setFillColor(UIColor.systemGray4.withAlphaComponent(0.8).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
        context.restoreGState()

        // Draw border (stroke)
        context.saveGState()
        context.setStrokeColor(UIColor.gray.cgColor)
        context.setLineWidth(1.0) // Thin border
        context.addPath(path.cgPath)
        context.strokePath()
        context.restoreGState()

        // Draw text
        let textRect = CGRect(
            x: rect.origin.x + padding.left,
            y: rect.origin.y + padding.top,
            width: textSize.width,
            height: textSize.height
        )

        NSString(string: text).draw(in: textRect, withAttributes: attributes)
    }

    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        guard let chartView = self.chartView else { return .zero }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
        ]

        let textSize = text?.size(withAttributes: attributes) ?? CGSize.zero

        let size = CGSize(
            width: textSize.width + padding.left + padding.right,
            height: textSize.height + padding.top + padding.bottom
        )
        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0

        // Determine x position
        if point.x + size.width > chartView.bounds.width {
            xOffset = -(size.width + 5) // 5 pixels padding
        } else {
            xOffset = 5 // 5 pixels padding
        }

        // Determine y position
        if point.y - size.height - 5 < 0 {
            yOffset = 5 // 5 pixels below the point
        } else {
            yOffset = -(size.height + 5) // 5 pixels above the point
        }

        return CGPoint(x: xOffset, y: yOffset)
    }
}
