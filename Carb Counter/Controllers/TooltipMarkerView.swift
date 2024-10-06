import UIKit
import DGCharts

class TooltipMarkerView: MarkerView {

    private var text: String = ""

    private let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.darkGray.withAlphaComponent(0.7)
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // Called when the marker is drawn. Use this to update the position.
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        // Customize the text to be displayed in the tooltip
        text = String(format: "%.0f g", entry.y) // For example, show the carbs value
        label.text = text
        label.sizeToFit()
    }

    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        // Position the tooltip directly above the tapped point and center horizontally
        let xOffset = -label.frame.size.width / 2
        let yOffset = -label.frame.size.height - 10
        return CGPoint(x: xOffset, y: yOffset)
    }

    override func draw(context: CGContext, point: CGPoint) {
        // Ensure the tooltip stays within bounds of the chart
        let labelWidth = label.frame.size.width + 10
        let labelHeight = label.frame.size.height + 6
        let x = point.x - labelWidth / 2
        let y = point.y - labelHeight - 10

        // Clamp the position to keep the tooltip from going off the screen
        let clampedX = max(10, min(x, self.bounds.size.width - labelWidth - 10))
        let clampedY = max(10, y)

        // Update the label's frame
        label.frame = CGRect(x: clampedX, y: clampedY, width: labelWidth, height: labelHeight)

        super.draw(context: context, point: point)
    }
}
