// Daniel: 2800+ lines - To be cleaned
//  ComposeMealViewController.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-17.

import UIKit
import CoreData
import AudioToolbox
import LocalAuthentication
import CloudKit
import QuartzCore
import SwiftUI
import UserNotifications


class ComposeMealViewController: UIViewController, FoodItemRowViewDelegate, UITextFieldDelegate, TwilioRequestable, MealViewControllerDelegate, RSSFeedDelegate, MealInsightsDelegate {
    static weak var current: ComposeMealViewController?
    static var shared: ComposeMealViewController?
    var profileManager = ProfileManager.shared
    
    ///Views
    var foodItemRows: [FoodItemRowView] = []
    var searchableDropdownViewController: SearchableDropdownViewController!
    var stackView: UIStackView!
    var scrollView: UIScrollView!
    var contentView: UIView!
    var addButtonRowView: AddButtonRowView!
    private var scrollViewBottomConstraint: NSLayoutConstraint?
    private var addButtonRowViewBottomConstraint: NSLayoutConstraint?
    
    ///Buttons
    var clearAllButton: UIBarButtonItem!
    var saveFavoriteButton: UIButton!
    var addFromSearchableDropdownButton: UIBarButtonItem!
    
    ///Summary labels
    var totalBolusAmountLabel: UILabel!
    var totalNetCarbsLabel: UILabel!
    var totalNetFatLabel: UILabel!
    var totalNetProteinLabel: UILabel!
    
    ///Treatment labels
    var crLabel: UILabel!
    var nowCRLabel: UILabel!
    var startAmountLabel: UILabel!
    var totalStartAmountLabel: UILabel!
    var totalStartBolusLabel: UILabel!
    var remainsLabel: UILabel!
    var totalRemainsLabel: UILabel!
    var totalRemainsBolusLabel: UILabel!
    public var totalRegisteredCarbsLabel: UILabel!
    
    /// Container views for bolus, fat, protein, and carbs
    var bolusContainer: UIView!
    var fatContainer: UIView!
    var proteinContainer: UIView!
    var carbsContainer: UIView!
    var crContainer: UIView?
    private var crContainerBackgroundColor: UIColor = .systemGray3
    var startAmountContainer: UIView!
    var remainsContainer: UIView!
    var registeredContainer: UIView!
    
    ///Meal food item rows  labels
    var foodItemLabel: UILabel!
    var portionServedLabel: UILabel!
    var notEatenLabel: UILabel!
    var netCarbsLabel: UILabel!
    
    ///Data and states
    var foodItems: [FoodItem] = []
    var matchedFoodItems: [FoodItem] = []
    var scheduledStartDose = Double(20)
    var scheduledCarbRatio = Double(25)
    var allowShortcuts: Bool = false
    var saveMealToHistory: Bool = false
    var zeroBolus: Bool = false
    var lateBreakfast: Bool = false
    var lateBreakfastFactor = Double(1.5)
    var temporaryOverride: Bool = false
    var temporaryOverrideFactor = Double(1.0)
    private var lateBreakfastTimer: Timer?
    private let lateBreakfastDuration: TimeInterval = 90 * 60 // 90 minutes in seconds
    var startDoseGiven: Bool = false
    var preBolus = false
    var remainingDoseGiven: Bool = false
    var dataSharingVC: DataSharingViewController?
    var mealEmojis: String? = "🍴"
    var mealDate: Date?
    var isPopoverChange = false
    var hourChangeTimer: Timer?
    var registeredFatSoFar = Double(0.0)
    var registeredProteinSoFar = Double(0.0)
    var registeredBolusSoFar = Double(0.0)
    private var _registeredCarbsSoFar: Double = 0.0
    var registeredCarbsSoFar: Double {
        get {
            return _registeredCarbsSoFar
        }
        set {
            _registeredCarbsSoFar = newValue
            isPopoverChange = true
            // Check if newValue is 0, if so, set label to "--", otherwise display the value.
            if newValue == 0 {
                totalRegisteredCarbsLabel?.text = "--"
            } else {
                totalRegisteredCarbsLabel?.text = String(format: "%.0f g", newValue)
            }
        }
    }
    var latestBolusSent = Double(0.0)
    
    ///Meal monitoring
    var exportTimer: Timer?
    private var isEditingMeal = false {
        didSet {
            if isEditingMeal {
                UserDefaultsRepository.allowViewingOngoingMeals = false
                startAutoSaveToCSV()
            } else {
                UserDefaultsRepository.allowViewingOngoingMeals = true
                stopAutoSaveToCSV()
            }
        }
    }
    // MARK: View Did Load
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeComposeMealViewController()
        webLoadNSProfile() //TODO: Add to override/latebreakfast switch when implementing remote overrides
    }
    
    private func initializeComposeMealViewController() {
        loadValuesFromUserDefaults()
        initializeUIElements()
        ComposeMealViewController.current = self
        ComposeMealViewController.shared = self
        
        /// Create the gradient view
        // Check if the app is in dark mode and set the background accordingly
        updateBackgroundForCurrentMode()
        
        /*
        let plateImageView = UIImageView(image: UIImage(named: "Plate"))
        plateImageView.contentMode = .scaleAspectFit
        plateImageView.alpha = 0.05
        plateImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(plateImageView)
        NSLayoutConstraint.activate([
            plateImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            plateImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),
            plateImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9), // Adjust size as needed
            plateImageView.heightAnchor.constraint(equalTo: plateImageView.widthAnchor)
        ])*/
        
        title = NSLocalizedString("Måltid", comment: "Måltid")
        
        /// Setup the fixed header containing summary and headline
        let fixedHeaderContainer = UIView()
        fixedHeaderContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fixedHeaderContainer)
        NSLayoutConstraint.activate([
            fixedHeaderContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            fixedHeaderContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fixedHeaderContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fixedHeaderContainer.heightAnchor.constraint(equalToConstant: 143)
        ])
        
        /// Reset lateBreakfast to false
        UserDefaultsRepository.lateBreakfast = false
        lateBreakfast = false
        
        /// Ensure addButtonRowView is initialized
        addButtonRowView = AddButtonRowView()
        updatePlaceholderValuesForCurrentHour()
        lateBreakfastFactor = UserDefaultsRepository.lateBreakfastFactor
        lateBreakfast = UserDefaultsRepository.lateBreakfast
        addButtonRowView.lateBreakfastSwitch.isOn = lateBreakfast
        if lateBreakfast {
            if temporaryOverride {
                scheduledCarbRatio /= temporaryOverrideFactor
            } else {
                scheduledCarbRatio /= lateBreakfastFactor
            }
            UserDefaultsRepository.scheduledCarbRatio = scheduledCarbRatio
        }
        updateScheduledValuesUI()
        
        setupSummaryView(in: fixedHeaderContainer)
        setupTreatmentView(in: fixedHeaderContainer)
        setupHeadline(in: fixedHeaderContainer)
        setupScrollView(below: fixedHeaderContainer)
        setupAddButtonRowView()
        
        /// Initializing
        clearAllButton = UIBarButtonItem(title: NSLocalizedString("Avsluta måltid", comment: "Avsluta måltid"), style: .plain, target: self, action: #selector(clearAllButtonTapped))
        clearAllButton.tintColor = .red
        navigationItem.rightBarButtonItem = clearAllButton
        
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        
        /// Inital fetch
        self.fetchFoodItems()
        loadFoodItemsFromCoreData()
        NotificationCenter.default.addObserver(self, selector: #selector(allowShortcutsChanged), name: Notification.Name("AllowShortcutsChanged"), object: nil)
        allowShortcuts = UserDefaultsRepository.allowShortcuts
        
        /// Create buttons
        let calendarImage = UIImage(systemName: "calendar")
        let historyButton = UIButton(type: .system)
        historyButton.setImage(calendarImage, for: .normal)
        historyButton.addTarget(self, action: #selector(showMealHistory), for: .touchUpInside)
        
        let showFavoriteMealsImage = UIImage(systemName: "list.star")
        let showFavoriteMealsButton = UIButton(type: .system)
        showFavoriteMealsButton.setImage(showFavoriteMealsImage, for: .normal)
        showFavoriteMealsButton.addTarget(self, action: #selector(showFavoriteMeals), for: .touchUpInside)
        
        let saveFavoriteImage = UIImage(systemName: "star.circle")
        saveFavoriteButton = UIButton(type: .system)
        saveFavoriteButton.setImage(saveFavoriteImage, for: .normal)
        saveFavoriteButton.addTarget(self, action: #selector(saveFavoriteMeals), for: .touchUpInside)
        saveFavoriteButton.isEnabled = false
        saveFavoriteButton.tintColor = .gray
        
        let stackView = UIStackView(arrangedSubviews: [historyButton, showFavoriteMealsButton, saveFavoriteButton])
        stackView.axis = .horizontal
        stackView.spacing = 20
        
        let customView = UIView()
        customView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: customView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: customView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: customView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: customView.bottomAnchor)
        ])
        
        let customBarButtonItem = UIBarButtonItem(customView: customView)
        navigationItem.leftBarButtonItem = customBarButtonItem
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(lateBreakfastLabelTapped))
        addButtonRowView.lateBreakfastLabel.addGestureRecognizer(tapGesture)
        
        /// Register for keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(allowViewingOngoingMealsChanged), name: .allowViewingOngoingMealsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didTakeoverRegistration(_:)), name: .didTakeoverRegistration, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateRSSButtonVisibility), name: .schoolFoodURLChanged, object: nil)
        addButtonRowView.lateBreakfastSwitch.addTarget(self, action: #selector(lateBreakfastSwitchChanged(_:)), for: .valueChanged)
        dataSharingVC = DataSharingViewController()
        
        if registeredCarbsSoFar == 0 {
            totalRegisteredCarbsLabel?.text = "--"
        } else {
            totalRegisteredCarbsLabel?.text = String(format: "%.0f g", registeredCarbsSoFar)
        }
        
    }
    // MARK: View Will Appear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.endEditing(true)
        loadTemporaryFoodItemsFromCoreData()
        loadValuesFromUserDefaults()
        
        updatePlaceholderValuesForCurrentHour() //Make sure carb ratio and start dose schedules are updated
        startHourChangeTimer() // Start timer while in this view to check if its a new hour and update CR/Startdoses if they are changed from the last hour to the new hour
        lateBreakfastFactor = UserDefaultsRepository.lateBreakfastFactor // Fetch factor for calculating late breakfast CR
        if lateBreakfast {
            if temporaryOverride {
                scheduledCarbRatio /= temporaryOverrideFactor
            } else {
                scheduledCarbRatio /= lateBreakfastFactor // If latebreakfast switch is on, calculate new CR
            }
            UserDefaultsRepository.scheduledCarbRatio = scheduledCarbRatio
        }
        updateScheduledValuesUI()
        
        // Check if the late breakfast switch should be off
        if let startTime = UserDefaultsRepository.lateBreakfastStartTime {
            print("Override CR was activated: \(startTime)")
            let timeInterval = Date().timeIntervalSince(startTime)
            if timeInterval >= lateBreakfastDuration {
                addButtonRowView.lateBreakfastSwitch.isOn = false
                lateBreakfastSwitchChanged(addButtonRowView.lateBreakfastSwitch)
            } else {
                lateBreakfastTimer = Timer.scheduledTimer(timeInterval: lateBreakfastDuration - timeInterval, target: self, selector: #selector(turnOffLateBreakfastSwitch), userInfo: nil, repeats: false)
            }
        }
        
        // Ensure updateTotalNutrients is called after all initializations
        updateTotalNutrients()
        
        // Ensure dataSharingVC is instantiated
        guard let dataSharingVC = dataSharingVC else { return }
        Task {
            print("Data import triggered")
            await
            dataSharingVC.importCSVFiles()
        }
        fetchFoodItems()
        checkIfEditing()
    }
    // MARK: View Will Disappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if lateBreakfast {
            scheduledCarbRatio *= lateBreakfastFactor // Reset scheduledCarbRatio when leaving view
        }
        UserDefaultsRepository.scheduledCarbRatio = scheduledCarbRatio
        hourChangeTimer?.invalidate()
        hourChangeTimer = nil
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Check if the user interface style (light/dark mode) has changed
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBackgroundForCurrentMode()
        }
    }

    private func updateBackgroundForCurrentMode() {
        // Remove any existing gradient views before updating
        view.subviews.filter { $0 is GradientView }.forEach { $0.removeFromSuperview() }
        
        // Update the background based on the current interface style
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .systemBackground
            // Create the gradient view for dark mode
            let colors: [CGColor] = [
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.25).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor
            ]
            let gradientView = GradientView(colors: colors)
            gradientView.translatesAutoresizingMaskIntoConstraints = false

            // Add the gradient view to the main view
            view.addSubview(gradientView)
            view.sendSubviewToBack(gradientView)

            // Set up constraints for the gradient view
            NSLayoutConstraint.activate([
                gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                gradientView.topAnchor.constraint(equalTo: view.topAnchor),
                gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        } else {
            // In light mode, set a solid white background
            view.backgroundColor = .systemGray6
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .allowViewingOngoingMealsChanged, object: nil)
        if ComposeMealViewController.current === self {
            ComposeMealViewController.current = nil
        }
    }
    
    // MARK: Formatting and helpers
    private func formatNumberWithoutTrailingZero(_ number: Double) -> String {
        let formattedNumber = String(format: "%.1f", number)
        return formattedNumber.hasSuffix(".0") ? String(formattedNumber.dropLast(2)) : formattedNumber
    }
    
    private func formattedValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    func formatScheduledCarbRatio(_ value: Double) -> String {
        let roundedValue = round(value * 10) / 10.0
        if roundedValue == floor(roundedValue) {
            return String(format: NSLocalizedString("%.0f g/E", comment: "%.0f g/E"), roundedValue)
        } else {
            return String(format: NSLocalizedString("%.1f g/E", comment: "%.1f g/E"), roundedValue)
        }
    }
    
    // Helper function to format values and remove trailing .0
    func formatValue(_ value: String) -> String {
        let doubleValue = Double(value) ?? 0.0
        return doubleValue.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", doubleValue) : String(doubleValue)
    }
    
    // Function to get the current date in UTC format
    func getCurrentDateUTC() -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter.string(from: Date())
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else if value * 10 == floor(value * 10) {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
    private func roundDownToNearest05(_ value: Double) -> Double {
        return (value * 20.0).rounded(.down) / 20.0
    }
    
    // Helper function to format numbers with necessary decimal places
    private func formatValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value) // No decimal places if it's a whole number
        } else if value * 10 == floor(value * 10) {
            return String(format: "%.1f", value) // One decimal place if one decimal is non-zero
        } else {
            return String(format: "%.2f", value) // Two decimal places otherwise
        }
    }
    
    /// Helper function to add the semi-transparent overlay layer behind the labels
    private func addOverlayLayer(to container: UIView, percentage: CGFloat, belowView: UIView) {
        let overlayView = UIView()
        //overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlayView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.4)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        container.insertSubview(overlayView, at: 0)
        
        NSLayoutConstraint.activate([
            overlayView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: container.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            overlayView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 1 - percentage) // Inverted percentage
        ])
    }
    /// Helper function to clamp a value between a minimum and maximum value
    private func clamp(_ value: Double, to limits: ClosedRange<Double>) -> Double {
        return min(max(value, limits.lowerBound), limits.upperBound)
    }
    
    private func createContainerView(backgroundColor: UIColor, borderColor: UIColor? = nil, borderWidth: CGFloat = 0) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = backgroundColor
        containerView.layer.cornerRadius = 10
        containerView.clipsToBounds = true
        if let borderColor = borderColor {
            containerView.layer.borderColor = borderColor.cgColor
            containerView.layer.borderWidth = borderWidth
        }
        return containerView
    }
    
    private func createLabel(text: String, fontSize: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let systemFont = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let font: UIFont
        
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: roundedDescriptor, size: fontSize)
        } else {
            font = systemFont
        }
        
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.textAlignment = .center
        return label
    }
    
    private func createTextField(placeholder: String, fontSize: CGFloat, weight: UIFont.Weight, color: UIColor) -> UITextField {
        let systemFont = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let font: UIFont
        
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: roundedDescriptor, size: fontSize)
        } else {
            font = systemFont
        }
        
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = font
        textField.textColor = color
        textField.textAlignment = .right
        textField.keyboardType = .decimalPad
        return textField
    }
    
    // MARK: Methods (Setup UI)
    private func initializeUIElements() {
        
        if clearAllButton == nil {
            clearAllButton = UIBarButtonItem(title: NSLocalizedString("Avsluta måltid", comment: "Avsluta måltid"), style: .plain, target: self, action: #selector(clearAllButtonTapped))
            clearAllButton.tintColor = .red
            navigationItem.rightBarButtonItem = clearAllButton
        }
        
        if saveFavoriteButton == nil {
            saveFavoriteButton = UIButton(type: .system)
            saveFavoriteButton.setImage(UIImage(systemName: "star.circle"), for: .normal)
            saveFavoriteButton.addTarget(self, action: #selector(saveFavoriteMeals), for: .touchUpInside)
            saveFavoriteButton.isEnabled = false
            saveFavoriteButton.tintColor = .gray
        }
    }
    
    private func setupScrollView(below header: UIView) {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)
        
        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -150)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollViewBottomConstraint!,
            
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
        
        setupStackView()
    }
    
    private func setupStackView() {
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    private func setupAddButtonRowView() {
        addButtonRowView = AddButtonRowView()
        addButtonRowView.translatesAutoresizingMaskIntoConstraints = false
        addButtonRowView.addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        view.addSubview(addButtonRowView)
        
        addButtonRowViewBottomConstraint = addButtonRowView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        
        NSLayoutConstraint.activate([
            addButtonRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            addButtonRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            addButtonRowViewBottomConstraint!,
            addButtonRowView.heightAnchor.constraint(equalToConstant: 55)
        ])
    }
    
    private func updateOverlayLayer(for container: UIView, percentage: CGFloat) {
        // Remove any existing overlay layers
        container.subviews.forEach { subview in
            if subview.tag == 999 {
                subview.removeFromSuperview()
            }
        }
        
        // Create a new overlay view
        let overlayView = UIView()
        //overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlayView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.4)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.tag = 999
        container.insertSubview(overlayView, at: 0)
        
        NSLayoutConstraint.activate([
            overlayView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: container.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            overlayView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 1 - percentage) // Inverted percentage
        ])
    }
    
    private func setupSummaryView(in container: UIView) {
        let colors: [CGColor] = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor
        ]
        let summaryView = GradientView(colors: colors)
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(summaryView)
        
        // Bolus container setup
        bolusContainer = createContainerView(backgroundColor: .systemIndigo, borderColor: .white, borderWidth: 0)
        summaryView.addSubview(bolusContainer)
        
        let bolusLabel = createLabel(text: NSLocalizedString("BOLUS", comment: "BOLUS"), fontSize: 9, weight: .bold, color: .white)
        totalBolusAmountLabel = createLabel(text: NSLocalizedString("--", comment: "--"), fontSize: 18, weight: .bold, color: .white)
        let bolusStack = UIStackView(arrangedSubviews: [bolusLabel, totalBolusAmountLabel])
        let bolusPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(bolusStack, in: bolusContainer, padding: bolusPadding)
        
        let bolusTapGesture = UITapGestureRecognizer(target: self, action: #selector(showBolusInfo))
        bolusContainer.isUserInteractionEnabled = true
        bolusContainer.addGestureRecognizer(bolusTapGesture)
        
        let bolusPercentage = calculatePercentage(registeredSoFar: registeredBolusSoFar, totalValue: totalBolusAmountLabel?.text)
        updateOverlayLayer(for: bolusContainer, percentage: bolusPercentage)
        
        // Carbs container setup
        carbsContainer = createContainerView(backgroundColor: .systemOrange, borderColor: .white, borderWidth: 0)
        summaryView.addSubview(carbsContainer)
        
        let carbsLabel = createLabel(text: NSLocalizedString("KOLHYDRATER", comment: "KOLHYDRATER"), fontSize: 9, weight: .bold, color: .white)
        totalNetCarbsLabel = createLabel(text: NSLocalizedString("0 g", comment: "0 g"), fontSize: 18, weight: .bold, color: .white)
        let carbsStack = UIStackView(arrangedSubviews: [carbsLabel, totalNetCarbsLabel])
        let carbsPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(carbsStack, in: carbsContainer, padding: carbsPadding)
        
        let carbsTapGesture = UITapGestureRecognizer(target: self, action: #selector(showCarbsInfo))
        carbsContainer.isUserInteractionEnabled = true
        carbsContainer.addGestureRecognizer(carbsTapGesture)
        
        let carbsPercentage = calculatePercentage(registeredSoFar: registeredCarbsSoFar, totalValue: totalNetCarbsLabel?.text)
        updateOverlayLayer(for: carbsContainer, percentage: carbsPercentage)
        
        // Fat container setup
        fatContainer = createContainerView(backgroundColor: .systemBrown, borderColor: .white, borderWidth: 0)
        summaryView.addSubview(fatContainer)
        
        let fatLabel = createLabel(text: NSLocalizedString("FETT", comment: "FETT"), fontSize: 9, weight: .bold, color: .white)
        totalNetFatLabel = createLabel(text: NSLocalizedString("0 g", comment: "0 g"), fontSize: 18, weight: .bold, color: .white)
        let fatStack = UIStackView(arrangedSubviews: [fatLabel, totalNetFatLabel])
        let fatPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(fatStack, in: fatContainer, padding: fatPadding)
        
        let fatTapGesture = UITapGestureRecognizer(target: self, action: #selector(showFatInfo))
        fatContainer.isUserInteractionEnabled = true
        fatContainer.addGestureRecognizer(fatTapGesture)
        
        let fatPercentage = calculatePercentage(registeredSoFar: registeredFatSoFar, totalValue: totalNetFatLabel?.text)
        updateOverlayLayer(for: fatContainer, percentage: fatPercentage)
        
        // Protein container setup
        proteinContainer = createContainerView(backgroundColor: .systemBrown, borderColor: .white, borderWidth: 0)
        summaryView.addSubview(proteinContainer)
        
        let proteinLabel = createLabel(text: NSLocalizedString("PROTEIN", comment: "PROTEIN"), fontSize: 9, weight: .bold, color: .white)
        totalNetProteinLabel = createLabel(text: NSLocalizedString("0 g", comment: "0 g"), fontSize: 18, weight: .bold, color: .white)
        let proteinStack = UIStackView(arrangedSubviews: [proteinLabel, totalNetProteinLabel])
        let proteinPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(proteinStack, in: proteinContainer, padding: proteinPadding)
        
        let proteinTapGesture = UITapGestureRecognizer(target: self, action: #selector(showProteinInfo))
        proteinContainer.isUserInteractionEnabled = true
        proteinContainer.addGestureRecognizer(proteinTapGesture)
        
        let proteinPercentage = calculatePercentage(registeredSoFar: registeredProteinSoFar, totalValue: totalNetProteinLabel?.text)
        updateOverlayLayer(for: proteinContainer, percentage: proteinPercentage)
        
        // Horizontal stack view setup
        let hStack = UIStackView(arrangedSubviews: [bolusContainer, fatContainer, proteinContainer, carbsContainer])
        hStack.axis = .horizontal
        hStack.spacing = 8
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.distribution = .fillEqually
        summaryView.addSubview(hStack)
        
        NSLayoutConstraint.activate([
            summaryView.heightAnchor.constraint(equalToConstant: 60),
            summaryView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            summaryView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            summaryView.topAnchor.constraint(equalTo: container.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor, constant: -16),
            hStack.topAnchor.constraint(equalTo: summaryView.topAnchor, constant: 10),
            hStack.bottomAnchor.constraint(equalTo: summaryView.bottomAnchor, constant: -5)
        ])
    }
    
    private func setupTreatmentView(in container: UIView) {
        let colors: [CGColor] = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor
        ]
        let treatmentView = GradientView(colors: colors)
        treatmentView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(treatmentView)
        
        // Initialize crContainer with the initial background color
        crContainer = createContainerView(backgroundColor: crContainerBackgroundColor, borderColor: .white, borderWidth: 0)
        treatmentView.addSubview(crContainer!)
        
        crLabel = createLabel(text: NSLocalizedString("INSULINKVOT", comment: "INSULINKVOT"), fontSize: 9, weight: .bold, color: .white)
        nowCRLabel = createLabel(text: formatScheduledCarbRatio(scheduledCarbRatio), fontSize: 18, weight: .bold, color: .white)
        
        if let crContainer = crContainer {
            let crStack = UIStackView(arrangedSubviews: [crLabel, nowCRLabel])
            crStack.axis = .vertical
            crStack.spacing = 4
            let crPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
            setupStackView(crStack, in: crContainer, padding: crPadding)
            let crTapGesture = UITapGestureRecognizer(target: self, action: #selector(showCRInfo))
            crContainer.isUserInteractionEnabled = true
            crContainer.addGestureRecognizer(crTapGesture)
        } else {
            print("crContainer is nil and cannot be configured.")
        }
        remainsContainer = createContainerView(backgroundColor: .systemGray3, borderColor: .white, borderWidth: 0)
        treatmentView.addSubview(remainsContainer)
        let remainsTapGesture = UITapGestureRecognizer(target: self, action: #selector(remainContainerTapped))
        remainsContainer.addGestureRecognizer(remainsTapGesture)
        // Long press gesture recognizer for additional action
        let longPressRemainsGesture = UILongPressGestureRecognizer(target: self, action: #selector(remainContainerTapped))
        remainsContainer.addGestureRecognizer(longPressRemainsGesture)
        remainsContainer.isUserInteractionEnabled = true
        
        remainsLabel = createLabel(text: NSLocalizedString("HELA DOSEN", comment: "HELA DOSEN"), fontSize: 9, weight: .bold, color: .white)
        totalRemainsLabel = createLabel(text: NSLocalizedString("", comment: ""), fontSize: 12, weight: .bold, color: .white)
        totalRemainsBolusLabel = createLabel(text: NSLocalizedString("", comment: ""), fontSize: 12, weight: .bold, color: .white)
        
        let remainsValuesStack = UIStackView(arrangedSubviews: [totalRemainsLabel, totalRemainsBolusLabel])
        remainsValuesStack.axis = .horizontal
        remainsValuesStack.spacing = 3
        
        let remainsStack = UIStackView(arrangedSubviews: [remainsLabel, remainsValuesStack])
        remainsStack.axis = .vertical
        remainsStack.spacing = 7
        let remainsPadding = UIEdgeInsets(top: 4, left: 2, bottom: 7, right: 2)
        setupStackView(remainsStack, in: remainsContainer, padding: remainsPadding)
        
        startAmountContainer = createContainerView(backgroundColor: .systemBlue, borderColor: .white, borderWidth: 0)
        treatmentView.addSubview(startAmountContainer)
        let startAmountTapGesture = UITapGestureRecognizer(target: self, action: #selector(startAmountContainerTapped))
        startAmountContainer.addGestureRecognizer(startAmountTapGesture)
        // Long press gesture recognizer for additional action
        let longPressStartAmountGesture = UILongPressGestureRecognizer(target: self, action: #selector(startAmountContainerTapped))
        startAmountContainer.addGestureRecognizer(longPressStartAmountGesture)
        startAmountContainer.isUserInteractionEnabled = true
        
        let startDoseTextString = self.startDoseGiven ? NSLocalizedString("+ DOS", comment: "+ DOS") : NSLocalizedString("+ STARTDOS", comment: "+ STARTDOS")
        let startAmountText = foodItemRows.isEmpty ? NSLocalizedString("+ PRE-BOLUS", comment: "+ PRE-BOLUS") : startDoseTextString
        startAmountLabel = createLabel(text: startAmountText, fontSize: 9, weight: .bold, color: .white)
        totalStartAmountLabel = createLabel(text: String(format: NSLocalizedString("%.0fg", comment: "%.0fg"), scheduledStartDose), fontSize: 12, weight: .bold, color: .white)
        totalStartBolusLabel = createLabel(text: NSLocalizedString("0E", comment: "0E"), fontSize: 12, weight: .bold, color: .white)
        let startAmountValuesStack = UIStackView(arrangedSubviews: [totalStartAmountLabel, totalStartBolusLabel])
        startAmountValuesStack.axis = .horizontal
        startAmountValuesStack.spacing = 3
        
        let startAmountStack = UIStackView(arrangedSubviews: [startAmountLabel, startAmountValuesStack])
        startAmountStack.axis = .vertical
        startAmountStack.spacing = 7
        let startAmountPadding = UIEdgeInsets(top: 4, left: 2, bottom: 7, right: 2)
        setupStackView(startAmountStack, in: startAmountContainer, padding: startAmountPadding)
        
        registeredContainer = createContainerView(backgroundColor: .systemGray3, borderColor: .white, borderWidth: 0)
        treatmentView.addSubview(registeredContainer)
        
        // Tap gesture recognizer for edit action
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(editCurrentRegistration))
        registeredContainer.addGestureRecognizer(tapGesture)
        
        // Long press gesture recognizer for additional action
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(registeredContainerLongPressed))
        registeredContainer.addGestureRecognizer(longPressGesture)
        
        registeredContainer.isUserInteractionEnabled = true
        
        let registeredLabel = createLabel(text: NSLocalizedString("REGGADE KH", comment: "REGGADE KH"), fontSize: 9, weight: .bold, color: .white)
        totalRegisteredCarbsLabel = createLabel(text: NSLocalizedString("--", comment: "--"), fontSize: 18, weight: .bold, color: .white)
        let registeredStack = UIStackView(arrangedSubviews: [registeredLabel, totalRegisteredCarbsLabel])
        registeredStack.axis = .vertical
        registeredStack.spacing = 4
        let registeredPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        setupStackView(registeredStack, in: registeredContainer, padding: registeredPadding)
        
        if let crContainer = crContainer, let startAmountContainer = startAmountContainer, let remainsContainer = remainsContainer, let registeredContainer = registeredContainer {
            let registeredStack = UIStackView(arrangedSubviews: [registeredLabel, totalRegisteredCarbsLabel])
            registeredStack.axis = .vertical
            registeredStack.spacing = 4
            let registeredPadding = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
            setupStackView(registeredStack, in: registeredContainer, padding: registeredPadding)
            let hStack = UIStackView(arrangedSubviews: [crContainer, startAmountContainer, remainsContainer, registeredContainer])
            hStack.axis = .horizontal
            hStack.spacing = 8
            hStack.translatesAutoresizingMaskIntoConstraints = false
            hStack.distribution = .fillEqually
            treatmentView.addSubview(hStack)
            NSLayoutConstraint.activate([
                hStack.leadingAnchor.constraint(equalTo: treatmentView.leadingAnchor, constant: 16),
                hStack.trailingAnchor.constraint(equalTo: treatmentView.trailingAnchor, constant: -16),
                hStack.topAnchor.constraint(equalTo: treatmentView.topAnchor, constant: 5),
                hStack.bottomAnchor.constraint(equalTo: treatmentView.bottomAnchor, constant: -10)
            ])
        } else {
            print("One or more views are nil and cannot be added to the stack view.")
        }
        
        NSLayoutConstraint.activate([
            treatmentView.heightAnchor.constraint(equalToConstant: 60),
            treatmentView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            treatmentView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            treatmentView.topAnchor.constraint(equalTo: container.topAnchor, constant: 60),
        ])
    }
    
    private func setupStackView(_ stackView: UIStackView, in containerView: UIView, padding: UIEdgeInsets) {
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding.left),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding.right),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding.top),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding.bottom)
        ])
    }
    
    private func setupHeadline(in container: UIView) {
        let headlineContainer = UIView()
        headlineContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headlineContainer)
        
        NSLayoutConstraint.activate([
            headlineContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 0),
            headlineContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headlineContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headlineContainer.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        let headlineStackView = UIStackView()
        headlineStackView.axis = .horizontal
        headlineStackView.spacing = 0
        headlineStackView.distribution = .fillProportionally
        headlineStackView.translatesAutoresizingMaskIntoConstraints = false
        headlineContainer.addSubview(headlineStackView)
        
        let systemFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        let font: UIFont
        
        if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: roundedDescriptor, size: 11)
        } else {
            font = systemFont
        }
        
        foodItemLabel = UILabel()
        foodItemLabel.text = NSLocalizedString("LIVSMEDEL", comment: "LIVSMEDEL")
        foodItemLabel.textAlignment = .left
        foodItemLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        foodItemLabel.font = font
        foodItemLabel.textColor = .gray
        
        portionServedLabel = UILabel()
        portionServedLabel.text = NSLocalizedString("PORTION", comment: "PORTION")
        portionServedLabel.textAlignment = .left
        portionServedLabel.widthAnchor.constraint(equalToConstant: 68).isActive = true
        portionServedLabel.font = font
        portionServedLabel.textColor = .gray
        
        notEatenLabel = UILabel()
        notEatenLabel.text = NSLocalizedString("LÄMNAT", comment: "LÄMNAT")
        notEatenLabel.textAlignment = .left
        notEatenLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        notEatenLabel.font = font
        notEatenLabel.textColor = .gray
        
        netCarbsLabel = UILabel()
        netCarbsLabel.text = NSLocalizedString("KOLH", comment: "KOLH")
        netCarbsLabel.textAlignment = .right
        netCarbsLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true
        netCarbsLabel.font = font
        netCarbsLabel.textColor = .gray
        headlineStackView.addArrangedSubview(foodItemLabel)
        headlineStackView.addArrangedSubview(portionServedLabel)
        headlineStackView.addArrangedSubview(notEatenLabel)
        headlineStackView.addArrangedSubview(netCarbsLabel)
        
        NSLayoutConstraint.activate([
            headlineStackView.leadingAnchor.constraint(equalTo: headlineContainer.leadingAnchor, constant: 16),
            headlineStackView.trailingAnchor.constraint(equalTo: headlineContainer.trailingAnchor, constant: -16),
            headlineStackView.topAnchor.constraint(equalTo: headlineContainer.topAnchor, constant: 16),
            headlineStackView.bottomAnchor.constraint(equalTo: headlineContainer.bottomAnchor)
        ])
    }
    
    // MARK: Methods (UI changes)
    @objc private func clearAllButtonTapped() {
        guard clearAllButton != nil else {
            return
        }
        view.endEditing(true)
        
        // Calculate values for the conditions
        let fatTotalValue = Double(totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0") ?? 0.0
        let fatRemaining = fatTotalValue - registeredFatSoFar
        
        let proteinTotalValue = Double(totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0") ?? 0.0
        let proteinRemaining = proteinTotalValue - registeredProteinSoFar
        
        let totalCarbsValue = Double(totalNetCarbsLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0") ?? 0.0
        let carbsRemains = Double(totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0") ?? 0.0
        
        // Check if any remaining values are greater than zero
        if (fatRemaining > 0 || proteinRemaining > 0 || carbsRemains > 0) {
            // Show the additional alert
            let confirmationAlert = UIAlertController(
                title: NSLocalizedString("⚠️ Registrering ej slutförd!", comment: "Confirm End Meal"),
                message: {
                    var message = NSLocalizedString("\nNedan värden har ännu inte registrerats för denna måltid:\n", comment: "Unregistered items")
                    
                    if carbsRemains > 0 {
                        message += String(format: "\n%.0f g Kh", carbsRemains)
                    }
                    if fatRemaining > 0 {
                        message += String(format: "\n%.0f g Fett", fatRemaining)
                    }
                    if proteinRemaining > 0 {
                        message += String(format: "\n%.0f g Protein", proteinRemaining)
                    }
                    
                    return message
                }(),
                preferredStyle: .alert
            )
            
            // "Continue" button to proceed with the regular alert
            let continueAction = UIAlertAction(title: NSLocalizedString("Fortsätt", comment: "Continue"), style: .destructive) { [weak self] _ in
                self?.showRegularClearAllAlert()
            }
            
            // "Cancel" button to dismiss this alert
            let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel"), style: .cancel, handler: nil)
            
            confirmationAlert.addAction(continueAction)
            confirmationAlert.addAction(cancelAction)
            
            present(confirmationAlert, animated: true, completion: nil)
        } else {
            // Directly show the regular alert if no conditions are met
            showRegularClearAllAlert()
        }
    }

    // Separate function for the regular alert to clean up code and avoid duplication
    private func showRegularClearAllAlert() {
        let alertController = UIAlertController(
            title: NSLocalizedString("Avsluta Måltid", comment: "End Meal"),
            message: NSLocalizedString("Bekräfta att du vill rensa alla valda livsmedel och inmatade värden för denna måltid. \nÅtgärden kan inte ångras.", comment: "Confirm clearing all selected food items and entered values for this meal. This action cannot be undone."),
            preferredStyle: .actionSheet
        )
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel"), style: .cancel, handler: nil)
        let yesAction = UIAlertAction(title: NSLocalizedString("Rensa", comment: "Clear"), style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                // Save the meal history before clearing data, if required
                if self.saveMealToHistory {
                    await self.saveMealHistory()
                }
                
                // Perform clearing operations after save is complete
                self.clearAllFoodItems()
                self.updateRemainsBolus()
                self.updateTotalNutrients()
                self.clearAllButton.isEnabled = false
                self.clearAllFoodItemRowsFromCoreData()
                self.startDoseGiven = false
                self.remainingDoseGiven = false
                self.isEditingMeal = false
                self.stopAutoSaveToCSV()
                FinishMealManager.shared.stopFinishMealCountdown()
                
                if UserDefaultsRepository.allowSharingOngoingMeals {
                    self.cleanDuplicateFiles()
                    self.exportBlankCSV()
                }
                
                self.lateBreakfastTimer?.invalidate()
                self.turnOffLateBreakfastSwitch()
                self.startAmountLabel.text = NSLocalizedString("+ PRE-BOLUS", comment: "+ PRE-BOLUS")
                self.startAmountContainer.backgroundColor = .systemBlue
                UserDefaultsRepository.savedHistorySearchText = ""
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(yesAction)
        present(alertController, animated: true, completion: nil)
    }



    
    private func clearAllFoodItems() {
        for row in foodItemRows {
            stackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        foodItemRows.removeAll()
        updateTotalNutrients()
        view.endEditing(true)
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        resetVariablesToDefault()
        updateRemainsBolus()
        
        // Reset the totalNetCarbsLabel and other total labels
        totalNetCarbsLabel.text = NSLocalizedString("--", comment: "--")
        totalNetFatLabel.text = NSLocalizedString("--", comment: "--")
        totalNetProteinLabel.text = NSLocalizedString("--", comment: "--")
        totalBolusAmountLabel.text = NSLocalizedString("--", comment: "--")
        totalStartAmountLabel.text = NSLocalizedString("0 g", comment: "0 g")
        totalRemainsLabel.text = NSLocalizedString("0 g", comment: "0 g")
        totalRemainsBolusLabel.text = NSLocalizedString("0 E", comment: "0 E")
        totalRegisteredCarbsLabel.text = NSLocalizedString("--", comment: "--")
        
        // Reset the startBolus amount
        startAmountLabel.text = NSLocalizedString("+ PRE-BOLUS", comment: "+ PRE-BOLUS")
        startAmountContainer.backgroundColor = .systemBlue
        totalStartBolusLabel.text = NSLocalizedString("0 E", comment: "0 E")
        
        // Reset the remainsContainer color and label
        remainsContainer.backgroundColor = .systemGray3
        remainsLabel.text = NSLocalizedString("+ RESTERANDE", comment: "+ RESTERANDE")
    }
    
    public func updateSaveFavoriteButtonState() {
        guard let saveFavoriteButton = saveFavoriteButton else {
            return
        }
        let isEnabled = !foodItemRows.isEmpty
        saveFavoriteButton.isEnabled = isEnabled
        saveFavoriteButton.tintColor = isEnabled ? .label : .gray
    }
    
    func populateWithFavoriteMeal(_ favoriteMeal: NewFavoriteMeals) {
        checkAndHandleExistingMeal(replacementAction: {
            self.addFavoriteMeal(favoriteMeal)
        }, additionAction: {
            self.addFavoriteMeal(favoriteMeal)
        }, completion: {})
    }
    
    func populateWithMealHistory(_ mealHistory: MealHistory) {
        checkAndHandleExistingMeal(replacementAction: {
            self.addMealHistory(mealHistory)
        }, additionAction: {
            self.addMealHistory(mealHistory)
        }, completion: {
        })
    }
    
    internal func addMealHistory(_ mealHistory: MealHistory) {
        for foodEntry in mealHistory.foodEntries?.allObjects as? [FoodItemEntry] ?? [] {
            var foodItem: FoodItem?
            
            // First, try to match by entryId
            if let entryId = foodEntry.entryId {
                foodItem = foodItems.first(where: { $0.id == entryId })
                if foodItem == nil {
                    print("Warning: Food item with id \(entryId) not found in foodItems. Attempting to match by name.")
                }
            }
            
            // If no match by entryId, fall back to matching by entryName
            if foodItem == nil, let entryName = foodEntry.entryName {
                foodItem = foodItems.first(where: { $0.name == entryName })
            }
            
            // Proceed if a matching foodItem is found
            if let foodItem = foodItem {
                let rowView = FoodItemRowView()
                rowView.foodItems = foodItems
                rowView.delegate = self
                rowView.translatesAutoresizingMaskIntoConstraints = false
                stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count)
                foodItemRows.append(rowView)
                rowView.setSelectedFoodItem(foodItem)
                rowView.portionServedTextField.text = formattedValue(foodEntry.entryPortionServed)
                rowView.portionServedTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
                
                rowView.onDelete = { [weak self] in
                    self?.removeFoodItemRow(rowView)
                }
                
                rowView.onValueChange = { [weak self] in
                    self?.updateTotalNutrients()
                    self?.updateHeadlineVisibility()
                }
                rowView.calculateNutrients()
            } else {
                print("Food item not found for entryId: \(foodEntry.entryId?.uuidString ?? "nil") or name: \(foodEntry.entryName ?? "nil")")
            }
        }
        let startDoseTextString = self.startDoseGiven ? NSLocalizedString("+ DOS", comment: "+ DOS") : NSLocalizedString("+ STARTDOS", comment: "+ STARTDOS")
        startAmountLabel.text = startDoseTextString
        startAmountContainer.backgroundColor = .systemBlue
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    func populateWithMatchedFoodItems(_ matchedFoodItems: [FoodItem]) {
        // Sort the matched food items by carbohydrates in descending order
        let sortedMatchedFoodItems = matchedFoodItems.sorted {
            ($0.carbohydrates + $0.carbsPP) > ($1.carbohydrates + $1.carbsPP)
        }
        
        for matchedFoodItem in sortedMatchedFoodItems {
            if let existingFoodItem = foodItems.first(where: { $0.name == matchedFoodItem.name }) {
                let rowView = FoodItemRowView()
                rowView.foodItems = foodItems
                rowView.delegate = self
                rowView.translatesAutoresizingMaskIntoConstraints = false
                stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count)
                foodItemRows.append(rowView)
                
                rowView.setSelectedFoodItem(existingFoodItem)
                rowView.portionServedTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
                
                rowView.onDelete = { [weak self] in
                    self?.removeFoodItemRow(rowView)
                }
                
                rowView.onValueChange = { [weak self] in
                    self?.updateTotalNutrients()
                    self?.updateHeadlineVisibility()
                }
                
                rowView.calculateNutrients()
            } else {
                print("Food item with name \(matchedFoodItem.name ?? "") not found in foodItems.")
            }
        }
        
        let startDoseTextString = self.startDoseGiven ? NSLocalizedString("+ DOS", comment: "+ DOS") : NSLocalizedString("+ STARTDOS", comment: "+ STARTDOS")
        startAmountLabel.text = startDoseTextString
        startAmountContainer.backgroundColor = .systemBlue
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        
        // Check if any food item has either carbohydrates or carbsPP greater than 10
        let isCarbohydrateRich = matchedFoodItems.contains { $0.carbohydrates > 10 || $0.carbsPP > 10 }
        
        if !isCarbohydrateRich {
            // Delay the alert a bit to make sure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let alertTitle = NSLocalizedString("Kolhydratssnål Måltid", comment:"Kolhydratssnål Måltid")
                let alertMessage = NSLocalizedString("\nDagens skollunch verkar innehålla relativt lite kolhydrater. \n\nKomplettera gärna med extra kolhydrater, exvis en skiva knäckebröd, en frukt eller extra mjölk.", comment:"\nDagens skollunch verkar innehålla relativt lite kolhydrater. \n\nKomplettera gärna med extra kolhydrater, exvis en skiva knäckebröd, en frukt eller extra mjölk.")
                
                self.showAlert(title: alertTitle, message: alertMessage)
            }
        }
    }
    
    // Implement the delegate method
    func didAddFoodItem(_ foodItem: FoodItem) {
        print("Adding food item to ComposeMealViewController: \(foodItem.name ?? "")")
        addFoodItemRow(with: foodItem)
    }
    
    private func updateStartAmountLabel() {
        guard let startAmountLabel = startAmountLabel else {
            print("startAmountLabel is not initialized.")
            return
        }
        
        if foodItemRows.isEmpty {
            startAmountLabel.text = NSLocalizedString("+ PRE-BOLUS", comment: "+ PRE-BOLUS")
            startAmountContainer.backgroundColor = .systemBlue
        } else {
            let startDoseTextString = self.startDoseGiven ? NSLocalizedString("+ DOS", comment: "+ DOS") : NSLocalizedString("+ STARTDOS", comment: "+ STARTDOS")
            startAmountLabel.text = startDoseTextString
            startAmountContainer.backgroundColor = .systemBlue
        }
    }
    
    @objc private func didTakeoverRegistration(_ notification: Notification) {
        if let importedRows = notification.userInfo?["foodItemRows"] as? [FoodItemRowData] {
            
            // Find the maximum registeredCarbsSoFar (and fat, protein & bolus so far) from the imported rows
            let maxregisteredCarbsSoFar = importedRows.map { $0.registeredCarbsSoFar }.max() ?? 0.0
            let maxRegisteredFatSoFar = importedRows.map { $0.registeredFatSoFar }.max() ?? 0.0
            let maxRegisteredProteinSoFar = importedRows.map { $0.registeredProteinSoFar }.max() ?? 0.0
            let maxRegisteredBolusSoFar = importedRows.map { $0.registeredBolusSoFar }.max() ?? 0.0
            
            // Retrieve mealDate if it's set in any of the imported rows
            if let importedMealDate = importedRows.compactMap({ $0.mealDate }).first {
                self.mealDate = importedMealDate
                print("Meal date set to: \(self.mealDate)")
            } else {
                print("No meal date found in imported rows")
            }

            // Determine if start dose should be true based on bolus value
            let startDose = maxRegisteredBolusSoFar > 0

            for row in importedRows {
                if let foodItem = getFoodItemByID(row.foodItemID) {
                    addFoodItemRow(with: foodItem, portionServed: row.portionServed, notEaten: row.notEaten)
                } else {
                    print("Food item not found for ID: \(row.foodItemID)")
                }
            }
            
            // Run the update function with max values and the calculated startDose
            didUpdateMealValues(
                khValue: String(format: "%.0f", maxregisteredCarbsSoFar),
                fatValue: String(format: "%.0f", maxRegisteredFatSoFar),
                proteinValue: String(format: "%.0f", maxRegisteredProteinSoFar),
                bolusValue: String(format: "%.2f", maxRegisteredBolusSoFar),
                startDose: startDose
            )

            if maxregisteredCarbsSoFar == 0 {
                totalRegisteredCarbsLabel?.text = "--"
            } else {
                totalRegisteredCarbsLabel?.text = String(format: "%.0f g", maxregisteredCarbsSoFar)
            }

            registeredFatSoFar = maxRegisteredFatSoFar
            registeredProteinSoFar = maxRegisteredProteinSoFar
            registeredBolusSoFar = maxRegisteredBolusSoFar

        } else {
            print("No foodItemRows found in notification")
        }
    }

    
    private func clearCurrentRows() {
        for row in foodItemRows {
            stackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        foodItemRows.removeAll()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    private func addRow(for foodItem: FoodItem, portionServed: Double, notEaten: Double) {
        let rowView = FoodItemRowView()
        rowView.selectedFoodItem = foodItem
        rowView.portionServedTextField.text = "\(portionServed)"
        rowView.notEatenTextField.text = "\(notEaten)"
        
        foodItemRows.append(rowView)
        stackView.addArrangedSubview(rowView)
    }
    
    func didUpdateMealValues(khValue: String, fatValue: String, proteinValue: String, bolusValue: String, startDose: Bool) {
        print("updateRegisteredAmount function ran from delegate")
        updateRegisteredAmount(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: bolusValue, startDose: startDose)
    }
    func didUpdateMealDate(_ date: Date) {
            self.mealDate = date
            print("Meal date set to: \(mealDate!)")
        }
    
    public func updateRegisteredAmount(khValue: String, fatValue: String, proteinValue: String, bolusValue: String, startDose: Bool) {
        print("updateRegisteredAmount function ran")
        self.startDoseGiven = startDose
        let currentRegisteredValue = Double(totalRegisteredCarbsLabel.text?.replacingOccurrences(of: "--", with: "0").replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        let remainsValue = Double(khValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let newRegisteredValue = currentRegisteredValue + remainsValue
        let fatDoubleValue = Double(fatValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let proteinDoubleValue = Double(proteinValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let bolusDoubleValue = Double(bolusValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let carbsDoubleValue = Double(khValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        
        // Set variable for the latest bolus registration if the value is less than 0
        if bolusDoubleValue > 0 {
            latestBolusSent = bolusDoubleValue
            print("Latest Bolus Sent: \(latestBolusSent)")
        } else {
            print("Bolus value is 0; latestBolusSent not updated.")
        }
        
        registeredFatSoFar += fatDoubleValue
        registeredProteinSoFar += proteinDoubleValue
        registeredBolusSoFar += bolusDoubleValue
        registeredCarbsSoFar += carbsDoubleValue
        totalRegisteredCarbsLabel.text = String(format: "%.0f g", registeredCarbsSoFar).replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "--", with: "0")

        print("Accumulated Fat So Far: \(registeredFatSoFar)g")
        print("Accumulated Protein So Far: \(registeredProteinSoFar)g")
        print("Accumulated Bolus So Far: \(registeredBolusSoFar)E")
        print("Accumulated Carbs So Far: \(registeredCarbsSoFar)g")
        
        saveValuesToUserDefaults()
        saveToCoreData()
        updateTotalNutrients()
        clearAllButton.isEnabled = true
        
        
        // Check if any of the values (carbs, fat, protein, bolus) are greater than 0
        if let textValue = totalRegisteredCarbsLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0"),
           let numberValue = Double(textValue.replacingOccurrences(of: ",", with: "")),
           numberValue > 0 || registeredFatSoFar > 0.0 || registeredProteinSoFar > 0.0 || registeredBolusSoFar > 0.0 {
            
            saveMealToHistory = true // Set true if any of the values are greater than 0
        } else {
            saveMealToHistory = false // Reset if all the values are 0
        }
        
        if UserDefaultsRepository.allowSharingOngoingMeals {
            self.exportToCSV()
        }
    }
    
    public func updateTotalNutrients() {
        let totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        let remainsValue = Double(totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        let remainsBolus = Double(totalRemainsBolusLabel.text?.replacingOccurrences(of: NSLocalizedString("E", comment: "E"), with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        
        guard let totalNetCarbsLabel = totalNetCarbsLabel else {
            print("Error: totalNetCarbsLabel is nil")
            return
        }
        
        // Replace 0 with "--" for totalNetCarbsLabel
        totalNetCarbsLabel.text = totalNetCarbs == 0 ? "--" : String(format: "%.0f g", totalNetCarbs)
        
        let totalNetFat = foodItemRows.reduce(0.0) { $0 + $1.netFat }
        // Replace 0 with "--" for totalNetFatLabel
        totalNetFatLabel.text = totalNetFat == 0 ? "--" : String(format: "%.0f g", totalNetFat)
        
        let totalNetProtein = foodItemRows.reduce(0.0) { $0 + $1.netProtein }
        // Replace 0 with "--" for totalNetProteinLabel
        totalNetProteinLabel.text = totalNetProtein == 0 ? "--" : String(format: "%.0f g", totalNetProtein)
        
        let totalBolus = totalNetCarbs / scheduledCarbRatio
        let roundedBolus = roundDownToNearest05(totalBolus)
        // Replace 0 with "--" for totalBolusAmountLabel
        totalBolusAmountLabel.text = roundedBolus == 0 ? "--" : formatNumber(roundedBolus) + NSLocalizedString(" E", comment: " E")
        
        if UserDefaultsRepository.useStartDosePercentage {
            let startDoseFactor = UserDefaultsRepository.startDoseFactor
            let totalStartAmount = totalNetCarbs * startDoseFactor
            totalStartAmountLabel.text = String(format: "%.0fg", totalStartAmount)
            let startBolus = totalStartAmount / scheduledCarbRatio
            let roundedStartBolus = roundDownToNearest05(startBolus)
            totalStartBolusLabel.text = formatNumber(roundedStartBolus) + NSLocalizedString("E", comment: "E")
        } else {
            if totalNetCarbs > 0 && totalNetCarbs <= scheduledStartDose {
                totalStartAmountLabel.text = String(format: "%.0fg", totalNetCarbs)
                let startBolus = totalNetCarbs / scheduledCarbRatio
                let roundedStartBolus = roundDownToNearest05(startBolus)
                totalStartBolusLabel.text = formatNumber(roundedStartBolus) + NSLocalizedString("E", comment: "E")
            } else {
                totalStartAmountLabel.text = String(format: "%.0fg", scheduledStartDose)
                let startBolus = scheduledStartDose / scheduledCarbRatio
                let roundedStartBolus = roundDownToNearest05(startBolus)
                totalStartBolusLabel.text = formatNumber(roundedStartBolus) + NSLocalizedString("E", comment: "E")
            }
        }
        
        updateRemainsBolus()
        updateSaveFavoriteButtonState()
        updatePercentages()
    }
    
    public func updateTotalRemainsLabel(text: String, fontSize: CGFloat) {
        let newLabel = createLabel(text: text, fontSize: fontSize, weight: .bold, color: .white)
        totalRemainsLabel.text = newLabel.text
        totalRemainsLabel.font = newLabel.font
        totalRemainsLabel.textColor = newLabel.textColor
        totalRemainsLabel.textAlignment = newLabel.textAlignment
    }
    
    public func updateTotalStartAmountLabel(text: String, fontSize: CGFloat) {
        let newLabel = createLabel(text: text, fontSize: fontSize, weight: .bold, color: .white)
        totalStartAmountLabel.text = newLabel.text
        totalStartAmountLabel.font = newLabel.font
        totalStartAmountLabel.textColor = newLabel.textColor
        totalStartAmountLabel.textAlignment = newLabel.textAlignment
    }
    
    public func updateRemainsBolus() {
        let totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        let totalCarbsValue = Double(totalNetCarbs)
        let remainsTextString = self.startDoseGiven ? NSLocalizedString("+ KVAR ATT GE", comment: "+ KVAR ATT GE") : NSLocalizedString("+ HELA DOSEN", comment: "+ HELA DOSEN")
        let remainsBolus = roundDownToNearest05(totalCarbsValue / scheduledCarbRatio) - registeredBolusSoFar
        let proteinTotalValue = Double(totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0") ?? 0.0
        let proteinRemaining = proteinTotalValue - registeredProteinSoFar
        let fatTotalValue = Double(totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "") ?? "0") ?? 0.0
        let fatRemaining = fatTotalValue - registeredFatSoFar
        
        if let registeredText = totalRegisteredCarbsLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0"),
           let registeredValue = Double(registeredText) {
            let remainsValue = totalCarbsValue - registeredValue
            totalRemainsLabel.text = String(format: "%.0fg", remainsValue)
            let remainsBolus = roundDownToNearest05(totalCarbsValue / scheduledCarbRatio) - registeredBolusSoFar
            totalRemainsBolusLabel.text = formatValue(remainsBolus) + NSLocalizedString("E", comment: "E")
            
            switch (remainsValue, remainsBolus, proteinRemaining, fatRemaining) {
            case (-0.5...0.5, -0.05...0.05, -0.5...0.5, -0.5...0.5) where proteinTotalValue == 0 && fatTotalValue == 0 && totalCarbsValue == 0:
                remainsContainer.backgroundColor = .systemGray3
                registeredContainer.backgroundColor = .systemGray3
                remainsLabel.text = NSLocalizedString("VÄNTAR", comment: "VÄNTAR")
                updateTotalRemainsLabel(text: NSLocalizedString(" PÅ INPUT", comment: " PÅ INPUT"), fontSize: 9)
                updateTotalStartAmountLabel(text: totalStartAmountLabel.text ?? "", fontSize: 12)
                totalRemainsBolusLabel.text = " "
                updateStartAmountLabel()
            case (-0.5...0.5, -0.05...0.05, -0.5...0.5, -0.5...0.5):
                remainsContainer.backgroundColor = .systemGreen
                registeredContainer.backgroundColor = .systemGreen
                startAmountContainer.backgroundColor = .systemGray3
                remainsLabel.text = NSLocalizedString("KVAR ATT GE", comment: "KVAR ATT GE")
                updateTotalRemainsLabel(text: NSLocalizedString(" KLAR", comment: " KLAR"), fontSize: 18)
                totalRemainsBolusLabel.text = ""
                startAmountLabel.text = NSLocalizedString("+ DOS", comment: "+ DOS")
                updateTotalStartAmountLabel(text: NSLocalizedString(" KLAR", comment: " KLAR"), fontSize: 18)
                totalStartBolusLabel.text = ""
                
                
            case let (x, y, z, w) where x > 0.5 || y > 0.05 || z > 0.5 || w > 0.5:
                remainsContainer?.backgroundColor = .systemBlue
                registeredContainer.backgroundColor = .systemGray3
                remainsLabel.text = remainsTextString
                updateTotalRemainsLabel(text: totalRemainsLabel.text ?? "", fontSize: 12)
                updateTotalStartAmountLabel(text: totalStartAmountLabel.text ?? "", fontSize: 12)
                updateStartAmountLabel()
            default:
                remainsContainer.backgroundColor = .systemRed
                registeredContainer.backgroundColor = .systemRed
                startAmountContainer.backgroundColor = .systemGray3
                remainsLabel.text = NSLocalizedString("ÖVERDOS!", comment: "ÖVERDOS!")
                updateTotalStartAmountLabel(text: NSLocalizedString(" KLAR", comment: " KLAR"), fontSize: 18)
                totalStartBolusLabel.text = ""
                updateTotalRemainsLabel(text: totalRemainsLabel.text ?? " ", fontSize: 12)
            }
        } else {
            // Calculate values when no registration is found
            let remainsValue = totalCarbsValue // Set remainsValue to totalCarbsValue since no registration found
            
            let remainsBolus = roundDownToNearest05(totalCarbsValue / scheduledCarbRatio) - registeredBolusSoFar
            totalRemainsLabel.text = String(format: "%.0fg", remainsValue)
            totalRemainsBolusLabel?.text = formatValue(remainsBolus) + NSLocalizedString("E", comment: "E")
            
            if remainsValue >= -0.5 && remainsValue <= 0.5 &&
                remainsBolus >= -0.05 && remainsBolus <= 0.05 &&
                proteinRemaining >= -0.5 && proteinRemaining <= 0.5 &&
                fatRemaining >= -0.5 && fatRemaining <= 0.5 &&
                proteinTotalValue == 0 && fatTotalValue == 0 && totalCarbsValue == 0 {
                remainsContainer?.backgroundColor = .systemGray3
                registeredContainer?.backgroundColor = .systemGray3
                remainsLabel.text = NSLocalizedString("VÄNTAR", comment: "VÄNTAR")
                updateTotalRemainsLabel(text: NSLocalizedString(" PÅ INPUT", comment: " PÅ INPUT"), fontSize: 9)
                totalRemainsBolusLabel.text = " "
                updateTotalStartAmountLabel(text: totalStartAmountLabel.text ?? "", fontSize: 12)
                updateStartAmountLabel()
            } else if remainsValue >= -0.5 && remainsValue <= 0.5
                        && remainsBolus >= -0.05 && remainsBolus <= 0.05
                        && proteinRemaining >= -0.5 && proteinRemaining <= 0.5
                        && fatRemaining >= -0.5 && fatRemaining <= 0.5 {
                remainsContainer?.backgroundColor = .systemGreen
                registeredContainer.backgroundColor = .systemGreen
                startAmountContainer.backgroundColor = .systemGreen //systemGray2
                remainsLabel.text = NSLocalizedString("KVAR ATT GE", comment: "KVAR ATT GE")
                updateTotalRemainsLabel(text: NSLocalizedString(" KLAR", comment: " KLAR"), fontSize: 18)
                totalRemainsBolusLabel.text = ""
                startAmountLabel.text = NSLocalizedString("+ DOS", comment: "+ DOS")
                updateTotalStartAmountLabel(text: NSLocalizedString(" KLAR", comment: " KLAR"), fontSize: 18)
                totalStartBolusLabel.text = ""
            } else if remainsValue > 0.5 ||
                        remainsBolus > 0.05 ||
                        proteinRemaining > 0.5 ||
                        fatRemaining > 0.5 {
                remainsContainer?.backgroundColor = .systemBlue
                registeredContainer.backgroundColor = .systemGray3
                remainsLabel.text = remainsTextString
                updateTotalRemainsLabel(text: totalRemainsLabel.text ?? "", fontSize: 12)
                updateTotalStartAmountLabel(text: totalStartAmountLabel.text ?? "", fontSize: 12)
                updateStartAmountLabel()
            } else {
                remainsContainer?.backgroundColor = .systemRed
                registeredContainer.backgroundColor = .systemRed
                startAmountContainer.backgroundColor = .systemGreen //systemGray3
                remainsLabel.text = NSLocalizedString("ÖVERDOS!", comment: "ÖVERDOS!")
                updateTotalStartAmountLabel(text: NSLocalizedString(" KLAR", comment: " KLAR"), fontSize: 18)
                totalStartBolusLabel.text = ""
                updateTotalRemainsLabel(text: totalRemainsLabel.text ?? " ", fontSize: 12)
            }
            remainsLabel?.text = remainsTextString
        }
        let remainsValue = Double(totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: ",", with: ".") ?? "0") ?? 0.0
        if registeredCarbsSoFar > 0 && totalNetCarbs > 0 && remainsValue <= scheduledStartDose {
            startAmountLabel.text = NSLocalizedString("DOS", comment: "DOS")
            startAmountContainer.backgroundColor = .systemGreen //systemGray3
            updateTotalStartAmountLabel(text: NSLocalizedString(" KLAR", comment: " KLAR"), fontSize: 18)
            totalStartBolusLabel.text = ""
            if remainsValue > 0.4 {
                remainsContainer?.backgroundColor = .systemBlue
            } else if remainsValue < -0.4 {
                remainsContainer?.backgroundColor = .systemRed
                registeredContainer.backgroundColor = .systemRed
            }
        }
    }
    
    public func updateHeadlineVisibility() {
        let isHidden = foodItemRows.isEmpty
        
        foodItemLabel?.isHidden = isHidden
        portionServedLabel?.isHidden = isHidden
        notEatenLabel?.isHidden = isHidden
        netCarbsLabel?.isHidden = isHidden
    }
    
    private func handleSelectedFoodItems(_ items: [FoodItem]) {
        for item in items {
            addFoodItemRow(with: item)
        }
        updateTotalNutrients()
        updateHeadlineVisibility()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
    }
    
    func addFoodItemRow(with foodItem: FoodItem? = nil) {
        guard let stackView = stackView else {
            print("stackView is nil")
            return
        }
        
        let rowView = FoodItemRowView()
        rowView.foodItems = foodItems
        rowView.delegate = self
        rowView.translatesAutoresizingMaskIntoConstraints = false
        stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count)
        foodItemRows.append(rowView)
        
        if let foodItem = foodItem {
            rowView.setSelectedFoodItem(foodItem)
        }
        rowView.onDelete = { [weak self] in
            self?.removeFoodItemRow(rowView)
        }
        rowView.onValueChange = { [weak self] in
            self?.updateTotalNutrients()
        }
        let startDoseTextString = self.startDoseGiven ? NSLocalizedString("+ DOS", comment: "+ DOS") : NSLocalizedString("+ STARTDOS", comment: "+ STARTDOS")
        startAmountLabel.text = startDoseTextString
        startAmountContainer.backgroundColor = .systemBlue
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        
        if !isEditingMeal {
            startEditing()
        }
        rowView.calculateNutrients()
    }
    
    private func addFoodItemRow(with foodItem: FoodItem, portionServed: Double? = nil, notEaten: Double? = nil) {
        let rowView = FoodItemRowView()
        rowView.foodItems = foodItems
        rowView.delegate = self
        rowView.translatesAutoresizingMaskIntoConstraints = false
        stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count)
        foodItemRows.append(rowView)
        rowView.setSelectedFoodItem(foodItem)
        
        // Only set the text fields if the values are not nil
        if let portionServed = portionServed {
            rowView.portionServedTextField.text = formattedValue(portionServed)
        }
        if let notEaten = notEaten {
            rowView.notEatenTextField.text = formattedValue(notEaten)
        }
        rowView.portionServedTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        rowView.notEatenTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        rowView.onDelete = { [weak self] in
            self?.removeFoodItemRow(rowView)
        }
        rowView.onValueChange = { [weak self] in
            self?.updateTotalNutrients()
            self?.updateHeadlineVisibility()
        }
        rowView.calculateNutrients()
        
        let startDoseTextString = self.startDoseGiven ? NSLocalizedString("+ DOS", comment: "+ DOS") : NSLocalizedString("+ STARTDOS", comment: "+ STARTDOS")
        startAmountLabel.text = startDoseTextString
        startAmountContainer.backgroundColor = .systemBlue
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    @objc private func addButtonTapped() {
        let dropdownVC = SearchableDropdownViewController()
        dropdownVC.onDoneButtonTapped = { [weak self] selectedItems in
            self?.handleSelectedFoodItems(selectedItems)
        }
        let navigationController = UINavigationController(rootViewController: dropdownVC)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true, completion: nil)
        
        hideAllDeleteButtons()
    }
    
    private func removeFoodItemRow(_ rowView: FoodItemRowView) {
        stackView.removeArrangedSubview(rowView)
        rowView.removeFromSuperview()
        if let index = foodItemRows.firstIndex(of: rowView) {
            foodItemRows.remove(at: index)
        }
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
        
        // Check if foodItemRows is empty and update label accordingly
        if foodItemRows.isEmpty {
            startAmountLabel.text = NSLocalizedString("+ PRE-BOLUS", comment: "+ PRE-BOLUS")
            startAmountContainer.backgroundColor = .systemBlue
            
            if UserDefaultsRepository.allowSharingOngoingMeals {
                cleanDuplicateFiles()
                exportBlankCSV()
            }
        }
    }
    
    public func updateClearAllButtonState() {
        guard let clearAllButton = clearAllButton else {
            return
        }
        let carbsText = totalRegisteredCarbsLabel?.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
        let carbsValue = Double(carbsText.replacingOccurrences(of: ",", with: "")) ?? 0.0

        clearAllButton.isEnabled = !foodItemRows.isEmpty || registeredCarbsSoFar > 0 || registeredFatSoFar > 0 || registeredProteinSoFar > 0 || registeredBolusSoFar > 0
    }
    
    private func updateScheduledValuesUI() {
        guard let nowCRLabel = nowCRLabel,
              let totalStartAmountLabel = totalStartAmountLabel,
              let totalStartBolusLabel = totalStartBolusLabel else {
            return
        }
        nowCRLabel.text = String(formatScheduledCarbRatio(scheduledCarbRatio))
        totalStartAmountLabel.text = String(format: "%.0fg", scheduledStartDose)
        
        let totalStartAmount = Double(totalStartAmountLabel.text?.replacingOccurrences(of: "g", with: "") ?? "0") ?? 0.0
        let startBolus = roundDownToNearest05(totalStartAmount / scheduledCarbRatio)
        totalStartBolusLabel.text = String(format: NSLocalizedString("%.2fE", comment: "%.2fE"), startBolus)
        updateRemainsBolus()
    }
    
    func didTapNextButton(_ rowView: FoodItemRowView, currentTextField: UITextField) {
        guard let currentIndex = foodItemRows.firstIndex(of: rowView) else {
            print("Row not found in foodItemRows")
            return
        }
        let nextIndex = (currentIndex + 1) % foodItemRows.count
        let nextRowView = foodItemRows[nextIndex]
        
        DispatchQueue.main.async {
            if currentTextField == rowView.portionServedTextField {
                if nextRowView.portionServedTextField.becomeFirstResponder() {
                } else {
                    print("Failed to make portionServedTextField first responder for row \(nextIndex)")
                }
            } else if currentTextField == rowView.notEatenTextField {
                if nextRowView.notEatenTextField.becomeFirstResponder() {
                } else {
                    print("Failed to make notEatenTextField first responder for row \(nextIndex)")
                }
            }
            self.scrollView.scrollRectToVisible(nextRowView.frame, animated: true)
        }
    }
    
    @objc internal func rssButtonTapped() {
        let rssFeedVC = RSSFeedViewController()
        rssFeedVC.delegate = self
        let navigationController = UINavigationController(rootViewController: rssFeedVC)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true, completion: nil)
        hideAllDeleteButtons()
    }
    
    @objc private func lateBreakfastSwitchChanged(_ sender: UISwitch) {
        lateBreakfast = sender.isOn
        UserDefaultsRepository.lateBreakfast = lateBreakfast
        
        // Show alert to set temporary override factor
        if lateBreakfast {
            showTemporaryOverrideAlert()
            self.startLateBreakfastTimer()
        } else {
            crContainerBackgroundColor = .systemGray3
            
            updatePlaceholderValuesForCurrentHour()
            updateScheduledValuesUI()
            updateTotalNutrients()

            if let crContainer = crContainer {
                crContainer.backgroundColor = crContainerBackgroundColor
            }

            if let addButtonRowView = self.addButtonRowView {
                addButtonRowView.lateBreakfastContainer.backgroundColor = .systemGray3
                addButtonRowView.lateBreakfastLabel.text = NSLocalizedString("OVERRIDE", comment: "OVERRIDE")
            }
        }
    }
    
    // MARK: Methods (States and data)
    private func startHourChangeTimer() {
        hourChangeTimer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(checkForHourChange), userInfo: nil, repeats: true)
    }
    
    @objc private func checkForHourChange() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        if lastCheckedHour != currentHour {
            lastCheckedHour = currentHour
            updatePlaceholderValuesForCurrentHour()
            updateScheduledValuesUI()
        }
    }
    
    @objc private func allowViewingOngoingMealsChanged() {
        print("allowViewingOngoingMeals changed to: \(UserDefaultsRepository.allowViewingOngoingMeals)")
    }
    
    private var lastCheckedHour: Int = Calendar.current.component(.hour, from: Date())
    
    
    private func getMealEmojis() -> String {
        return (mealEmojis ?? "🍽️").filter { !$0.isWhitespaceOrNewline }
    }
    
    private func createEmojiString() {
        let emojis = foodItemRows.compactMap { $0.selectedFoodItem?.emoji }
        if emojis.isEmpty {
            mealEmojis = "🍴" // Default emoji if no emojis are available
        } else {
            mealEmojis = removeDuplicateEmojis(from: emojis.joined().filter { !$0.isWhitespaceOrNewline })
        }
        print("mealEmojis updated: \(mealEmojis ?? "")")
    }
    
    private func removeDuplicateEmojis(from string: String) -> String {
        var uniqueEmojis = Set<Character>()
        return string.filter { uniqueEmojis.insert($0).inserted }
    }
    
    func didSelectFoodItems(_ foodItems: [FoodItem]) {
        // Update your UI with the newly selected food items
        populateWithMatchedFoodItems(foodItems)
        
        // Print the selected food items (for debugging purposes)
        print("Selected food items: \(foodItems)")
    }
    
    private func updatePercentages() {
        guard let bolusText = totalBolusAmountLabel?.text,
              let fatText = totalNetFatLabel?.text,
              let proteinText = totalNetProteinLabel?.text,
              let carbsText = totalNetCarbsLabel?.text else {
            print("One or more labels are nil, cannot calculate percentages")
            return
        }
        
        // Calculate the percentages
        let bolusPercentage = calculatePercentage(registeredSoFar: registeredBolusSoFar, totalValue: bolusText)
        let fatPercentage = calculatePercentage(registeredSoFar: registeredFatSoFar, totalValue: fatText)
        let proteinPercentage = calculatePercentage(registeredSoFar: registeredProteinSoFar, totalValue: proteinText)
        let carbsPercentage = calculatePercentage(registeredSoFar: registeredCarbsSoFar, totalValue: carbsText)

        updateOverlayLayer(for: bolusContainer, percentage: bolusPercentage)
        updateOverlayLayer(for: fatContainer, percentage: fatPercentage)
        updateOverlayLayer(for: proteinContainer, percentage: proteinPercentage)
        updateOverlayLayer(for: carbsContainer, percentage: carbsPercentage)
    }
    
    private func calculatePercentage(registeredSoFar: Double, totalValue: String?) -> CGFloat {
        guard let totalString = totalValue, let total = Double(totalString.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)), total > 0 else {
            return 0.0
        }
        let percentage = registeredSoFar / total // Normal calculation
        return CGFloat(clamp(percentage, to: 0...1)) // Ensure percentage stays between 0 and 1
    }
    
    @objc private func allowShortcutsChanged() {
        allowShortcuts = UserDefaultsRepository.allowShortcuts
    }
    
    private func hideAllDeleteButtons() {
        for row in foodItemRows {
            row.hideDeleteButton()
        }
    }
    
    private func updatePlaceholderValuesForCurrentHour() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        if let carbRatio = CoreDataHelper.shared.fetchCarbRatio(for: currentHour) {
            scheduledCarbRatio = carbRatio
            UserDefaultsRepository.scheduledCarbRatio = scheduledCarbRatio
        }
        if let startDose = CoreDataHelper.shared.fetchStartDose(for: currentHour) {
            scheduledStartDose = startDose
        }
    }
    
    ///OngoingMeal monitoring
    func startEditing() {
        guard !isEditingMeal else {
            return
        }
        isEditingMeal = true
        print("Start editing triggered. isEditingMeal set to \(isEditingMeal)")
        
        // Cancel the preBolus timer through the PreBolusManager
        PreBolusManager.shared.stopPreBolusCountdown()
        
        startAutoSaveToCSV()
    }
    
    func stopEditing() {
        print("Stop editing triggered. Checking if still editing...")
        checkIfEditing()
    }
    
    private func checkIfEditing() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItemRow> = FoodItemRow.fetchRequest()
        do {
            let foodItemRows = try context.fetch(fetchRequest)
            isEditingMeal = !foodItemRows.isEmpty
            print("Checked if editing. isEditingMeal set to \(isEditingMeal) with \(foodItemRows.count) food item rows.")
            if !isEditingMeal {
                stopAutoSaveToCSV()
            }
        } catch {
            print("Failed to fetch food item rows: \(error)")
        }
    }
    
    func saveValuesToUserDefaults() {
        // Save values to UserDefaults
        UserDefaults.standard.set(registeredFatSoFar, forKey: "registeredFatSoFar")
        UserDefaults.standard.set(registeredProteinSoFar, forKey: "registeredProteinSoFar")
        UserDefaults.standard.set(registeredBolusSoFar, forKey: "registeredBolusSoFar")
        UserDefaults.standard.set(registeredCarbsSoFar, forKey: "registeredCarbsSoFar")
        
        if let mealDate = mealDate {
            UserDefaults.standard.set(mealDate, forKey: "mealDate") // Save Date if available
            print("Meal date saved to UserDefaults: \(mealDate)")
        } else {
            UserDefaults.standard.removeObject(forKey: "mealDate") // Remove if nil
            print("Meal date removed from UserDefaults.")
        }
        
        UserDefaults.standard.set(latestBolusSent, forKey: "latestBolusSent")
        
        UserDefaults.standard.synchronize() // Ensure immediate write to disk

        // Check if any of the registered values are non-zero before starting the countdown
        if registeredFatSoFar > 0 || registeredProteinSoFar > 0 || registeredBolusSoFar > 0 || registeredCarbsSoFar > 0 {
            // Add a short delay to give time for UserDefaults to save before starting the timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                FinishMealManager.shared.startFinishMealCountdown()
                if self.preBolus {
                    PreBolusManager.shared.startPreBolusCountdown()
                } else {
                    PreBolusManager.shared.stopPreBolusCountdown()
                }
            }
        } else {
            FinishMealManager.shared.stopFinishMealCountdown()
            PreBolusManager.shared.stopPreBolusCountdown()
            print("No values to register, notification timers stopped/not started.")
        }
    }
    
    func loadValuesFromUserDefaults() {
        registeredFatSoFar = UserDefaults.standard.double(forKey: "registeredFatSoFar")
        registeredProteinSoFar = UserDefaults.standard.double(forKey: "registeredProteinSoFar")
        registeredBolusSoFar = UserDefaults.standard.double(forKey: "registeredBolusSoFar")
        registeredCarbsSoFar = UserDefaults.standard.double(forKey: "registeredCarbsSoFar")
        
        // Load mealDate, if exists
        if let savedMealDate = UserDefaults.standard.object(forKey: "mealDate") as? Date {
            mealDate = savedMealDate
        } else {
            mealDate = nil // Reset if not found
        }
        latestBolusSent = UserDefaults.standard.double(forKey: "latestBolusSent")
    }
    
    private func resetVariablesToDefault() {
        registeredFatSoFar = 0.0
        registeredProteinSoFar = 0.0
        registeredBolusSoFar = 0.0
        registeredCarbsSoFar = 0.0
        latestBolusSent = 0.0
        mealDate = nil // Reset mealDate to nil

        saveValuesToUserDefaults() // Save the reset values to UserDefaults
        print("Variables reset to 0.0 and mealDate reset to nil, saved to UserDefaults")
    }
    
    private func startLateBreakfastTimer() {
        let currentDate = Date()
        UserDefaultsRepository.lateBreakfastStartTime = currentDate
        print("Override timer started at: \(currentDate)")
        lateBreakfastTimer?.invalidate()
        lateBreakfastTimer = Timer.scheduledTimer(timeInterval: lateBreakfastDuration, target: self, selector: #selector(turnOffLateBreakfastSwitch), userInfo: nil, repeats: false)
    }
    
    @objc private func turnOffLateBreakfastSwitch() {
        print("Override timer off")
        addButtonRowView.lateBreakfastSwitch.isOn = false
        lateBreakfastSwitchChanged(addButtonRowView.lateBreakfastSwitch)
    }
    
    func setLatestOverrideFactor(_ overrideFactor: Double) {
        let multipliedFactor = overrideFactor * 100
        let formattedFactor = String(format: "%.0f %%", multipliedFactor)
        UserDefaultsRepository.lateBreakfastFactorUsed = formattedFactor
    }
    
    // MARK: Methods (Observers)
    @objc public func totalRegisteredCarbsLabelDidChange(_ textField: UILabel) {
        if let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
            textField.text = text.replacingOccurrences(of: ",", with: ".")
        }
        // Check if carbs, fat, protein, and bolus are all 0
        if let text = totalRegisteredCarbsLabel?.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0"),
           Double(text) == 0,
           registeredFatSoFar == 0.0,
           registeredProteinSoFar == 0.0,
           registeredBolusSoFar == 0.0 {
            
            // If all are 0, set saveMealToHistory to false and reset registeredCarbsSoFar
            saveMealToHistory = false
            print("save meal to history false")
            registeredCarbsSoFar = 0
        } else {
            // If any are non-zero, proceed with saving
            saveMealToHistory = true
            print("save meal to history true")
            if let text = totalRegisteredCarbsLabel?.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0"),
               let carbsValue = Double(text) {
                registeredCarbsSoFar = carbsValue
            } else {
                registeredCarbsSoFar = 0
            }
            saveValuesToUserDefaults()
            print("saved to userdefaults")
        }
        updateTotalNutrients()
        updateHeadlineVisibility()
        updateRemainsBolus()
        updateClearAllButtonState()
        saveToCoreData()
        
        // Avoid looping
        if isPopoverChange {
            isPopoverChange = false
            return
        }
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        if let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
            textField.text = text.replacingOccurrences(of: ",", with: ".")
        }
        updateTotalNutrients()
        updateHeadlineVisibility()
    }
    
    @objc private func updateRSSButtonVisibility() {
        view.subviews.forEach { $0.removeFromSuperview() } // Clear all subviews from the main view
        NotificationCenter.default.removeObserver(self) // Remove all observers to avoid duplicates
        initializeComposeMealViewController() // Reinitialize the entire view controller
    }
    
    // MARK: Methods (Keyboard)
    @objc private func keyboardWillShow(notification: NSNotification) {
        adjustForKeyboard(notification: notification, keyboardShowing: true)
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        adjustForKeyboard(notification: notification, keyboardShowing: false)
    }
    
    private func adjustForKeyboard(notification: NSNotification, keyboardShowing: Bool) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        if keyboardShowing {
            // Adjust constraints when the keyboard is shown
            scrollViewBottomConstraint?.constant = -(keyboardHeight + 50)
            addButtonRowViewBottomConstraint?.constant = -(keyboardHeight - 88)
        } else {
            // Reset constraints when the keyboard is hidden
            scrollViewBottomConstraint?.constant = -150
            addButtonRowViewBottomConstraint?.constant = -10
        }
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: Methods (Navigation)
    @objc private func showMealHistory() {
        let mealHistoryVC = MealHistoryViewController()
        navigationController?.pushViewController(mealHistoryVC, animated: true)
    }
    
    @objc private func showFavoriteMeals() {
        let favoriteMealsVC = FavoriteMealsViewController()
        navigationController?.pushViewController(favoriteMealsVC, animated: true)
    }
    
    @objc private func showAddFoodItemViewController() {
        let addFoodItemVC = AddFoodItemViewController()
        addFoodItemVC.delegate = self
        navigationController?.pushViewController(addFoodItemVC, animated: true)
    }
    
    internal func addFavoriteMeal(_ favoriteMeal: NewFavoriteMeals) {
        guard let favoriteEntries = favoriteMeal.favoriteEntries as? Set<FoodItemFavorite> else {
            print("Error: Unable to retrieve favoriteEntries from favoriteMeal.")
            return
        }
        
        let sortedEntries = Array(favoriteEntries).sorted { $0.name ?? "" < $1.name ?? "" }
        
        for entry in sortedEntries {
            guard let foodItem = foodItems.first(where: { $0.id == entry.id }) ?? foodItems.first(where: { $0.name == entry.name }) else {
                print("Warning: Food item with \(entry.id != nil ? "id \(entry.id!)" : "name \(entry.name ?? "unknown")") not found in foodItems.")
                continue
            }
            
            let rowView = FoodItemRowView()
            rowView.foodItems = foodItems
            rowView.delegate = self
            rowView.translatesAutoresizingMaskIntoConstraints = false
            stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count)
            foodItemRows.append(rowView)
            
            rowView.setSelectedFoodItem(foodItem)
            rowView.portionServedTextField.text = formattedValue(entry.portionServed)
            rowView.portionServedTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
            
            rowView.onDelete = { [weak self] in
                self?.removeFoodItemRow(rowView)
            }
            rowView.onValueChange = { [weak self] in
                self?.updateTotalNutrients()
                self?.updateHeadlineVisibility()
            }
            
            rowView.calculateNutrients()
        }
        
        let startDoseTextString = self.startDoseGiven ? NSLocalizedString("+ DOS", comment: "+ DOS") : NSLocalizedString("+ STARTDOS", comment: "+ STARTDOS")
        startAmountLabel.text = startDoseTextString
        startAmountContainer.backgroundColor = .systemBlue
        
        updateTotalNutrients()
        updateClearAllButtonState()
        updateSaveFavoriteButtonState()
        updateHeadlineVisibility()
    }
    
    // MARK: Methods (Alerts)
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    internal func checkAndHandleExistingMeal(replacementAction: @escaping () -> Void, additionAction: @escaping () -> Void, completion: @escaping () -> Void) {
        if !foodItemRows.isEmpty {
            let alert = UIAlertController(title: NSLocalizedString("Lägg till eller ersätt?", comment: "Lägg till eller ersätt?"), message: NSLocalizedString("\nObs! Du har redan en pågående måltidsregistrering.\n\nVill du addera den nya måltiden till den pågående, eller vill du ersätta den pågående måltiden med den nya?", comment: "\nObs! Du har redan en pågående måltidsregistrering.\n\nVill du addera den nya måltiden till den pågående, eller vill du ersätta den pågående måltiden med den nya?"), preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Ersätt", comment: "Ersätt"), style: .destructive, handler: { _ in
                self.clearAllFoodItems()
                replacementAction()
                completion()
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Addera", comment: "Addera"), style: .default, handler: { _ in
                additionAction()
                completion()
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler:  nil))
            
            present(alert, animated: true, completion: nil)
        } else {
            additionAction()
            completion()
        }
    }
    
    private func showTemporaryOverrideAlert() {
        let overrideName = UserDefaultsRepository.lateBreakfastOverrideName ?? "förinställd"
        let alertController = UIAlertController(
            title: NSLocalizedString("Tillfällig eller förinställd override?", comment: "Tillfällig eller förinställd override?"),
            message: String(format: NSLocalizedString("\nVälj om du vill aktivera den förinställda overriden (%@), eller om du vill ställa in en tillfällig override.\n\nOm du vill använda en tillfällig override kan du ange värdet i procent nedan", comment: "\nVälj om du vill aktivera den förinställda overriden %@, eller om du vill ställa in en tillfällig override.\n\nOm du vill använda en tillfällig override kan du ange värdet i procent nedan"), overrideName),
            preferredStyle: .alert
        )
        alertController.addTextField { textField in
            textField.placeholder = NSLocalizedString("Ange override-faktor i %", comment: "Ange override-faktor i %")
            textField.keyboardType = .decimalPad
        }
        let confirmAction = UIAlertAction(title: NSLocalizedString("Använd tillfällig", comment: "Använd tillfällig"), style: .default) { [weak self] _ in
            guard let self = self else { return }
            let inputText = alertController.textFields?.first?.text?.replacingOccurrences(of: ",", with: ".") ?? ""
            let percentageFactor = Double(inputText) ?? 100
            self.temporaryOverrideFactor = percentageFactor / 100.0
            self.temporaryOverride = true // Set the flag to true
            self.crContainerBackgroundColor = .systemRed // Change color
            self.scheduledCarbRatio /= self.temporaryOverrideFactor // Adjust carb ratio
            self.setLatestOverrideFactor(self.temporaryOverrideFactor)
            self.updateScheduledValuesUI()
            self.updateTotalNutrients()
            UserDefaultsRepository.scheduledCarbRatio = self.scheduledCarbRatio
            
            if let crContainer = self.crContainer {
                crContainer.backgroundColor = self.crContainerBackgroundColor
            }
            if let addButtonRowView = self.addButtonRowView {
                let override = self.temporaryOverrideFactor * 100
                let formattedOverride = String(format: "%.0f", override)
                addButtonRowView.lateBreakfastContainer.backgroundColor = .systemRed
                addButtonRowView.lateBreakfastLabel.text = ("\(formattedOverride) %  ")
            }
        }
        let presetAction = UIAlertAction(title: String(format: NSLocalizedString("Använd %@", comment: "Använd %@"), overrideName), style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.temporaryOverride = false
            self.crContainerBackgroundColor = .systemRed
            self.scheduledCarbRatio /= self.lateBreakfastFactor
            self.setLatestOverrideFactor(self.lateBreakfastFactor)
            self.updateScheduledValuesUI()
            self.updateTotalNutrients()
            self.handleLateBreakfastSwitchOn()
            UserDefaultsRepository.scheduledCarbRatio = self.scheduledCarbRatio
            
            if let crContainer = self.crContainer {
                crContainer.backgroundColor = self.crContainerBackgroundColor
            }
            if let addButtonRowView = self.addButtonRowView {
                let override = self.lateBreakfastFactor * 100
                let formattedOverride = String(format: "%.0f", override)
                addButtonRowView.lateBreakfastContainer.backgroundColor = .systemRed
                addButtonRowView.lateBreakfastLabel.text = ("\(formattedOverride) %   ")
            }
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel) { [weak self] _ in
            guard let self = self else { return }
            turnOffLateBreakfastSwitch()
        }
        alertController.addAction(confirmAction)
        alertController.addAction(presetAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: Methods (Core data and csv handling)
    private func exportBlankCSV() {
        let blankCSVString = "foodItemID;portionServed;notEaten;registeredCarbsSoFar;registeredFatSoFar;registeredProteinSoFar;registeredBolusSoFar;mealDate\n"
        saveCSV(data: blankCSVString, fileName: "OngoingMeal.csv")
        print("Blank ongoing meal CSV export done")
    }

    
    private func saveCSV(data: String, fileName: String) {
        guard let dataSharingVC = dataSharingVC else { return }
        Task {
            await
            dataSharingVC.saveCSV(data: data, fileName: fileName)
        }
    }
    
    private func cleanDuplicateFiles() {
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            
            // Get the iCloud URL for the CarbsCounter directory
            guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/CarbsCounter") else {
                print("Failed to get iCloud URL.")
                return
            }
            do {
                // Get all files in the directory
                let files = try fileManager.contentsOfDirectory(at: iCloudURL, includingPropertiesForKeys: nil)
                
                // Filter files that match the pattern "OngoingMeal X.csv" (where X is a number)
                let duplicateFiles = files.filter { url in
                    let filename = url.lastPathComponent
                    return filename.starts(with: "OngoingMeal ") && filename.hasSuffix(".csv") && filename != "OngoingMeal.csv"
                }
                // Delete each duplicate file
                for file in duplicateFiles {
                    try fileManager.removeItem(at: file)
                    print("Deleted duplicate file: \(file.lastPathComponent)")
                }
            } catch {
                print("Error while cleaning up duplicate files: \(error)")
            }
        }
    }
    
    /// Core data functions
    func startAutoSaveToCSV() {
        if UserDefaultsRepository.allowSharingOngoingMeals {
            exportTimer?.invalidate()
            exportTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(exportToCSV), userInfo: nil, repeats: true)
            print("Auto-save to CSV started with a 30-second interval.")
        }
    }
    
    func stopAutoSaveToCSV() {
        exportTimer?.invalidate()
        exportTimer = nil
        print("Auto-save to CSV stopped.")
    }
    
    @objc func exportToCSV() {
        Task {
            await DataSharingViewController().exportOngoingMealToCSV()
        }
    }
    private func loadFoodItemsFromCoreData() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItemRow> = FoodItemRow.fetchRequest()
        
        do {
            let savedFoodItems = try context.fetch(fetchRequest)
            for savedFoodItem in savedFoodItems {
                if let foodItemID = savedFoodItem.foodItemID,
                   let foodItem = foodItems.first(where: { $0.id == foodItemID }) {
                    
                    let rowView = FoodItemRowView()
                    rowView.foodItems = foodItems
                    rowView.delegate = self
                    rowView.translatesAutoresizingMaskIntoConstraints = false
                    rowView.foodItemRow = savedFoodItem
                    rowView.setSelectedFoodItem(foodItem)
                    
                    let portionServedValue = formatNumber(savedFoodItem.portionServed)
                    rowView.portionServedTextField.text = portionServedValue == "0" ? nil : portionServedValue
                    
                    let notEatenValue = formatNumber(savedFoodItem.notEaten)
                    rowView.notEatenTextField.text = notEatenValue == "0" ? nil : notEatenValue
                    
                    stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count)
                    foodItemRows.append(rowView)
                    rowView.onDelete = { [weak self] in
                        self?.removeFoodItemRow(rowView)
                    }
                    rowView.onValueChange = { [weak self] in
                        self?.updateTotalNutrients()
                    }
                    rowView.calculateNutrients()
                }
            }
            loadValuesFromUserDefaults()
            
            // Set totalRegisteredCarbsLabel based on registeredCarbsSoFar
            let formattedLastValue = String(format: "%.0f g", registeredCarbsSoFar)
            totalRegisteredCarbsLabel.text = registeredCarbsSoFar == 0 ? nil : formattedLastValue
            
            // Check if any of the values (carbs, fat, protein, bolus) are greater than 0
            if let textValue = totalRegisteredCarbsLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0"),
               let numberValue = Double(textValue.replacingOccurrences(of: ",", with: "")),
               numberValue > 0 || registeredFatSoFar > 0.0 || registeredProteinSoFar > 0.0 || registeredBolusSoFar > 0.0 {
                
                saveMealToHistory = true // Set true if any of the values are greater than 0
            } else {
                saveMealToHistory = false // Reset if all the values are 0
            }
            initializeUIElements()
            updateTotalNutrients()
            updateClearAllButtonState()
            updateSaveFavoriteButtonState()
            updateHeadlineVisibility()
            updateStartAmountLabel()
        } catch {
            print("Debug - Failed to fetch FoodItemRows: \(error)")
        }
    }
    
    private func loadTemporaryFoodItemsFromCoreData() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItemTemporary> = FoodItemTemporary.fetchRequest()
        
        do {
            let savedTemporaryFoodItems = try context.fetch(fetchRequest)
            
            // Iterate through the fetched temporary food items
            for temporaryFoodItem in savedTemporaryFoodItems {
                // Ensure the temporary entry has an ID and find a matching food item
                if let foodItemID = temporaryFoodItem.entryId,
                   let foodItem = foodItems.first(where: { $0.id == foodItemID }) {
                    
                    // Create a new row view and set its properties
                    let rowView = FoodItemRowView()
                    rowView.foodItems = foodItems
                    rowView.delegate = self
                    rowView.translatesAutoresizingMaskIntoConstraints = false
                    
                    // Set the food item in the row view
                    rowView.setSelectedFoodItem(foodItem)
                    
                    // Set the portion served from the temporary entry
                    let portionServedValue = formatNumber(temporaryFoodItem.entryPortionServed)
                    rowView.portionServedTextField.text = portionServedValue == "0" ? nil : portionServedValue
                    
                    // Add the row view to the stack view
                    stackView.insertArrangedSubview(rowView, at: stackView.arrangedSubviews.count)
                    foodItemRows.append(rowView)
                    
                    // Set up the row view's event handlers
                    rowView.onDelete = { [weak self] in
                        self?.removeFoodItemRow(rowView)
                    }
                    rowView.onValueChange = { [weak self] in
                        self?.updateTotalNutrients()
                    }
                    
                    // Calculate the nutrients for the row view
                    rowView.calculateNutrients()
                }
            }
            
            // Delete all the temporary food items after loading them
            for item in savedTemporaryFoodItems {
                context.delete(item)
            }
            
            // Save the context to ensure the deletions are persisted
            try context.save()
            print("Temporary FoodItem entries loaded and cleared successfully")

            // Update the UI with the loaded values
            loadValuesFromUserDefaults()
            updateTotalNutrients()
            updateClearAllButtonState()
            updateSaveFavoriteButtonState()
            updateHeadlineVisibility()
            updateStartAmountLabel()
        } catch {
            print("Debug - Failed to fetch or delete FoodItemTemporary entries: \(error)")
        }
    }
    
    public func fetchFoodItems() {
        let context = CoreDataStack.shared.context
        let fetchRequest = NSFetchRequest<FoodItem>(entityName: "FoodItem")
        
        // Add a predicate to filter out items where the delete flag is true
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        
        do {
            let foodItems = try context.fetch(fetchRequest).sorted { ($0.name ?? "") < ($1.name ?? "") }
            DispatchQueue.main.async {
                self.foodItems = foodItems
                self.searchableDropdownViewController?.updateFoodItems(foodItems)
                print("fetchfooditems ran")
            }
        } catch {
            DispatchQueue.main.async {
                print("Failed to fetch food items: \(error)")
            }
        }
    }
    
    func saveToCoreData() {
        let context = CoreDataStack.shared.context
        
        //print("Current mealDate in ComposeMealVC: \(String(describing: self.mealDate))") // Debug print
        
        for rowView in foodItemRows {
            if let foodItemRow = rowView.foodItemRow {
                foodItemRow.portionServed = Double(rowView.portionServedTextField.text ?? "0") ?? 0
                foodItemRow.notEaten = Double(rowView.notEatenTextField.text ?? "0") ?? 0
                foodItemRow.foodItemID = rowView.selectedFoodItem?.id
                
                if let mealDate = self.mealDate {
                    foodItemRow.mealDate = mealDate
                    //print("Saving mealDate: \(mealDate) to existing FoodItemRow") // Debug print
                }
                
            } else {
                let foodItemRow = FoodItemRow(context: context)
                foodItemRow.portionServed = Double(rowView.portionServedTextField.text ?? "0") ?? 0
                foodItemRow.notEaten = Double(rowView.notEatenTextField.text ?? "0") ?? 0
                foodItemRow.foodItemID = rowView.selectedFoodItem?.id
                
                if let mealDate = self.mealDate {
                    foodItemRow.mealDate = mealDate
                    //print("Saving mealDate: \(mealDate) to new FoodItemRow") // Debug print
                }
                
                rowView.foodItemRow = foodItemRow
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Debug - Failed to save FoodItemRows: \(error)")
        }
    }


    
    private func saveMealHistory() async {
        guard !foodItemRows.isEmpty else {
            mealDate = nil // Reset mealDate to nil after exiting without saving
            print("No food items to save.")
            return
        }
        
        // Trigger data import before saving the new MealHistory entry
        print("Starting data import for Meal History before saving")
        guard let dataSharingVC = dataSharingVC else {
            print("DataSharingVC could not be instantiated.")
            return
        }
        
        // Import only the MealHistory CSV file
        await dataSharingVC.importCSVFiles(specificFileName: "MealHistory.csv")
        print("Data import complete for Meal History")

        let context = CoreDataStack.shared.context
        let mealHistory = MealHistory(context: context)
        
        // Set unique ID, date, and lastEdited
        mealHistory.id = UUID()
        mealHistory.mealDate = mealDate ?? Date()
        mealHistory.lastEdited = Date()  // Set lastEdited to current date
        
        // Set delete flag to false (as it's a new entry)
        mealHistory.delete = false
        
        // Calculate total net values
        mealHistory.totalNetCarbs = foodItemRows.reduce(0.0) { $0 + $1.netCarbs }
        mealHistory.totalNetFat = foodItemRows.reduce(0.0) { $0 + $1.netFat }
        mealHistory.totalNetProtein = foodItemRows.reduce(0.0) { $0 + $1.netProtein }
        mealHistory.totalNetBolus = registeredBolusSoFar
        
        // Add food entries to meal history
        for row in foodItemRows {
            if let foodItem = row.selectedFoodItem {
                let foodEntry = FoodItemEntry(context: context)
                foodEntry.entryId = foodItem.id
                foodEntry.entryName = foodItem.name
                foodEntry.entryCarbohydrates = foodItem.carbohydrates
                foodEntry.entryFat = foodItem.fat
                foodEntry.entryProtein = foodItem.protein
                foodEntry.entryEmoji = foodItem.emoji

                // Handle portion and not eaten text fields with commas replaced by periods
                let portionServedText = row.portionServedTextField.text?.replacingOccurrences(of: ",", with: ".") ?? "0"
                let notEatenText = row.notEatenTextField.text?.replacingOccurrences(of: ",", with: ".") ?? "0"
                foodEntry.entryPortionServed = Double(portionServedText) ?? 0
                foodEntry.entryNotEaten = Double(notEatenText) ?? 0

                // Add portion per piece values
                foodEntry.entryCarbsPP = foodItem.carbsPP
                foodEntry.entryFatPP = foodItem.fatPP
                foodEntry.entryProteinPP = foodItem.proteinPP
                foodEntry.entryPerPiece = foodItem.perPiece

                // Link the food entry to the meal history
                mealHistory.addToFoodEntries(foodEntry)
            }
        }
        
        // Save the context and handle errors
        do {
            try context.save()
            print("MealHistory saved successfully!")
            
            // Trigger the export after saving
            Task {
                print("Meal history export triggered")
                await dataSharingVC.exportMealHistoryToCSV()
            }
            
        } catch {
            print("Failed to save MealHistory: \(error)")
        }
        
        // Reset the state after saving
        saveMealToHistory = false
        mealDate = nil
    }

    
    @objc private func saveFavoriteMeals() {
        guard saveFavoriteButton != nil, let dataSharingVC = dataSharingVC else { return }
        
        Task {
            // Import only the FavoriteMeals CSV file before saving
            print("Starting data import for Favorite Meals")
            await dataSharingVC.importCSVFiles(specificFileName: "FavoriteMeals.csv")
            print("Data import complete for Favorite Meals")
            
            guard !foodItemRows.isEmpty else {
                let alert = UIAlertController(
                    title: NSLocalizedString("Inga livsmedel", comment: "Inga livsmedel"),
                    message: NSLocalizedString("Välj minst ett livsmedel för att spara en favorit.", comment: "Välj minst ett livsmedel för att spara en favorit."),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default))
                self.present(alert, animated: true)
                return
            }
            
            let nameAlert = UIAlertController(
                title: NSLocalizedString("Spara som favoritmåltid", comment: "Spara som favoritmåltid"),
                message: NSLocalizedString("Ange ett namn på måltiden:", comment: "Ange ett namn på måltiden:"),
                preferredStyle: .alert
            )
            nameAlert.addTextField { textField in
                textField.placeholder = NSLocalizedString("Namn", comment: "Namn")
                textField.autocorrectionType = .no
                textField.spellCheckingType = .no
                textField.autocapitalizationType = .sentences
                textField.textContentType = .none
                
                if #available(iOS 11.0, *) {
                    textField.inputAssistantItem.leadingBarButtonGroups = []
                    textField.inputAssistantItem.trailingBarButtonGroups = []
                }
            }
            
            let saveAction = UIAlertAction(title: NSLocalizedString("Spara", comment: "Spara"), style: .default) { [weak self] _ in
                guard let self = self else { return }
                let mealName = nameAlert.textFields?.first?.text ?? NSLocalizedString("Min favoritmåltid", comment: "Min favoritmåltid")
                
                // Create the NewFavoriteMeals entity
                let favoriteMeal = NewFavoriteMeals(context: CoreDataStack.shared.context)
                favoriteMeal.name = mealName
                favoriteMeal.id = UUID()
                favoriteMeal.delete = false
                favoriteMeal.lastEdited = Date()
                
                // Populate the relationship with FoodItemFavorite entries
                for row in self.foodItemRows {
                    if let foodItem = row.selectedFoodItem {
                        let foodItemFavorite = FoodItemFavorite(context: CoreDataStack.shared.context)
                        foodItemFavorite.id = foodItem.id ?? UUID()
                        foodItemFavorite.name = foodItem.name ?? ""
                        foodItemFavorite.portionServed = Double(row.portionServedTextField.text ?? "0") ?? 0.0
                        foodItemFavorite.perPiece = foodItem.perPiece
                        
                        // Add FoodItemFavorite to favoriteMeal relationship
                        favoriteMeal.addToFavoriteEntries(foodItemFavorite)
                    }
                }
                
                CoreDataStack.shared.saveContext()
                
                Task {
                    print("Favorite meals export triggered")
                    await dataSharingVC.exportFavoriteMealsToCSV()
                }
                
                let confirmAlert = UIAlertController(
                    title: NSLocalizedString("Lyckades", comment: "Lyckades"),
                    message: NSLocalizedString("Måltiden har sparats som favorit.", comment: "Måltiden har sparats som favorit."),
                    preferredStyle: .alert
                )
                confirmAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default))
                self.present(confirmAlert, animated: true)
            }
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler: nil)
            
            nameAlert.addAction(saveAction)
            nameAlert.addAction(cancelAction)
            present(nameAlert, animated: true)
        }
    }

    
    private func clearAllFoodItemRowsFromCoreData() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = FoodItemRow.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to delete FoodItemRows: \(error)")
        }
    }
    
    func deleteFoodItemRow(_ rowView: FoodItemRowView) {
        let context = CoreDataStack.shared.context
        if let foodItemRow = rowView.foodItemRow {
            context.delete(foodItemRow)
            
            do {
                try context.save()
                removeFoodItemRow(rowView)
            } catch {
                print("Failed to delete FoodItemRow: \(error)")
            }
        }
        checkIfEditing()
    }
    
    func exportFoodItemRows() -> [FoodItemRowData] {
        var foodItemRowData: [FoodItemRowData] = []
        
        for rowView in foodItemRows {
            if let foodItem = rowView.selectedFoodItem {
                let portionServed = Double(rowView.portionServedTextField.text ?? "") ?? 0.0
                let notEaten = Double(rowView.notEatenTextField.text ?? "") ?? 0.0
                let registeredCarbsSoFar = registeredCarbsSoFar
                let registeredFatSoFar = registeredFatSoFar
                let registeredProteinSoFar = registeredProteinSoFar
                let registeredBolusSoFar = registeredBolusSoFar
                
                let rowData = FoodItemRowData(
                    foodItemID: foodItem.id,
                    portionServed: portionServed,
                    notEaten: notEaten,
                    registeredCarbsSoFar: registeredCarbsSoFar,
                    registeredFatSoFar: registeredFatSoFar,
                    registeredProteinSoFar: registeredProteinSoFar,
                    registeredBolusSoFar: registeredBolusSoFar,
                    mealDate: self.mealDate
                )
                foodItemRowData.append(rowData)
            }
        }
        
        return foodItemRowData
    }

    
    private func getFoodItemByID(_ id: UUID?) -> FoodItem? {
        guard let id = id else { return nil }
        
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let items = try context.fetch(fetchRequest)
            return items.first
        } catch {
            print("Failed to fetch FoodItem with id \(id): \(error)")
            return nil
        }
    }
    
    // MARK: Methods (Overrides)
    private func handleLateBreakfastSwitchOn() {
        guard let overrideName = UserDefaultsRepository.lateBreakfastOverrideName else {
            print("No override name available")
            return
        }
        if UserDefaultsRepository.allowShortcuts {
            let caregiverName = UserDefaultsRepository.caregiverName
            let remoteSecretCode = UserDefaultsRepository.remoteSecretCode
            let combinedString = "Remote Override\n\(overrideName)\nInlagt av: \(caregiverName)\nHemlig kod: \(remoteSecretCode)"
            
            let alertTitle = NSLocalizedString("Aktivera override", comment: "Aktivera override")
            let alertMessage = String(format: NSLocalizedString("\nVill du även aktivera overriden \n%@ i iAPS/Trio?", comment: "Message asking if the user wants to activate the override in iAPS/Trio"), overrideName)
            
            let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("Nej", comment: "Nej"), style: .cancel, handler: nil)
            let yesAction = UIAlertAction(title: NSLocalizedString("Ja", comment: "Ja"), style: .default) { _ in
                self.sendOverrideRequest(combinedString: combinedString)
            }
            alertController.addAction(cancelAction)
            alertController.addAction(yesAction)
            present(alertController, animated: true, completion: nil)
        } else {
            let alertController = UIAlertController(title: NSLocalizedString("Manuell aktivering", comment: "Manuell aktivering"), message: String(format: NSLocalizedString("\nKom ihåg att aktivera overriden \n\(overrideName) i iAPS/Trio", comment: "\nKom ihåg att aktivera overriden \n'%@' i iAPS/Trio"), overrideName), preferredStyle: .alert)
            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default) { _ in
            }
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
    }
    
    private func sendOverrideRequest(combinedString: String) {
        if UserDefaultsRepository.method == "iOS Shortcuts" {
            guard let encodedString = combinedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                print("Failed to encode URL string")
                return
            }
            let urlString = "shortcuts://run-shortcut?name=CC%20Override&input=text&text=\(encodedString)"
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        } else {
            authenticateUser { [weak self] authenticated in
                guard let self = self else { return }
                if authenticated {
                    self.twilioRequest(combinedString: combinedString) { result in
                        switch result {
                        case .success:
                            AudioServicesPlaySystemSound(SystemSoundID(1322))
                            let alertController = UIAlertController(title: NSLocalizedString("Lyckades!", comment: "Lyckades!"), message: NSLocalizedString("\nKommandot levererades till iAPS/Trio", comment: "\nKommandot levererades till iAPS/Trio"), preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default) { _ in
                                self.dismiss(animated: true, completion: nil)
                            })
                            self.present(alertController, animated: true, completion: nil)
                        case .failure(let error):
                            AudioServicesPlaySystemSound(SystemSoundID(1053))
                            let alertController = UIAlertController(title: NSLocalizedString("Fel", comment: "Fel"), message: error.localizedDescription, preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
                            self.present(alertController, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }
    // MARK: Methods (Meal registration)
        @objc private func registeredContainerLongPressed() {
            print("Long press detected on registeredContainer")

            hideAllDeleteButtons()

            let emojis = "🔂"

            // Replace "--" with "0" in totalStartAmountLabel and totalStartBolusLabel
            let khValue = "0"
            let fatValue = "0"
            let proteinValue = "0"
            let bolusValue = String(latestBolusSent)
            
            let method: String
            if UserDefaultsRepository.method == "iOS Shortcuts" {
                method = "iOS Shortcuts"
            } else if UserDefaultsRepository.method == "Trio APNS" {
                method = "Trio APNS"
            } else {
                method = "SMS API"
            }
            let bolusSoFar = String(format: "%.2f", registeredBolusSoFar)
            
            // Replace "--" with "0" in totalBolusAmountLabel
            let bolusTotal = totalBolusAmountLabel.text?.replacingOccurrences(of: NSLocalizedString(" E", comment: " E"), with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
            
            let carbsSoFar = String(format: "%.0f", registeredCarbsSoFar)
            // Replace "--" with "0" in totalNetCarbsLabel
            let carbsTotal = totalNetCarbsLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
            
            let fatSoFar = String(format: "%.0f", registeredFatSoFar)
            // Replace "--" with "0" in totalNetFatLabel
            let fatTotal = totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
            
            let proteinSoFar = String(format: "%.0f", registeredProteinSoFar)
            // Replace "--" with "0" in totalNetProteinLabel
            let proteinTotal = totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
            
            let cr = nowCRLabel.text?.replacingOccurrences(of: NSLocalizedString(" g/E", comment: " g/E"), with: "") ?? "0"
            
            let startDose = false
            let remainDose = false
            
            if !allowShortcuts {
                // Use alert when manually registering
                let alertController = UIAlertController(
                    title: NSLocalizedString("Manuell registrering", comment: "Manual registration"),
                    message: String(format: NSLocalizedString("\nRegistrera nu den angivna startdosen för måltiden %@ g kh och %@ E insulin i iAPS/Trio", comment: "Prompt to register the specified start dose for the meal in iAPS/Trio"), khValue, bolusValue),
                    preferredStyle: .alert
                )
                let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler: nil)
                let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default) { _ in
                    print("Manual bolus retry ok")
                }
                alertController.addAction(cancelAction)
                alertController.addAction(okAction)
                present(alertController, animated: true, completion: nil)
            } else {
                /*
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                if let mealVC = storyboard.instantiateViewController(withIdentifier: "MealViewController") as? MealViewController {
                    mealVC.delegate = self
                    let navigationController = UINavigationController(rootViewController: mealVC)
                    navigationController.modalPresentationStyle = .pageSheet
                    
                    present(navigationController, animated: true, completion: {
                        mealVC.populateMealViewController(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: bolusValue, emojis: emojis, bolusSoFar: bolusSoFar, bolusTotal: bolusTotal, carbsSoFar: carbsSoFar, carbsTotal: carbsTotal, fatSoFar: fatSoFar, fatTotal: fatTotal, proteinSoFar: proteinSoFar, proteinTotal: proteinTotal, method: method, startDose: startDose, remainDose: remainDose, cr: cr, retry: true)
                    })
                }*/
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    if let mealVC = storyboard.instantiateViewController(withIdentifier: "MealViewController") as? MealViewController {
                        mealVC.delegate = self
                        mealVC.khValue = khValue
                        mealVC.fatValue = fatValue
                        mealVC.proteinValue = proteinValue
                        mealVC.bolusValue = bolusValue
                        mealVC.emojis = emojis
                        mealVC.bolusSoFar = bolusSoFar
                        mealVC.bolusTotal = bolusTotal
                        mealVC.carbsSoFar = carbsSoFar
                        mealVC.carbsTotal = carbsTotal
                        mealVC.fatSoFar = fatSoFar
                        mealVC.fatTotal = fatTotal
                        mealVC.proteinSoFar = proteinSoFar
                        mealVC.proteinTotal = proteinTotal
                        mealVC.method = method
                        mealVC.startDose = startDose
                        mealVC.remainDose = remainDose
                        mealVC.cr = cr
                        mealVC.retry = true

                        let navigationController = UINavigationController(rootViewController: mealVC)
                        navigationController.modalPresentationStyle = .pageSheet
                        
                        present(navigationController, animated: true)
                    }
            }
            
            // Fetch device status from Nightscout after all UI actions
            NightscoutManager.shared.fetchDeviceStatus {
                DispatchQueue.main.async {
                    print("Device status has been updated.")
                }
            }
        }
    
    @objc private func startAmountContainerTapped() {
        if registeredCarbsSoFar == 0 && registeredFatSoFar == 0 && registeredProteinSoFar == 0 {
            mealDate = Date()
        }
        hideAllDeleteButtons()
        createEmojiString()
        
        self.preBolus = self.foodItemRows.isEmpty
        let emojis = self.preBolus ? "⏱️" : self.getMealEmojis()

        // Replace "--" with "0" in totalStartAmountLabel and totalStartBolusLabel
        let khValue = formatValue(totalStartAmountLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0")
        let fatValue = "0"
        let proteinValue = "0"
        let bolusValue = formatValue(totalStartBolusLabel.text?.replacingOccurrences(of: NSLocalizedString("E", comment: "E"), with: "").replacingOccurrences(of: "--", with: "0") ?? "0")
        
        let method: String
        if UserDefaultsRepository.method == "iOS Shortcuts" {
            method = "iOS Shortcuts"
        } else if UserDefaultsRepository.method == "Trio APNS" {
            method = "Trio APNS"
        } else {
            method = "SMS API"
        }
        let bolusSoFar = String(format: "%.2f", registeredBolusSoFar)
        
        // Replace "--" with "0" in totalBolusAmountLabel
        let bolusTotal = totalBolusAmountLabel.text?.replacingOccurrences(of: NSLocalizedString(" E", comment: " E"), with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
        
        let carbsSoFar = String(format: "%.0f", registeredCarbsSoFar)
        // Replace "--" with "0" in totalNetCarbsLabel
        let carbsTotal = totalNetCarbsLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
        
        let fatSoFar = String(format: "%.0f", registeredFatSoFar)
        // Replace "--" with "0" in totalNetFatLabel
        let fatTotal = totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
        
        let proteinSoFar = String(format: "%.0f", registeredProteinSoFar)
        // Replace "--" with "0" in totalNetProteinLabel
        let proteinTotal = totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
        
        let cr = nowCRLabel.text?.replacingOccurrences(of: NSLocalizedString(" g/E", comment: " g/E"), with: "") ?? "0"
        
        let startDose = true
        let remainDose = false
        
        if !allowShortcuts {
            // Use alert when manually registering
            let alertController = UIAlertController(
                title: NSLocalizedString("Manuell registrering", comment: "Manual registration"),
                message: String(format: NSLocalizedString("\nRegistrera nu den angivna startdosen för måltiden %@ g kh och %@ E insulin i iAPS/Trio", comment: "Prompt to register the specified start dose for the meal in iAPS/Trio"), khValue, bolusValue),
                preferredStyle: .alert
            )
            let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Avbryt"), style: .cancel, handler: nil)
            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default) { _ in
                self.updateRegisteredAmount(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: bolusValue, startDose: true)
                self.startDoseGiven = true
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        } else {
            /*let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let mealVC = storyboard.instantiateViewController(withIdentifier: "MealViewController") as? MealViewController {
                mealVC.delegate = self
                let navigationController = UINavigationController(rootViewController: mealVC)
                navigationController.modalPresentationStyle = .pageSheet
                
                present(navigationController, animated: true, completion: {
                    mealVC.populateMealViewController(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: bolusValue, emojis: emojis, bolusSoFar: bolusSoFar, bolusTotal: bolusTotal, carbsSoFar: carbsSoFar, carbsTotal: carbsTotal, fatSoFar: fatSoFar, fatTotal: fatTotal, proteinSoFar: proteinSoFar, proteinTotal: proteinTotal, method: method, startDose: startDose, remainDose: remainDose, cr: cr, retry: false)
                })
            }*/
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
                if let mealVC = storyboard.instantiateViewController(withIdentifier: "MealViewController") as? MealViewController {
                    mealVC.delegate = self
                    mealVC.khValue = khValue
                    mealVC.fatValue = fatValue
                    mealVC.proteinValue = proteinValue
                    mealVC.bolusValue = bolusValue
                    mealVC.emojis = emojis
                    mealVC.bolusSoFar = bolusSoFar
                    mealVC.bolusTotal = bolusTotal
                    mealVC.carbsSoFar = carbsSoFar
                    mealVC.carbsTotal = carbsTotal
                    mealVC.fatSoFar = fatSoFar
                    mealVC.fatTotal = fatTotal
                    mealVC.proteinSoFar = proteinSoFar
                    mealVC.proteinTotal = proteinTotal
                    mealVC.method = method
                    mealVC.startDose = startDose
                    mealVC.remainDose = remainDose
                    mealVC.cr = cr
                    mealVC.retry = false

                    let navigationController = UINavigationController(rootViewController: mealVC)
                    navigationController.modalPresentationStyle = .pageSheet
                    
                    present(navigationController, animated: true)
                }
        }
        
        // Fetch device status from Nightscout after all UI actions
        NightscoutManager.shared.fetchDeviceStatus {
            DispatchQueue.main.async {
                print("Device status has been updated.")
            }
        }
    }
    
    @objc private func remainContainerTapped() {
        if mealDate == nil {
            mealDate = Date()
        }
        hideAllDeleteButtons()
        createEmojiString()
        
        //FinishMealManager.shared.startFinishMealCountdown()

        // Replace "--" with "0" in totalRemainsLabel and totalRemainsBolusLabel
        let remainsValue = Double(totalRemainsLabel.text?
            .replacingOccurrences(of: "g", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "--", with: "0") ?? "0") ?? 0.0

        let bolusRemainsValue = Double(totalRemainsBolusLabel.text?
            .replacingOccurrences(of: NSLocalizedString("E", comment: "E"), with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "--", with: "0") ?? "0") ?? 0.0

        if bolusRemainsValue < 0 {
            let bolusText = totalRemainsBolusLabel.text?
                .replacingOccurrences(of: NSLocalizedString("E", comment: "E"), with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ",", with: ".") ?? "0"
            let crText = nowCRLabel.text?
                .replacingOccurrences(of: NSLocalizedString(" g/E", comment: " g/E"), with: "")
                .replacingOccurrences(of: ",", with: ".") ?? "0"

            if let bolusValue = Double(bolusText), let crValue = Double(crText) {
                let khValue = bolusValue * crValue
                let formattedKhValue = formatValue(String(format: "%.0f", khValue))
                let alert = UIAlertController(
                    title: NSLocalizedString("Varning", comment: "Varning"),
                    message: String(format: NSLocalizedString("\nDu har registrerat mer insulin än det beräknade behovet! \n\nSe till att komplettera med %@ g kolhydrater för att undvika ett lågt blodsocker!", comment: "Insulin exceeds carbs warning"), formattedKhValue),
                    preferredStyle: .alert
                )
                let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil)
                alert.addAction(okAction)
                present(alert, animated: true, completion: nil)
                return
            } else {
                print("Invalid input for calculation")
            }
        } else if remainsValue < 0 {
            let khValue = totalRemainsLabel.text?
                .replacingOccurrences(of: "g", with: " g")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ",", with: ".") ?? "0"
            let alert = UIAlertController(
                title: NSLocalizedString("Varning", comment: "Varning"),
                message: String(format: NSLocalizedString("\nDu har registrerat mer kolhydrater än vad som har ätits! \n\nSe till att komplettera med %@ kolhydrater för att undvika ett lågt blodsocker!", comment: "Carb registration exceeds intake warning"), khValue),
                preferredStyle: .alert
            )
            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
            return
        }

        // Replace "--" with "0" in totalNetFatLabel, totalNetProteinLabel, totalRemainsBolusLabel
        let khValue = formatValue(totalRemainsLabel.text?.replacingOccurrences(of: "g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0")
        let totalFatValue = Double(totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0") ?? 0.0
        let fatValue = formatValue("\(totalFatValue - registeredFatSoFar)")
        let totalProteinValue = Double(totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0") ?? 0.0
        let proteinValue = formatValue("\(totalProteinValue - registeredProteinSoFar)")
        let bolusValue = formatValue(totalRemainsBolusLabel.text?.replacingOccurrences(of: NSLocalizedString("E", comment: "E"), with: "").replacingOccurrences(of: "--", with: "0") ?? "0")

        var adjustedKhValue = khValue
        var adjustedBolusValue = self.zeroBolus ? "0.0" : bolusValue
        var showAlert = false

        if let maxCarbs = UserDefaultsRepository.maxCarbs as Double?,
           let khValueDouble = Double(khValue),
           khValueDouble > maxCarbs {
            adjustedKhValue = String(format: "%.0f", maxCarbs)
            if let carbRatio = Double(nowCRLabel.text?.replacingOccurrences(of: NSLocalizedString(" g/E", comment: " g/E"), with: "") ?? "0"),
               let currentBolusValue = Double(bolusValue) {
                let calculatedBolusValue = maxCarbs / carbRatio
                adjustedBolusValue = self.zeroBolus ? "0.0" : String(format: "%.2f", min(calculatedBolusValue, currentBolusValue))
            }
            showAlert = true
        }
        if let maxBolus = UserDefaultsRepository.maxBolus as Double?,
           let bolusValueDouble = Double(bolusValue),
           bolusValueDouble > maxBolus {
            adjustedBolusValue = String(format: "%.2f", maxBolus)
            showAlert = true
        }
        if showAlert {
            let maxCarbsAlert = UIAlertController(
                title: NSLocalizedString("Maxgräns överskriden", comment: "Max limit exceeded"),
                message: String(format: NSLocalizedString("\nMåltidsregistreringen på %@ g kolhydrater och %@ E bolus överskrider de angivna maxgränserna: %@ g kolhydrater och/eller %@ E bolus.\n\nDoseringen justeras därför ner till den angivna maxnivån i nästa steg...", comment: "Meal registration exceeds limits warning"), khValue, bolusValue, adjustedKhValue, adjustedBolusValue),
                preferredStyle: .alert
            )
            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default) { _ in
                self.proceedWithRemainingAmount(khValue: adjustedKhValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: adjustedBolusValue)
            }
            maxCarbsAlert.addAction(okAction)
            present(maxCarbsAlert, animated: true, completion: nil)
        } else {
            self.proceedWithRemainingAmount(khValue: adjustedKhValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: adjustedBolusValue)
        }
    }
    
    private func proceedWithRemainingAmount(khValue: String, fatValue: String, proteinValue: String, bolusValue: String) {
        // Replace "--" with "0" in the provided bolusValue
        let finalBolusValue = self.zeroBolus ? "0.0" : bolusValue.replacingOccurrences(of: "--", with: "0")
        let method: String
        if UserDefaultsRepository.method == "iOS Shortcuts" {
            method = "iOS Shortcuts"
        } else if UserDefaultsRepository.method == "Trio APNS" {
            method = "Trio APNS"
        } else {
            method = "SMS API"
        }

        let emojis: String
        if preBolus {
            emojis = "\(self.getMealEmojis())🍽️"
        } else if self.startDoseGiven {
            emojis = "🍽️"
        } else {
            emojis = "\(self.getMealEmojis())🍽️"
        }

        // Replace "--" with "0" in the labels
        let bolusSoFar = String(format: "%.2f", registeredBolusSoFar)
        let bolusTotal = totalBolusAmountLabel.text?.replacingOccurrences(of: NSLocalizedString(" E", comment: " E"), with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
        let carbsSoFar = String(format: "%.0f", registeredCarbsSoFar)
        let carbsTotal = totalNetCarbsLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
        let fatSoFar = String(format: "%.0f", registeredFatSoFar)
        let fatTotal = totalNetFatLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
        let proteinSoFar = String(format: "%.0f", registeredProteinSoFar)
        let proteinTotal = totalNetProteinLabel.text?.replacingOccurrences(of: " g", with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
        let cr = nowCRLabel.text?.replacingOccurrences(of: NSLocalizedString(" g/E", comment: " g/E"), with: "").replacingOccurrences(of: "--", with: "0") ?? "0"
        let startDose = true
        let remainDose = true

        if !allowShortcuts {
            var alertMessage = String(format: NSLocalizedString("\nRegistrera nu de kolhydrater som ännu inte registrerats i iAPS/Trio, och ge en bolus enligt summeringen nedan:\n\n• %@ g kolhydrater", comment: "\nRegister the unregistered carbs in iAPS/Trio and give a bolus as summarized:\n\n• %@ g carbs"), khValue)
            
            if let fat = Double(fatValue), fat > 0 {
                alertMessage += String(format: NSLocalizedString("\n• %@ g fett", comment: "\n• %@ g fat"), fatValue)
            }
            if let protein = Double(proteinValue), protein > 0 {
                alertMessage += String(format: NSLocalizedString("\n• %@ g protein", comment: "\n• %@ g protein"), proteinValue)
            }

            alertMessage += String(format: NSLocalizedString("\n• %@ E insulin", comment: "\n• %@ E insulin"), finalBolusValue)

            let alertController = UIAlertController(
                title: NSLocalizedString("Manuell registrering", comment: "Manual registration"),
                message: alertMessage,
                preferredStyle: .alert
            )
            let cancelAction = UIAlertAction(title: NSLocalizedString("Avbryt", comment: "Cancel"), style: .cancel, handler: nil)
            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default) { _ in
                self.updateRegisteredAmount(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: finalBolusValue, startDose: false)
                self.remainingDoseGiven = true
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)

        } else {
            /*let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let mealVC = storyboard.instantiateViewController(withIdentifier: "MealViewController") as? MealViewController {
                mealVC.delegate = self
                let navigationController = UINavigationController(rootViewController: mealVC)
                navigationController.modalPresentationStyle = .pageSheet

                present(navigationController, animated: true, completion: {
                    mealVC.populateMealViewController(khValue: khValue, fatValue: fatValue, proteinValue: proteinValue, bolusValue: bolusValue, emojis: emojis, bolusSoFar: bolusSoFar, bolusTotal: bolusTotal, carbsSoFar: carbsSoFar, carbsTotal: carbsTotal, fatSoFar: fatSoFar, fatTotal: fatTotal, proteinSoFar: proteinSoFar, proteinTotal: proteinTotal, method: method, startDose: startDose, remainDose: remainDose, cr: cr, retry: false)
                })
            }*/
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
                if let mealVC = storyboard.instantiateViewController(withIdentifier: "MealViewController") as? MealViewController {
                    mealVC.delegate = self
                    mealVC.khValue = khValue
                    mealVC.fatValue = fatValue
                    mealVC.proteinValue = proteinValue
                    mealVC.bolusValue = bolusValue
                    mealVC.emojis = emojis
                    mealVC.bolusSoFar = bolusSoFar
                    mealVC.bolusTotal = bolusTotal
                    mealVC.carbsSoFar = carbsSoFar
                    mealVC.carbsTotal = carbsTotal
                    mealVC.fatSoFar = fatSoFar
                    mealVC.fatTotal = fatTotal
                    mealVC.proteinSoFar = proteinSoFar
                    mealVC.proteinTotal = proteinTotal
                    mealVC.method = method
                    mealVC.startDose = startDose
                    mealVC.remainDose = remainDose
                    mealVC.cr = cr
                    mealVC.retry = false

                    let navigationController = UINavigationController(rootViewController: mealVC)
                    navigationController.modalPresentationStyle = .pageSheet
                    
                    present(navigationController, animated: true)
                }
        }

        // Fetch device status from Nightscout after all UI actions
        NightscoutManager.shared.fetchDeviceStatus {
            DispatchQueue.main.async {
                print("Device status has been updated.")
            }
        }
        
        // Reset preBolus to false
            self.preBolus = false
    }
    
    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate with biometrics to proceed"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        completion(true)
                    } else {
                        if let error = authenticationError as NSError?,
                           error.code == LAError.biometryNotAvailable.rawValue || error.code == LAError.biometryNotEnrolled.rawValue || error.code == LAError.biometryLockout.rawValue {
                            self.authenticateWithPasscode(completion: completion)
                        } else {
                            completion(false)
                        }
                    }
                }
            }
        } else {
            authenticateWithPasscode(completion: completion)
        }
    }
    
    private func authenticateWithPasscode(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        let reason = "Authenticate with passcode to proceed"
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    // MARK: Class (AddButtonRow)
    class AddButtonRowView: UIView {
        let addButton: UIButton = {
            let button = UIButton(type: .system)
            button.setTitle(NSLocalizedString("+ VÄLJ I LISTA", comment: "+ VÄLJ I LISTA"), for: .normal)
            let systemFont = UIFont.systemFont(ofSize: 12, weight: .bold)
            if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
                button.titleLabel?.font = UIFont(descriptor: roundedDescriptor, size: 12)
            } else {
                button.titleLabel?.font = systemFont
            }
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemBlue
            button.translatesAutoresizingMaskIntoConstraints = false
            button.layer.cornerRadius = 10
            button.layer.borderWidth = 0
            button.layer.borderColor = UIColor.white.cgColor
            button.clipsToBounds = true
            return button
        }()
        
        let rssButton: UIButton = {
            let button = UIButton(type: .system)
            button.setTitle(NSLocalizedString("+ SKOLMATEN", comment: "+ SKOLMATEN"), for: .normal)
            let systemFont = UIFont.systemFont(ofSize: 12, weight: .bold)
            if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
                button.titleLabel?.font = UIFont(descriptor: roundedDescriptor, size: 12)
            } else {
                button.titleLabel?.font = systemFont
            }
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemBlue
            button.translatesAutoresizingMaskIntoConstraints = false
            button.layer.cornerRadius = 10
            button.layer.borderWidth = 0
            button.layer.borderColor = UIColor.white.cgColor
            button.clipsToBounds = true
            button.addTarget(self, action: #selector(rssButtonTapped), for: .touchUpInside)
            return button
        }()
        
        let lateBreakfastSwitch: UISwitch = {
            let toggle = UISwitch()
            toggle.onTintColor = .clear
            toggle.translatesAutoresizingMaskIntoConstraints = false
            return toggle
        }()
        
        let lateBreakfastLabel: UILabel = {
            let label = UILabel()
            let systemFont = UIFont.systemFont(ofSize: 12, weight: .bold)
            if let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded) {
                label.font = UIFont(descriptor: roundedDescriptor, size: 12)
            } else {
                label.font = systemFont
            }
            label.text = NSLocalizedString("OVERRIDE", comment: "OVERRIDE")
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
            label.isUserInteractionEnabled = true
            return label
        }()

        let lateBreakfastContainer: UIView = {
            let view = UIView()
            view.backgroundColor = .systemGray3
            view.layer.cornerRadius = 10
            view.layer.borderWidth = 0
            view.layer.borderColor = UIColor.white.cgColor
            view.clipsToBounds = true
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupView()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupView() {
            lateBreakfastContainer.addSubview(lateBreakfastLabel)
            lateBreakfastContainer.addSubview(lateBreakfastSwitch)
            lateBreakfastSwitch.transform = CGAffineTransform(scaleX: 0.65, y: 0.65)
            
            var arrangedSubviews: [UIView] = [addButton, lateBreakfastContainer]
            if let schoolFoodURL = UserDefaultsRepository.schoolFoodURL, !schoolFoodURL.isEmpty {
                arrangedSubviews.insert(rssButton, at: 1) // Insert at index 1 to maintain the order
            }
            let stackView = UIStackView(arrangedSubviews: arrangedSubviews)
            stackView.axis = .horizontal
            stackView.alignment = .fill
            stackView.distribution = .fillEqually
            stackView.spacing = 8
            stackView.translatesAutoresizingMaskIntoConstraints = false

            addSubview(stackView)

            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                stackView.heightAnchor.constraint(equalToConstant: 44),
                stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
                lateBreakfastLabel.trailingAnchor.constraint(equalTo: lateBreakfastContainer.centerXAnchor, constant: 14),
                lateBreakfastLabel.centerYAnchor.constraint(equalTo: lateBreakfastContainer.centerYAnchor),
                lateBreakfastSwitch.leadingAnchor.constraint(equalTo: lateBreakfastContainer.centerXAnchor, constant: 7),
                lateBreakfastSwitch.centerYAnchor.constraint(equalTo: lateBreakfastContainer.centerYAnchor),
            ])
        }
    }
}
// MARK: Struct (InfoPopoverView)
struct InfoPopoverView: View {
    let title: String
    let message: String
    let statusTitle: String
    let statusMessage: String
    let progress: CGFloat
    let progressBarColor: Color
    let showProgressBar: Bool
    
    let backgroundColor = Color(red: 90/255, green: 104/255, blue: 145/255)
    
    var body: some View {
        ZStack {
            backgroundColor.opacity(0.7)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 12)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Text(statusTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 12)
                
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()

                if showProgressBar {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 20)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(progressBarColor)
                                .frame(width: min(progress, 1.0) * geometry.size.width, height: 20)
                        }
                        .frame(height: 20)
                    }
                    .padding([.leading, .trailing], 16)
                    .frame(height: 20)
                }
                
                Spacer()
            }
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
    }
}

