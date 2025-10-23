import SwiftUI
import PhotosUI
import SwiftData
import UIKit

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var parsedItems: [(name: String, price: Double)] = []
    @State private var expenseName = ""
    @State private var payerName = "Payer"
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var selectedPaymentMethod: PaymentMethod = .cash
    @State private var notes = ""
    @State private var showingParsedItems = false
    @State private var showingManualEntry = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var errorInfo: ErrorDisplayInfo?
    @State private var showingOCRTutorial = !UserDefaults.standard.bool(forKey: "hasSeenOCRTutorial")
    @State private var showingImagePicker = false
    @State private var showingCameraOptions = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @StateObject private var barcodeService = BarcodeService()
    @StateObject private var scanningService = ScanningService()
    @State private var showingItemSelection = false
    @State private var showingScanResults = false
    @State private var currentScanResult: ScanResult?
    @State private var selectedScanItems: Set<UUID> = []
    @State private var imageForOCR: UIImage?
    @State private var showingOCRImagePicker = false
    @State private var showingCodeScanOptions = false
    @State private var showingReceiptScanOptions = false
    @State private var showingCodeCamera = false
    @State private var showingReceiptCamera = false
    @State private var showingCodeGallery = false
    @State private var imageForCodeScan: UIImage?
    @State private var showingPreScanHelper = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Entry Method Selection
                    VStack(spacing: 16) {
                        Text("How would you like to add this expense?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        // OCR Tutorial Tip
                        if showingOCRTutorial {
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("💡")
                                                .font(.title2)
                                            Text("Quick Tip: OCR Scanning")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                        }
                                        Text("Scan receipts with your camera for automatic item detection!")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("📸 Works best with clear, well-lit photos of itemized receipts")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showingOCRTutorial = false
                                        UserDefaults.standard.set(true, forKey: "hasSeenOCRTutorial")
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .font(.title2)
                                    }
                                }
                                
                                    Button(action: {
                                        showingOCRTutorial = false
                                        UserDefaults.standard.set(true, forKey: "hasSeenOCRTutorial")
                                    }) {
                                        Text("Got It")
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Scanning Row (First Row)
                        HStack(spacing: 12) {
                            Button(action: { 
                                if UserDefaults.shouldShowScanHelp() {
                                    showingPreScanHelper = true
                                } else {
                                    showingCodeScanOptions = true
                                }
                            }) {
                                VStack(spacing: 8) {
                                    if scanningService.isScanning {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                            .accessibilityLabel("Scanning in progress")
                                    } else {
                                        Image(systemName: "qrcode")
                                            .font(.system(size: 30))
                                    }
                                    Text(scanningService.isScanning ? "Scanning..." : "Scan Code")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(scanningService.isScanning ? Color.gray : Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(scanningService.isScanning)
                            .accessibilityLabel(AccessibilityHelper.scanButton)
                            .accessibilityHint("Scans QR codes and barcodes from receipts")
                            
                            Button(action: { 
                                if UserDefaults.shouldShowScanHelp() {
                                    showingPreScanHelper = true
                                } else {
                                    showingReceiptScanOptions = true
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.text.viewfinder")
                                        .font(.system(size: 30))
                                    Text("Scan Receipt")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .accessibilityLabel("Scan receipt with camera OCR")
                            .accessibilityHint("Takes a photo of your receipt and extracts items automatically")
                        }
                        .padding(.horizontal)
                        
                        // Debug hint moved to bottom inset

                        // Manual Entry (smaller tertiary style)
                        Button(action: { showingManualEntry = true }) {
                            Label("Manual Entry", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .accessibilityLabel(AccessibilityHelper.manualEntryButton)
                        .accessibilityHint("Add expense items by typing them in manually")
                    }
                    
                    // Image Preview
                    if let selectedImage = selectedImage {
                        VStack(spacing: 12) {
                            Text("Receipt Image")
                                .font(.headline)
                            
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                                .shadow(radius: 3)
                        }
                    }
                    
                    // Expense Details Input
                    if selectedImage != nil || showingManualEntry {
                        VStack(spacing: 16) {
                            Text("Expense Details")
                                .font(.headline)
                            
                            VStack(spacing: 12) {
                                TextField("Expense name (e.g., Dinner at Italian Restaurant)", text: $expenseName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                TextField("Who paid for this?", text: $payerName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                // Category Picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Picker("Category", selection: $selectedCategory) {
                                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                                            HStack {
                                                Image(systemName: category.icon)
                                                Text(category.rawValue)
                                            }
                                            .tag(category)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                
                                // Payment Method Picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Payment Method")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Picker("Payment Method", selection: $selectedPaymentMethod) {
                                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                                            HStack {
                                                Image(systemName: method.icon)
                                                Text(method.rawValue)
                                            }
                                            .tag(method)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                
                                TextField("Notes (optional)", text: $notes, axis: .vertical)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(2...4)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 2)
                    }
                    
                    // Process/Continue Button
                    if (selectedImage != nil || showingManualEntry) && !expenseName.isEmpty && !payerName.isEmpty {
                        if selectedImage != nil {
                            Button(action: processImage) {
                                HStack {
                                    if isProcessing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .accessibilityLabel("Processing receipt")
                                    }
                                    Text(isProcessing ? "Processing Receipt..." : "Scan Receipt Items")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isProcessing ? Color(.systemGray) : Color(.systemGreen))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isProcessing)
                            .accessibilityLabel(isProcessing ? "Processing receipt image" : "Start OCR scanning of receipt")
                            .accessibilityHint(isProcessing ? "Please wait while we extract items from your receipt" : "Analyzes the receipt image and extracts items and prices")
                        } else {
                            Button(action: { showingParsedItems = true; parsedItems = [] }) {
                                Text("Continue to Add Items")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGreen))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .accessibilityLabel("Continue to manual item entry")
                            .accessibilityHint("Proceeds to add expense items manually")
                        }
                    }
                    
                    // Parsed/Manual Items Review
                    if showingParsedItems {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Expense Items")
                                    .font(.headline)
                                Spacer()
                                Button(action: addNewItem) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .accessibilityLabel(AccessibilityHelper.addItemButton)
                                .accessibilityHint("Adds a new blank item to the expense")
                            }
                            
                            if parsedItems.isEmpty {
                                VStack(spacing: 12) {
                                    Text("No items found in receipt")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("This is normal when scanning receipts without clear item details. You can add items manually.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Button(action: addNewItem) {
                                        Label("Add Item Manually", systemImage: "plus")
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(parsedItems.enumerated()), id: \.offset) { index, item in
                                        EditableItemRow(
                                            item: item,
                                            onUpdate: { updatedItem in
                                                parsedItems[index] = updatedItem
                                            },
                                            onDelete: {
                                                parsedItems.remove(at: index)
                                            }
                                        )
                                    }
                                }
                            }
                            
                            if !parsedItems.isEmpty {
                                let total = parsedItems.reduce(0) { $0 + $1.price }
                                HStack {
                                    Text("Total:")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text(total, format: .currency(code: "USD"))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                
                                Button(action: saveExpense) {
                                    Text("Save Expense")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemBlue))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                .disabled(expenseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || payerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityLabel(AccessibilityHelper.saveExpenseButton)
                                .accessibilityHint("Saves this expense with all items to your records")
                            } else {
                                Button(action: saveExpenseWithoutItems) {
                                    Text("Save Expense Without Items")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemBlue))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 3)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Replace title with a principal toolbar item so we can attach a hidden DEBUG gesture
                ToolbarItem(placement: .principal) {
                    Text("Add Expense")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
#if DEBUG
                        .onTapGesture(count: 5) {
                            debugLoadDemoReceipt()
                        }
#endif
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let newItem = newItem {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                            showingManualEntry = false
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .errorAlert($errorInfo)
        .confirmationDialog("Select Image Source", isPresented: $showingCameraOptions, titleVisibility: .visible) {
            Button("Camera") {
                showingImagePicker = true
            }
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text("Photo Library")
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, showingManualEntry: $showingManualEntry)
        }
        .sheet(isPresented: $showingOCRImagePicker) {
            ImagePicker(selectedImage: $imageForOCR, showingManualEntry: .constant(false), sourceType: .photoLibrary)
        }
        .sheet(item: $currentScanResult) { scanResult in
            if showingItemSelection {
                ItemSelectionView(
                    scanResult: scanResult,
                    selectedItems: $selectedScanItems,
                    onConfirm: { selectedItems in
                        addAllScannedItems(selectedItems)
                        showingItemSelection = false
                        currentScanResult = nil
                    },
                    onBack: {
                        showingItemSelection = false
                    }
                )
            } else {
                ScanningResultsView(
                    scanResult: scanResult,
                    onAddAll: {
                        addAllScannedItems(scanResult.items)
                        currentScanResult = nil
                    },
                    onChooseItems: {
                        selectedScanItems = [] // Start with no items selected
                        showingItemSelection = true
                    },
                    onCancel: {
                        currentScanResult = nil
                    }
                )
            }
        }
        .onChange(of: imageForOCR) { _, newImage in
            if let image = newImage {
                performOCR(on: image)
            }
        }
        .onChange(of: imageForCodeScan) { _, newImage in
            if let image = newImage {
                performCodeScanFromImage(on: image)
            }
        }
        .overlay(alignment: .bottom) {
            #if DEBUG
            Text("Debug: tap title 5× to load sample")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
            #endif
        }
        .confirmationDialog("Scan Code Options", isPresented: $showingCodeScanOptions, titleVisibility: .visible) {
            Button("Use Camera") {
                showingCodeCamera = true
            }
            
            Button("Choose from Gallery") {
                showingCodeGallery = true
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("How would you like to scan the barcode/QR code?")
        }
        .confirmationDialog("Scan Receipt Options", isPresented: $showingReceiptScanOptions, titleVisibility: .visible) {
            Button("Use Camera") {
                showingReceiptCamera = true
            }
            
            Button("Choose from Gallery") {
                showingOCRImagePicker = true
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("How would you like to scan the receipt?")
        }
        .sheet(isPresented: $showingCodeCamera) {
            CameraScannerView(scanType: .barcode) { result in
                handleCameraScanResult(result)
                showingCodeCamera = false
            }
        }
        .sheet(isPresented: $showingReceiptCamera) {
            CameraScannerView(scanType: .receipt) { result in
                handleCameraScanResult(result)
                showingReceiptCamera = false
            }
        }
        .sheet(isPresented: $showingCodeGallery) {
            ImagePicker(selectedImage: $imageForCodeScan, showingManualEntry: .constant(false), sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingPreScanHelper) {
            PreScanHelperView()
        }
        .loadingOverlay(isShowing: isProcessing, message: "Processing receipt image...")
        .loadingOverlay(isShowing: scanningService.isScanning, message: "Scanning for codes...")
    }
    
    private func addNewItem() {
        parsedItems.append((name: "", price: 0.0))
    }
    
    private func processImage() {
        guard let selectedImage = selectedImage else { return }
        
        isProcessing = true
        showingError = false
        
        Task {
            do {
                let ocrService = OCRService()
                let recognizedText = try await ocrService.recognizeText(from: selectedImage)
                
                let parseResult = ReceiptParser.parseReceiptTextEnhanced(recognizedText)
                let items = parseResult.items.map { ($0.name, $0.totalPrice) }
                
                await MainActor.run {
                    if items.isEmpty {
                        parsedItems = []
                        let errorInfo = ErrorHandler.handle(
                            error: ScanningError.noItemsFound,
                            context: "OCR Processing",
                            userMessage: "No items found in the receipt. This is normal for receipts without clear item details. You can add items manually."
                        )
                        self.errorInfo = errorInfo
                    } else {
                        parsedItems = items
                    }
                    
                    // Auto-populate expense name with store name if available and current name is empty
                    if expenseName.isEmpty, let storeName = parseResult.metadata.storeName {
                        expenseName = storeName
                    }
                    
                    showingParsedItems = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    let errorInfo = ErrorHandler.handle(
                        error: error,
                        context: "Receipt OCR Processing"
                    )
                    self.errorInfo = errorInfo
                    isProcessing = false
                    showingParsedItems = true
                    parsedItems = []
                }
            }
        }
    }
    
    private func saveExpense() {
        commitAllEditableRows()
        // Give rows a tick to push their updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        let expense = Expense(
            name: expenseName,
            payerName: payerName,
            paymentMethod: selectedPaymentMethod,
            category: selectedCategory,
            notes: notes
        )
        
        modelContext.insert(expense)
        
        for itemData in parsedItems {
            let item = ExpenseItem(name: itemData.name, price: itemData.price, expense: expense)
            modelContext.insert(item)
            expense.items.append(item)
        }
        
        try? modelContext.save()
        
        // Notify dashboard and widgets to update
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
        
        dismiss()
        }
    }
    
    private func saveExpenseWithoutItems() {
        commitAllEditableRows()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        let expense = Expense(
            name: expenseName,
            payerName: payerName,
            paymentMethod: selectedPaymentMethod,
            category: selectedCategory,
            notes: notes
        )
        
        modelContext.insert(expense)
        try? modelContext.save()
        
        // Notify dashboard and widgets to update
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
        
        dismiss()
        }
    }
    
    // MARK: - Production Scanning Methods
    
    private func performOCR(on image: UIImage) {
        Task {
            do {
                let result = try await scanningService.performOCR(on: image)
                
                // Auto-populate expense name if empty and we have store metadata
                if expenseName.isEmpty {
                    // We need to parse the OCR result again to get metadata 
                    let parseResult = ReceiptParser.parseReceiptTextEnhanced(result.originalText)
                    if let storeName = parseResult.metadata.storeName {
                        await MainActor.run {
                            expenseName = storeName
                        }
                    }
                }
                
                currentScanResult = result
            } catch {
                let errorInfo = ErrorHandler.handle(
                    error: error,
                    context: "Image OCR Processing"
                )
                self.errorInfo = errorInfo
            }
        }
    }
    
    private func addAllScannedItems(_ items: [ParsedItem]) {
        let newItems = items.map { ($0.name, $0.totalPrice) }
        parsedItems.append(contentsOf: newItems)
        showingParsedItems = true
        currentScanResult = nil
    }
    
    private func performCodeScanFromImage(on image: UIImage) {
        Task {
            do {
                // Use production barcode service for image-based scanning
                let payload = try await barcodeService.scanBarcode(from: image)
                
                if let receiptData = barcodeService.parseReceiptData(from: payload) {
                    let parser = ProductionReceiptParser()
                    let items = parser.parseItems(from: receiptData)
                    
                    let result = ScanResult(
                        type: .barcode,
                        sourceId: receiptData.transactionId,
                        items: items,
                        originalText: payload,
                        image: image
                    )
                    currentScanResult = result
                    showingScanResults = true
                } else {
                    // Treat as simple transaction ID and let user add items manually
                    let result = ScanResult(
                        type: .barcode,
                        sourceId: payload,
                        items: [], // Empty items - user will add manually
                        originalText: payload,
                        image: image
                    )
                    currentScanResult = result
                    showingScanResults = true
                }
            } catch {
                // Provide specific error message for barcode scanning
                let errorInfo = if let scanError = error as? BarcodeServiceError {
                    ErrorHandler.handle(error: scanError, context: "Barcode Scanning")
                } else {
                    ErrorHandler.handle(error: error, context: "Code Scanning")
                }
                self.errorInfo = errorInfo
            }
        }
    }
    
    private func handleCameraScanResult(_ result: ScanResult) {
        currentScanResult = result
        showingScanResults = true
    }

#if DEBUG
    /// Hidden developer gesture handler to load a bundled demo receipt
    private func debugLoadDemoReceipt() {
        guard let demo = UIImage(named: "DemoReceipt") else {
            let info = ErrorHandler.handle(
                error: ScanningError.invalidImage,
                context: "DEBUG Demo Receipt",
                userMessage: "DemoReceipt image not found in assets. Add an image asset named 'DemoReceipt'."
            )
            self.errorInfo = info
            return
        }

        // Try QR first from the same image, then fall back to OCR
        Task {
            do {
                let payload = try? await barcodeService.scanBarcode(from: demo)
                if let payload = payload, let receiptData = barcodeService.parseReceiptData(from: payload) {
                    let parser = ProductionReceiptParser()
                    let items = parser.parseItems(from: receiptData)
                    let result = ScanResult(
                        type: .barcode,
                        sourceId: receiptData.transactionId,
                        items: items,
                        originalText: payload,
                        image: demo
                    )
#if DEBUG
                    Task {
                        if let t = try? await OCRService().recognizeText(from: demo) {
                            print("RAW OCR TEXT:\n\(t)")
                        } else {
                            print("RAW OCR TEXT: <nil>")
                        }
                    }
#endif
                    await MainActor.run {
                        self.currentScanResult = result
                        self.showingScanResults = true
                    }
                } else {
                    // No structured data; run OCR
                    await MainActor.run {
                        self.performOCR(on: demo)
                    }
                }
            } catch {
                // If barcode scan fails, run OCR path
                await MainActor.run {
                    self.performOCR(on: demo)
                }
            }
        }
    }
#endif
}

// Notification used to ask all editable rows to commit their values silently
extension Notification.Name {
    static let commitEditableItems = Notification.Name("CommitEditableItemsNotification")
}

private extension AddExpenseView {
    func commitAllEditableRows() {
        NotificationCenter.default.post(name: .commitEditableItems, object: nil)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var showingManualEntry: Bool
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.showingManualEntry = false
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct EditableItemRow: View {
    @State private var item: (name: String, price: Double)
    let onUpdate: ((name: String, price: Double)) -> Void
    let onDelete: () -> Void
    @State private var isEditing = true // Start in editing mode for new items
    @State private var priceText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isNewItem = true
    @State private var swipeOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    
    // Swipe thresholds
    private let editThreshold: CGFloat = 80
    private let deleteThreshold: CGFloat = -80
    
    init(item: (name: String, price: Double), onUpdate: @escaping ((name: String, price: Double)) -> Void, onDelete: @escaping () -> Void) {
        self._item = State(initialValue: item)
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        // Start with blank price for new items, formatted price for existing items
        if item.name.isEmpty && item.price == 0.0 {
            self._priceText = State(initialValue: "")
            self._isNewItem = State(initialValue: true)
        } else {
            self._priceText = State(initialValue: String(format: "%.2f", item.price))
            self._isNewItem = State(initialValue: false)
            self._isEditing = State(initialValue: false)
        }
    }
    
    var body: some View {
        HStack {
            if isEditing {
                editingContent
            } else {
                displayContent
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .offset(x: dragOffset)
        .animation(.interactiveSpring(), value: dragOffset)
        .background(
            swipeBackgroundView
                .cornerRadius(8)
        )
        .gesture(
            isEditing ? nil : swipeGesture
        )
        .onReceive(NotificationCenter.default.publisher(for: .commitEditableItems)) { _ in
            validateAndSave()
        }
        .alert("Invalid Price", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var editingContent: some View {
        HStack {
            VStack(spacing: 8) {
                TextField("Item name", text: $item.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            isNewItem = false
                        }
                    }
                
                HStack {
                    Text("$")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    TextField("0.00", text: $priceText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .onTapGesture {
                            // Clear the field when user first taps if it's a new item
                            if isNewItem && priceText == "0.00" {
                                priceText = ""
                            }
                        }
                        .onChange(of: priceText) { _, newValue in
                            // Remove any existing dollar signs and format
                            let cleanValue = newValue.replacingOccurrences(of: "$", with: "")
                                .replacingOccurrences(of: ",", with: "")
                            
                            // Only allow digits and one decimal point
                            let filtered = cleanValue.filter { "0123456789.".contains($0) }
                            
                            // Ensure only one decimal point
                            let components = filtered.components(separatedBy: ".")
                            if components.count > 2 {
                                // If more than one decimal point, keep only the first one
                                priceText = components[0] + "." + components[1]
                            } else {
                                priceText = filtered
                            }
                            
                            // Mark as no longer new item once user starts typing
                            if !priceText.isEmpty {
                                isNewItem = false
                            }
                        }
                        .onSubmit {
                            validateAndSave()
                        }
                }
            }
            
            VStack(spacing: 4) {
                Button("Save") {
                    validateAndSave()
                }
                .foregroundColor(.green)
                .font(.caption)
                
                Button("Cancel") {
                    if isNewItem {
                        onDelete() // Delete if it's a new item and user cancels
                    } else {
                        priceText = String(format: "%.2f", item.price)
                        isEditing = false
                    }
                }
                .foregroundColor(.red)
                .font(.caption)
            }
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .accessibilityLabel(AccessibilityHelper.deleteItemButton)
            .accessibilityHint("Removes this item from the expense")
        }
    }
    
    private var displayContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                Text(item.price, format: .currency(code: "USD"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityHelper.expenseItemLabel(name: item.name, price: item.price))
            .accessibilityHint("Swipe right to edit, swipe left to delete")
            
            Spacer()
            
            // Show swipe hint only for non-editing items
            Text("⟷ Swipe to edit/delete")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
    }
    
    private var swipeBackgroundView: some View {
        HStack {
            // Edit background (right swipe)
            if dragOffset > 0 {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                        .font(.title2)
                    Text("Edit")
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue)
            }
            
            Spacer()
            
            // Delete background (left swipe)
            if dragOffset < 0 {
                HStack {
                    Spacer()
                    Text("Delete")
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .font(.title2)
                }
                .padding(.trailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.red)
            }
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let swipeDistance = value.translation.width
                
                withAnimation(.easeOut(duration: 0.3)) {
                    if swipeDistance > editThreshold {
                        // Right swipe - Edit
                        priceText = String(format: "%.2f", item.price)
                        isEditing = true
                        dragOffset = 0
                    } else if swipeDistance < deleteThreshold {
                        // Left swipe - Delete
                        onDelete()
                    } else {
                        // Return to center
                        dragOffset = 0
                    }
                }
            }
    }
    
    private func validateAndSave() {
        // Validate item name
        let cleanName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.isEmpty {
            alertMessage = "Please enter an item name"
            showingAlert = true
            return
        }
        
        // Clear any whitespace and validate price
        let cleanText = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanText.isEmpty {
            alertMessage = "Please enter a price"
            showingAlert = true
            return
        }
        
        guard let price = Double(cleanText), price >= 0 else {
            alertMessage = "Please enter a valid positive number"
            showingAlert = true
            return
        }
        
        // Update the item with validated data
        item.name = cleanName
        item.price = price
        isNewItem = false
        onUpdate(item)
        isEditing = false
    }
}

#Preview {
    AddExpenseView()
        .modelContainer(for: [Expense.self, ExpenseItem.self, Receipt.self, SplitRequest.self])
}
