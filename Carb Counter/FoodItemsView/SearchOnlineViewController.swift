import UIKit
import CoreData


 /*
 class SearchOnlineViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
 private let searchTextField: UITextField = {
 let textField = UITextField()
 textField.placeholder = "Sök efter livsmedel online"
 textField.borderStyle = .roundedRect
 textField.backgroundColor = .systemGray6
 textField.translatesAutoresizingMaskIntoConstraints = false
 
 let placeholderText = "Sök efter livsmedel online"
 let attributes: [NSAttributedString.Key: Any] = [
 .foregroundColor: UIColor.systemGray
 ]
 textField.attributedPlaceholder = NSAttributedString(string: placeholderText, attributes: attributes)
 
 return textField
 }()
 
 private let searchButton: UIButton = {
 let button = UIButton(type: .system)
 button.setTitle("Sök", for: .normal)
 button.setTitleColor(.white, for: .normal)
 button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
 button.backgroundColor = .systemBlue
 button.layer.cornerRadius = 10
 button.translatesAutoresizingMaskIntoConstraints = false
 return button
 }()
 
 private let tableView: UITableView = {
 let tableView = UITableView()
 tableView.translatesAutoresizingMaskIntoConstraints = false
 return tableView
 }()
 
 private var articles: [Article] = []
 private var tableViewBottomConstraint: NSLayoutConstraint!
 
 override func viewDidLoad() {
 super.viewDidLoad()
 view.backgroundColor = .systemBackground
 title = "Sök Online"
 
 view.addSubview(searchTextField)
 view.addSubview(searchButton)
 view.addSubview(tableView)
 
 setupConstraints()
 setupSearchTextField()
 setupKeyboardToolbar()
 
 searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
 
 tableView.delegate = self
 tableView.dataSource = self
 tableView.register(ArticleTableViewCell.self, forCellReuseIdentifier: "ArticleCell")
 
 // Add cancel button to the navigation bar
 let cancelButton = UIBarButtonItem(title: "Avbryt", style: .plain, target: self, action: #selector(cancelButtonTapped))
 navigationItem.rightBarButtonItem = cancelButton
 
 // Add observers for keyboard notifications
 NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
 NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
 }
 
 private func setupKeyboardToolbar() {
 let toolbar = UIToolbar()
 toolbar.sizeToFit()
 
 let symbolImage = UIImage(systemName: "keyboard.chevron.compact.down")
 let cancelButton = UIButton(type: .system)
 cancelButton.setImage(symbolImage, for: .normal)
 cancelButton.tintColor = .systemBlue
 cancelButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
 cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
 let cancelBarButtonItem = UIBarButtonItem(customView: cancelButton)
 
 let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
 let doneButton = UIBarButtonItem(title: "Klar", style: .done, target: self, action: #selector(doneButtonTapped))
 
 toolbar.setItems([cancelBarButtonItem, flexSpace, doneButton], animated: false)
 
 searchTextField.inputAccessoryView = toolbar
 }
 
 @objc private func doneButtonTapped() {
 view.endEditing(true)
 }
 
 @objc private func cancelButtonTapped() {
 view.endEditing(true)
 if let navigationController = navigationController {
 navigationController.popViewController(animated: true)
 } else {
 dismiss(animated: true, completion: nil)
 }
 }
 
 @objc private func keyboardWillShow(notification: NSNotification) {
 if let userInfo = notification.userInfo {
 if let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
 tableViewBottomConstraint.constant = -keyboardFrame.height + 2
 view.layoutIfNeeded()
 }
 }
 }
 
 @objc private func keyboardWillHide(notification: NSNotification) {
 tableViewBottomConstraint.constant = 0
 view.layoutIfNeeded()
 }
 
 private func setupConstraints() {
 tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
 
 NSLayoutConstraint.activate([
 searchTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
 searchTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
 searchTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100),
 
 searchButton.centerYAnchor.constraint(equalTo: searchTextField.centerYAnchor),
 searchButton.leadingAnchor.constraint(equalTo: searchTextField.trailingAnchor, constant: 8),
 searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
 searchButton.heightAnchor.constraint(equalToConstant: 36),
 
 tableView.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 16),
 tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
 tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
 tableViewBottomConstraint
 ])
 }
 
 private func setupSearchTextField() {
 let clearButton = UIButton(type: .custom)
 clearButton.setImage(UIImage(systemName: "xmark.circle"), for: .normal)
 clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
 
 let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 24, height: 20)) // Adjust size if needed
 clearButton.frame = CGRect(x: 0, y: 0, width: 20, height: 20) // Adjust size if needed
 paddingView.addSubview(clearButton)
 
 searchTextField.rightView = paddingView
 searchTextField.rightViewMode = .whileEditing
 }
 
 @objc private func clearButtonTapped() {
 searchTextField.text = ""
 }
 
 @objc private func searchButtonTapped() {
 guard let searchString = searchTextField.text, !searchString.isEmpty else { return }
 print("Sökning efter \(searchString) skickades")
 
 let dabasAPISecret = UserDefaultsRepository.dabasAPISecret
 let dabasURLString = "https://api.dabas.com/DABASService/V2/articles/searchparameter/\(searchString)/JSON?apikey=\(dabasAPISecret)"
 
 guard let dabasURL = URL(string: dabasURLString) else {
 showErrorAlert(message: "Felaktig Dabas URL")
 return
 }
 
 let dabasTask = URLSession.shared.dataTask(with: dabasURL) { data, response, error in
 if let error = error {
 DispatchQueue.main.async {
 self.showErrorAlert(message: "Dabas API fel: \(error.localizedDescription)")
 }
 return
 }
 
 guard let data = data else {
 DispatchQueue.main.async {
 self.showErrorAlert(message: "Dabas API fel: Ingen data togs emot")
 }
 return
 }
 
 do {
 let articles = try JSONDecoder().decode([Article].self, from: data)
 let filteredArticles = articles.filter { $0.artikelbenamning != nil }
 print("Filtered Articles: \(filteredArticles)")
 DispatchQueue.main.async {
 self.updateTableView(with: filteredArticles)
 }
 } catch {
 DispatchQueue.main.async {
 self.showErrorAlert(message: "Dabas API fel: \(error.localizedDescription)")
 }
 }
 }
 
 dabasTask.resume()
 }
 
 private func updateTableView(with articles: [Article]) {
 self.articles = articles
 tableView.reloadData()
 }
 
 func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
 return articles.count
 }
 
 func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
 let cell = tableView.dequeueReusableCell(withIdentifier: "ArticleCell", for: indexPath) as! ArticleTableViewCell
 let article = articles[indexPath.row]
 cell.configure(with: article)
 return cell
 }
 
 func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
 let selectedArticle = articles[indexPath.row]
 if let gtin = selectedArticle.gtin {
 fetchNutritionalInfo(for: gtin)
 }
 }
 
 private func fetchNutritionalInfo(for gtin: String) {
 let dabasAPISecret = UserDefaultsRepository.dabasAPISecret
 let dabasURLString = "https://api.dabas.com/DABASService/V2/article/gtin/\(gtin)/JSON?apikey=\(dabasAPISecret)"
 
 guard let dabasURL = URL(string: dabasURLString) else {
 showErrorAlert(message: "Felaktig Dabas URL")
 return
 }
 
 let dabasTask = URLSession.shared.dataTask(with: dabasURL) { data, response, error in
 if let error = error {
 DispatchQueue.main.async {
 self.showErrorAlert(message: "Dabas API fel: \(error.localizedDescription)")
 }
 return
 }
 
 guard let data = data else {
 DispatchQueue.main.async {
 self.showErrorAlert(message: "Dabas API fel: Ingen data togs emot")
 }
 return
 }
 
 do {
 if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
 //print("Dabas API Response: \(jsonResponse)")
 
 guard let artikelbenamning = jsonResponse["Artikelbenamning"] as? String,
 let naringsinfoArray = jsonResponse["Naringsinfo"] as? [[String: Any]],
 let naringsinfo = naringsinfoArray.first,
 let naringsvarden = naringsinfo["Naringsvarden"] as? [[String: Any]] else {
 DispatchQueue.main.async {
 self.showErrorAlert(message: "Kunde inte hitta information om livsmedlet")
 }
 return
 }
 
 var carbohydrates = 0.0
 var fat = 0.0
 var proteins = 0.0
 
 for nutrient in naringsvarden {
 if let code = nutrient["Kod"] as? String, let amount = nutrient["Mangd"] as? Double {
 switch code {
 case "CHOAVL":
 carbohydrates = amount
 case "FAT":
 fat = amount
 case "PRO-":
 proteins = amount
 default:
 break
 }
 }
 }
 
 let message = """
 Kolhydrater: \(carbohydrates) g / 100 g
 Fett: \(fat) g / 100 g
 Protein: \(proteins) g / 100 g
 
 (Källa: Dabas)
 """
 
 DispatchQueue.main.async {
 self.showProductAlert(title: artikelbenamning, message: message, productName: artikelbenamning, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
 }
 print("Dabas produktmatchning OK")
 } else {
 DispatchQueue.main.async {
 self.showErrorAlert(message: "Dabas API fel: Kunde inte tolka svar från servern")
 }
 }
 } catch {
 DispatchQueue.main.async {
 self.showErrorAlert(message: "Dabas API error: \(error.localizedDescription)")
 }
 }
 }
 
 dabasTask.resume()
 }
 
 private func showProductAlert(title: String, message: String, productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
 let context = CoreDataStack.shared.context
 let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
 fetchRequest.predicate = NSPredicate(format: "name == %@", productName)
 
 do {
 let existingItems = try context.fetch(fetchRequest)
 
 if let existingItem = existingItems.first {
 let comparisonMessage = """
 Befintlig data    ->    Ny data
 Kh:       \(formattedValue(existingItem.carbohydrates))  ->  \(formattedValue(carbohydrates)) g/100g
 Fett:    \(formattedValue(existingItem.fat))  ->  \(formattedValue(fat)) g/100g
 Protein:  \(formattedValue(existingItem.protein))  ->  \(formattedValue(proteins)) g/100g
 """
 
 let duplicateAlert = UIAlertController(title: productName, message: "Finns redan inlagt i livsmedelslistan. \n\nVill du behålla de befintliga näringsvärdena eller uppdatera dem?\n\n\(comparisonMessage)", preferredStyle: .alert)
 duplicateAlert.addAction(UIAlertAction(title: "Behåll befintliga", style: .default, handler: { _ in
 self.navigateToAddFoodItem(foodItem: existingItem)
 }))
 duplicateAlert.addAction(UIAlertAction(title: "Uppdatera", style: .default, handler: { _ in
 self.navigateToAddFoodItemWithUpdate(existingItem: existingItem, productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
 }))
 duplicateAlert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: nil))
 present(duplicateAlert, animated: true, completion: nil)
 } else {
 let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
 alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: nil))
 alert.addAction(UIAlertAction(title: "Lägg till", style: .default, handler: { _ in
 self.navigateToAddFoodItem(productName: productName, carbohydrates: carbohydrates, fat: fat, proteins: proteins)
 }))
 present(alert, animated: true, completion: nil)
 }
 } catch {
 showErrorAlert(message: "Ett fel uppstod vid hämtning av livsmedelsdata.")
 }
 }
 
 private func formattedValue(_ value: Double) -> String {
 let formatter = NumberFormatter()
 formatter.minimumFractionDigits = 0
 formatter.maximumFractionDigits = 2
 formatter.numberStyle = .decimal
 return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
 }
 
 private func showErrorAlert(message: String) {
 let alert = UIAlertController(title: "Fel", message: message, preferredStyle: .alert)
 alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
 present(alert, animated: true, completion: nil)
 }
 
 private func navigateToAddFoodItem(foodItem: FoodItem) {
 let storyboard = UIStoryboard(name: "Main", bundle: nil)
 if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
 addFoodItemVC.delegate = self as? AddFoodItemDelegate
 addFoodItemVC.foodItem = foodItem
 navigationController?.pushViewController(addFoodItemVC, animated: true)
 }
 }
 
 private func navigateToAddFoodItem(productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
 let storyboard = UIStoryboard(name: "Main", bundle: nil)
 if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
 addFoodItemVC.delegate = self as? AddFoodItemDelegate
 addFoodItemVC.prePopulatedData = (productName, carbohydrates, fat, proteins)
 navigationController?.pushViewController(addFoodItemVC, animated: true)
 }
 }
 
 private func navigateToAddFoodItemWithUpdate(existingItem: FoodItem, productName: String, carbohydrates: Double, fat: Double, proteins: Double) {
 let storyboard = UIStoryboard(name: "Main", bundle: nil)
 if let addFoodItemVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController {
 addFoodItemVC.delegate = self as? AddFoodItemDelegate
 addFoodItemVC.foodItem = existingItem
 addFoodItemVC.prePopulatedData = (productName, carbohydrates, fat, proteins)
 addFoodItemVC.isUpdateMode = true
 navigationController?.pushViewController(addFoodItemVC, animated: true)
 }
 }
 }
 
 struct Article: Codable {
 let artikelbenamning: String?
 let varumarke: String?
 let forpackningsstorlek: String?
 let gtin: String?  // Add this line
 
 enum CodingKeys: String, CodingKey {
 case artikelbenamning = "Artikelbenamning"
 case varumarke = "Varumarke"
 case forpackningsstorlek = "Forpackningsstorlek"
 case gtin = "GTIN"  // Add this line
 }
 }
 
 class ArticleTableViewCell: UITableViewCell {
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
 
 var gtin: String? // Add this property to store GTIN
 
 override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
 super.init(style: style, reuseIdentifier: reuseIdentifier)
 contentView.addSubview(nameLabel)
 contentView.addSubview(detailsLabel)
 
 NSLayoutConstraint.activate([
 nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
 nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
 nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 16),
 
 detailsLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
 detailsLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
 detailsLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
 detailsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
 ])
 }
 
 required init?(coder: NSCoder) {
 fatalError("init(coder:) has not been implemented")
 }
 
 func configure(with article: Article) {
 nameLabel.text = article.artikelbenamning
 detailsLabel.text = "\(article.varumarke ?? "") • \(article.forpackningsstorlek ?? "")"
 gtin = article.gtin // Store GTIN
 }
 }*/
 
