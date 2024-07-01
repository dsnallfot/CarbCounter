import UIKit

class FoodItemTableViewCell: UITableViewCell {
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        contentView.addSubview(nameLabel)
        contentView.addSubview(detailsLabel)
        
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            
            detailsLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            detailsLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            detailsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with foodItem: FoodItem) {
        nameLabel.text = foodItem.name ?? ""
        
        var details = [String]()
        
        if foodItem.perPiece {
            if foodItem.carbsPP > 0 {
                details.append("Kh \(String(format: "%.0f", foodItem.carbsPP))g/st")
            }
            if foodItem.fatPP > 0 {
                details.append("Fett \(String(format: "%.0f", foodItem.fatPP))g/st")
            }
            if foodItem.proteinPP > 0 {
                details.append("Protein \(String(format: "%.0f", foodItem.proteinPP))g/st")
            }
        } else {
            if foodItem.carbohydrates > 0 {
                details.append("Kh \(String(format: "%.0f", foodItem.carbohydrates))g/100g")
            }
            if foodItem.fat > 0 {
                details.append("Fett \(String(format: "%.0f", foodItem.fat))g/100g")
            }
            if foodItem.protein > 0 {
                details.append("Protein \(String(format: "%.0f", foodItem.protein))g/100g")
            }
        }
        
        detailsLabel.text = details.joined(separator: " • ")
    }
}
