import UIKit

class SearchOnlineViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let searchTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Sök efter livsmedel"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let searchButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Sök", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private var articles: [Article] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Sök Online"
        
        view.addSubview(searchTextField)
        view.addSubview(searchButton)
        view.addSubview(tableView)
        
        setupConstraints()
        setupSearchTextField()
        
        searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ArticleTableViewCell.self, forCellReuseIdentifier: "ArticleCell")
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            searchTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            searchTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100),
            
            searchButton.centerYAnchor.constraint(equalTo: searchTextField.centerYAnchor),
            searchButton.leadingAnchor.constraint(equalTo: searchTextField.trailingAnchor, constant: 8),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchButton.heightAnchor.constraint(equalToConstant: 40),
            
            tableView.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupSearchTextField() {
        let clearButton = UIButton(type: .custom)
        clearButton.setImage(UIImage(systemName: "xmark.circle"), for: .normal)
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        
        searchTextField.rightView = clearButton
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
            print("Invalid Dabas URL")
            return
        }
        
        let dabasTask = URLSession.shared.dataTask(with: dabasURL) { data, response, error in
            if let error = error {
                print("Dabas API error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("Dabas API error: No data received")
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
                print("Dabas API error: \(error.localizedDescription)")
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
}
