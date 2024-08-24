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
        
        // Start the first detail with "ⓘ" if the food item has notes
        var firstDetail: String? = nil
        if let notes = foodItem.notes, !notes.isEmpty {
            firstDetail = "ⓘ"
        }
        
        if foodItem.perPiece {
            if foodItem.carbsPP > 0 {
                let carbsDetail = String(format: NSLocalizedString("Kh %.0fg/st", comment: "Carbohydrates per piece"), foodItem.carbsPP)
                details.append(firstDetail != nil ? "\(firstDetail!) \(carbsDetail)" : carbsDetail)
                firstDetail = nil
            }
            if foodItem.fatPP > 0 {
                let fatDetail = String(format: NSLocalizedString("Fett %.0fg/st", comment: "Fat per piece"), foodItem.fatPP)
                details.append(firstDetail != nil ? "\(firstDetail!) \(fatDetail)" : fatDetail)
                firstDetail = nil
            }
            if foodItem.proteinPP > 0 {
                let proteinDetail = String(format: NSLocalizedString("Protein %.0fg/st", comment: "Protein per piece"), foodItem.proteinPP)
                details.append(firstDetail != nil ? "\(firstDetail!) \(proteinDetail)" : proteinDetail)
                firstDetail = nil
            }
        } else {
            if foodItem.carbohydrates > 0 {
                let carbsDetail = String(format: NSLocalizedString("Kh %.0fg/100g", comment: "Carbohydrates per 100 grams"), foodItem.carbohydrates)
                details.append(firstDetail != nil ? "\(firstDetail!) \(carbsDetail)" : carbsDetail)
                firstDetail = nil
            }
            if foodItem.fat > 0 {
                let fatDetail = String(format: NSLocalizedString("Fett %.0fg/100g", comment: "Fat per 100 grams"), foodItem.fat)
                details.append(firstDetail != nil ? "\(firstDetail!) \(fatDetail)" : fatDetail)
                firstDetail = nil
            }
            if foodItem.protein > 0 {
                let proteinDetail = String(format: NSLocalizedString("Protein %.0fg/100g", comment: "Protein per 100 grams"), foodItem.protein)
                details.append(firstDetail != nil ? "\(firstDetail!) \(proteinDetail)" : proteinDetail)
                firstDetail = nil
            }
        }
        
        detailsLabel.text = details.joined(separator: " | ")
    }
}
