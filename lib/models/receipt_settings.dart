class ReceiptSettings {
  final String restaurantName;
  final bool showRestaurantName;

  final String branchName;
  final bool showBranchName;

  final String phoneNumber;
  final bool showPhoneNumber;

  final String address;
  final bool showAddress;

  final String? logoPath;
  final bool showLogo;

  // Toggles
  final bool showDate;
  final bool showOrderNumber; // Buyurtma #
  final bool showTable; // Stol / Joy
  final bool showWaiter; // Ofitsiant
  final bool showPaymentType; // Naqd/Karta
  final bool showItemsTable; // Items list
  final bool showRoomCharges; // Xizmat/Xona breakdown

  final String footerMessage;
  final bool showFooter;

  // Behavior
  final bool cutPaper;
  final int feedLines;
  final int horizontalMargin; // 1, 2, or 3
  final bool showChange; // Qaytimni ko'rsatish
  final String layoutType; // 'table' or 'classic'

  // Formatting
  final bool headerBold;
  final bool totalBold; // Also larger

  ReceiptSettings({
    this.restaurantName = 'ZELLY',
    this.showRestaurantName = true,
    this.branchName = '',
    this.showBranchName = false,
    this.phoneNumber = '',
    this.showPhoneNumber = false,
    this.address = '',
    this.showAddress = false,
    this.logoPath,
    this.showLogo = false,
    this.showDate = true,
    this.showOrderNumber = true,
    this.showTable = true,
    this.showWaiter = true,
    this.showPaymentType = true,
    this.showItemsTable = true,
    this.showRoomCharges = true,
    this.footerMessage = '',
    this.showFooter = true,
    this.cutPaper = true,
    this.feedLines = 4,
    this.horizontalMargin = 2,
    this.showChange = false,
    this.layoutType = 'table',
    this.headerBold = true,
    this.totalBold = true,
  });

  Map<String, String> toMap() {
    return {
      'receipt_restaurant_name': restaurantName,
      'receipt_show_restaurant_name': showRestaurantName.toString(),
      'receipt_branch_name': branchName,
      'receipt_show_branch_name': showBranchName.toString(),
      'receipt_phone': phoneNumber,
      'receipt_show_phone': showPhoneNumber.toString(),
      'receipt_address': address,
      'receipt_show_address': showAddress.toString(),
      'receipt_logo_path': logoPath ?? '',
      'receipt_show_logo': showLogo.toString(),
      'receipt_show_date': showDate.toString(),
      'receipt_show_order_number': showOrderNumber.toString(),
      'receipt_show_table': showTable.toString(),
      'receipt_show_waiter': showWaiter.toString(),
      'receipt_show_payment_type': showPaymentType.toString(),
      'receipt_show_items_table': showItemsTable.toString(),
      'receipt_show_room_charges': showRoomCharges.toString(),
      'receipt_footer_message': footerMessage,
      'receipt_show_footer': showFooter.toString(),
      'receipt_cut_paper': cutPaper.toString(),
      'receipt_feed_lines': feedLines.toString(),
      'receipt_horizontal_margin': horizontalMargin.toString(),
      'receipt_show_change': showChange.toString(),
      'receipt_layout_type': layoutType,
      'receipt_header_bold': headerBold.toString(),
      'receipt_total_bold': totalBold.toString(),
    };
  }

  factory ReceiptSettings.fromMap(Map<String, dynamic> map) {
    bool parseBool(dynamic val, bool def) {
      if (val == null) return def;
      return val.toString().toLowerCase() == 'true';
    }

    return ReceiptSettings(
      restaurantName: map['receipt_restaurant_name'] ?? 'TEZZRO POS',
      showRestaurantName: parseBool(map['receipt_show_restaurant_name'], true),
      branchName: map['receipt_branch_name'] ?? '',
      showBranchName: parseBool(map['receipt_show_branch_name'], false),
      phoneNumber: map['receipt_phone'] ?? '',
      showPhoneNumber: parseBool(map['receipt_show_phone'], false),
      address: map['receipt_address'] ?? '',
      showAddress: parseBool(map['receipt_show_address'], false),
      logoPath:
          (map['receipt_logo_path'] != null &&
              map['receipt_logo_path'].isNotEmpty)
          ? map['receipt_logo_path']
          : null,
      showLogo: parseBool(map['receipt_show_logo'], false),
      showDate: parseBool(map['receipt_show_date'], true),
      showOrderNumber: parseBool(map['receipt_show_order_number'], true),
      showTable: parseBool(map['receipt_show_table'], true),
      showWaiter: parseBool(map['receipt_show_waiter'], true),
      showPaymentType: parseBool(map['receipt_show_payment_type'], true),
      showItemsTable: parseBool(map['receipt_show_items_table'], true),
      showRoomCharges: parseBool(map['receipt_show_room_charges'], true),
      footerMessage: map['receipt_footer_message'] ?? '',
      showFooter: parseBool(map['receipt_show_footer'], true),
      cutPaper: parseBool(map['receipt_cut_paper'], true),
      feedLines:
          int.tryParse(map['receipt_feed_lines']?.toString() ?? '4') ?? 4,
      horizontalMargin:
          int.tryParse(map['receipt_horizontal_margin']?.toString() ?? '2') ??
          2,
      showChange: parseBool(map['receipt_show_change'], false),
      layoutType: map['receipt_layout_type'] ?? 'table',
      headerBold: parseBool(map['receipt_header_bold'], true),
      totalBold: parseBool(map['receipt_total_bold'], true),
    );
  }

  ReceiptSettings copyWith({
    String? restaurantName,
    bool? showRestaurantName,
    String? branchName,
    bool? showBranchName,
    String? phoneNumber,
    bool? showPhoneNumber,
    String? address,
    bool? showAddress,
    String? logoPath,
    bool? showLogo,
    bool? showDate,
    bool? showOrderNumber,
    bool? showTable,
    bool? showWaiter,
    bool? showPaymentType,
    bool? showItemsTable,
    bool? showRoomCharges,
    String? footerMessage,
    bool? showFooter,
    bool? cutPaper,
    int? feedLines,
    int? horizontalMargin,
    bool? showChange,
    String? layoutType,
    bool? headerBold,
    bool? totalBold,
  }) {
    return ReceiptSettings(
      restaurantName: restaurantName ?? this.restaurantName,
      showRestaurantName: showRestaurantName ?? this.showRestaurantName,
      branchName: branchName ?? this.branchName,
      showBranchName: showBranchName ?? this.showBranchName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      showPhoneNumber: showPhoneNumber ?? this.showPhoneNumber,
      address: address ?? this.address,
      showAddress: showAddress ?? this.showAddress,
      logoPath: logoPath ?? this.logoPath,
      showLogo: showLogo ?? this.showLogo,
      showDate: showDate ?? this.showDate,
      showOrderNumber: showOrderNumber ?? this.showOrderNumber,
      showTable: showTable ?? this.showTable,
      showWaiter: showWaiter ?? this.showWaiter,
      showPaymentType: showPaymentType ?? this.showPaymentType,
      showItemsTable: showItemsTable ?? this.showItemsTable,
      showRoomCharges: showRoomCharges ?? this.showRoomCharges,
      footerMessage: footerMessage ?? this.footerMessage,
      showFooter: showFooter ?? this.showFooter,
      cutPaper: cutPaper ?? this.cutPaper,
      feedLines: feedLines ?? this.feedLines,
      horizontalMargin: horizontalMargin ?? this.horizontalMargin,
      showChange: showChange ?? this.showChange,
      layoutType: layoutType ?? this.layoutType,
      headerBold: headerBold ?? this.headerBold,
      totalBold: totalBold ?? this.totalBold,
    );
  }
}
