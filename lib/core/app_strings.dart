import 'translations.dart';

class AppStrings {
  static String _lang = 'uz';
  static void setLanguage(String lang) => _lang = lang;
  static String get lang => _lang;

  // Common
  static String get appName => Translations.get('app_name', _lang);
  static String get cancel => Translations.get('cancel', _lang);
  static String get save => Translations.get('save', _lang);
  static String get languageSettings =>
      Translations.get('language_settings', _lang);
  static String get delete => Translations.get('delete', _lang);
  static String get edit => Translations.get('edit', _lang);
  static String get add => Translations.get('add', _lang);
  static String get loading => Translations.get('loading', _lang);
  static String get actions => Translations.get('actions', _lang);
  static String get status => Translations.get('status', _lang);
  static String get all => Translations.get('all', _lang);

  // Login
  static String get enterPin => Translations.get('enter_pin', _lang);
  static String get login => Translations.get('login', _lang);
  static String get logout => Translations.get('logout', _lang);

  // Sidebar
  static String get pos => Translations.get('pos', _lang);
  static String get products => Translations.get('products', _lang);
  static String get categories => Translations.get('categories', _lang);
  static String get reports => Translations.get('reports', _lang);

  // POS
  static String get currentOrder => Translations.get('current_order', _lang);
  static String get total => Translations.get('total', _lang);
  static String get checkout => Translations.get('checkout', _lang);
  static String get printReceipt => Translations.get('print_receipt', _lang);
  static String get changeTable => Translations.get('change_table', _lang);
  static String get selectTable => Translations.get('select_table', _lang);
  static String get moveOrder => Translations.get('move_order', _lang);
  static String get payment => Translations.get('payment', _lang);
  static String get paymentMethod => Translations.get('payment_method', _lang);
  static String get cash => Translations.get('cash', _lang);
  static String get card => Translations.get('card', _lang);
  static String get paymentSuccess =>
      Translations.get('payment_success', _lang);
  static String get paymentFailed => Translations.get('payment_failed', _lang);
  static String get amountDue => Translations.get('amount_due', _lang);

  // Products
  static String get productMgmt => Translations.get('product_mgmt', _lang);
  static String get addProduct => Translations.get('add_product', _lang);
  static String get editProduct => Translations.get('edit_product', _lang);
  static String get productName => Translations.get('product_name', _lang);
  static String get productPrice => Translations.get('product_price', _lang);
  static String get productCategory =>
      Translations.get('product_category', _lang);
  static String get selectCategory =>
      Translations.get('select_category', _lang);
  static String get productQuantity =>
      Translations.get('product_quantity', _lang);
  static String get insufficientStock =>
      Translations.get('insufficient_stock', _lang);

  // Categories
  static String get categoryMgmt => Translations.get('category_mgmt', _lang);
  static String get addCategory => Translations.get('add_category', _lang);
  static String get editCategory => Translations.get('edit_category', _lang);
  static String get categoryName => Translations.get('category_name', _lang);

  // Reports
  static String get salesReports => Translations.get('sales_reports', _lang);
  static String get totalOrders => Translations.get('total_orders', _lang);
  static String get totalRevenue => Translations.get('total_revenue', _lang);
  static String get recentTransactions =>
      Translations.get('recent_transactions', _lang);
  static String get orderNumber => Translations.get('order_number', _lang);
  static String get dateFrom => Translations.get('date_from', _lang);
  static String get dateTo => Translations.get('date_to', _lang);
  static String get filter => Translations.get('filter', _lang);

  // Statistics
  static String get productStats => Translations.get('product_stats', _lang);
  static String get soldCount => Translations.get('sold_count', _lang);
  static String get times => Translations.get('times', _lang);

  // Printing
  static String get printingReceipt =>
      Translations.get('printing_receipt', _lang);
  static String get printerError => Translations.get('printer_error', _lang);
  static String get printerNotFound =>
      Translations.get('printer_not_found', _lang);
  static String get restaurantName => '';
  static String get footerMessage => '';
  static String get date => Translations.get('date', _lang);
  static String get time => Translations.get('time', _lang);

  // Locations & Tables
  static String get locationMgmt => Translations.get('location_mgmt', _lang);
  static String get addLocation => Translations.get('add_location', _lang);
  static String get editLocation => Translations.get('edit_location', _lang);
  static String get locationName => Translations.get('location_name', _lang);

  static String get tableMgmt => Translations.get('table_mgmt', _lang);
  static String get addTable => Translations.get('add_table', _lang);
  static String get editTable => Translations.get('edit_table', _lang);
  static String get tableName => Translations.get('table_name', _lang);
  static String get selectLocation =>
      Translations.get('select_location', _lang);
  static String get tableStatus => Translations.get('table_status', _lang);

  static String get waiterMgmt => Translations.get('waiter_mgmt', _lang);
  static String get addWaiter => Translations.get('add_waiter', _lang);
  static String get editWaiter => Translations.get('edit_waiter', _lang);
  static String get waiterName => Translations.get('waiter_name', _lang);
  static String get waiterType => Translations.get('waiter_type', _lang);
  static String get waiterValue => Translations.get('waiter_value', _lang);
  static String get fixed => Translations.get('fixed', _lang);
  static String get percentage => Translations.get('percentage', _lang);

  // Warnings
  static String get warningDeleteLocation =>
      Translations.get('warning_delete_location', _lang);
  static String get warningDeleteTable =>
      Translations.get('warning_delete_table', _lang);

  // New strings
  static String get settings => Translations.get('settings', _lang);
  static String get language => Translations.get('language', _lang);
  static String get selectLanguage =>
      Translations.get('select_language', _lang);
  static String get waiter => Translations.get('waiter', _lang);
  static String get table => Translations.get('table', _lang);

  // Sidebar navigation
  static String get tablesNav => Translations.get('tables_nav', _lang);
  static String get productsNav => Translations.get('products_nav', _lang);
  static String get categoriesNav => Translations.get('categories_nav', _lang);
  static String get locationsNav => Translations.get('locations_nav', _lang);
  static String get tablesSettingsNav =>
      Translations.get('tables_settings_nav', _lang);
  static String get waitersNav => Translations.get('waiters_nav', _lang);
  static String get cashiersNav => Translations.get('cashiers_nav', _lang);
  static String get expensesNav => Translations.get('expenses_nav', _lang);
  static String get customersNav => Translations.get('customers_nav', _lang);
  static String get reportsNav => Translations.get('reports_nav', _lang);
  static String get printerNav => Translations.get('printer_nav', _lang);
  static String get receiptNav => Translations.get('receipt_nav', _lang);
  static String get pinNav => Translations.get('pin_nav', _lang);
  static String get brandNav => Translations.get('brand_nav', _lang);
  static String get connectionNav => Translations.get('connection_nav', _lang);
  static String get telegramNav => Translations.get('telegram_nav', _lang);
  static String get finance => Translations.get('finance', _lang);
  static String get stats => Translations.get('stats', _lang);

  static String get occupied => Translations.get('occupied', _lang);
  static String get available => Translations.get('available', _lang);
  static String get tableEmpty => Translations.get('table_empty', _lang);
  static String get orderSaved => Translations.get('order_saved', _lang);
  static String get back => Translations.get('back', _lang);
  static String get tableLabel => Translations.get('table_label', _lang);
  static String get kassa => Translations.get('kassa', _lang);
  static String get waiterKassa => Translations.get('waiter_kassa', _lang);
  static String get tableOccupiedError =>
      Translations.get('table_occupied_error', _lang);
  static String get minutesShort => Translations.get('minutes_short', _lang);
  static String get hoursShort => Translations.get('hours_short', _lang);
  static String get minutesShortLabel =>
      Translations.get('minutes_short_label', _lang);
  static String get saboy => Translations.get('saboy', _lang);

  static String get ordersTitle => Translations.get('orders_title', _lang);
  static String get operationsSubtitle =>
      Translations.get('operations_subtitle', _lang);
  static String get productsTitle => Translations.get('products_title', _lang);
  static String get topProductsSubtitle =>
      Translations.get('top_products_subtitle', _lang);
  static String get waitersTitle => Translations.get('waiters_title', _lang);
  static String get staffPerformanceSubtitle =>
      Translations.get('staff_performance_subtitle', _lang);
  static String get commissionAndSales =>
      Translations.get('commission_and_sales', _lang);
  static String get tablesTitle => Translations.get('tables_title', _lang);
  static String get tablesRevenueSubtitle =>
      Translations.get('tables_revenue_subtitle', _lang);
  static String get activeTablesAnalysis =>
      Translations.get('active_tables_analysis', _lang);
  static String get locationsTitle =>
      Translations.get('locations_title', _lang);
  static String get locationsSubtitle =>
      Translations.get('locations_subtitle', _lang);
  static String get byLocations => Translations.get('by_locations', _lang);
  static String get generalReportTitle =>
      Translations.get('general_report_title', _lang);
  static String get zreportSubtitle =>
      Translations.get('zreport_subtitle', _lang);
  static String get financialSummary =>
      Translations.get('financial_summary', _lang);
  static String get reportsTitle => Translations.get('reports_title', _lang);
  static String get reportsDescription =>
      Translations.get('reports_description', _lang);
  static String get aiAnalysis => Translations.get('ai_analysis', _lang);
  static String get generalReportAnalysis =>
      Translations.get('general_report_analysis', _lang);
  static String get syncTelegram => Translations.get('sync_telegram', _lang);
  static String get telegramSettingsTitle =>
      Translations.get('telegram_settings_title', _lang);
  static String get botToken => Translations.get('bot_token', _lang);
  static String get chatId => Translations.get('chat_id', _lang);
  static String get saveAndSend => Translations.get('save_and_send', _lang);
  static String get sendingReport => Translations.get('sending_report', _lang);
  static String get reportSentTelegram =>
      Translations.get('report_sent_telegram', _lang);
  static String get telegramError => Translations.get('telegram_error', _lang);

  static String get expensesTitle => Translations.get('expenses_title', _lang);
  static String get expenseTypes => Translations.get('expense_types', _lang);
  static String get addExpense => Translations.get('add_expense', _lang);
  static String get selectDate => Translations.get('select_date', _lang);
  static String get noExpenses => Translations.get('no_expenses', _lang);
  static String get noExpenseType => Translations.get('no_expense_type', _lang);
  static String get totalExpenses => Translations.get('total_expenses', _lang);
  static String get addExpenseTypeFirst =>
      Translations.get('add_expense_type_first', _lang);
  static String get newExpense => Translations.get('new_expense', _lang);
  static String get expenseType => Translations.get('expense_type', _lang);
  static String get amount => Translations.get('amount', _lang);
  static String get note => Translations.get('note', _lang);
  static String get confirmDeleteTitle =>
      Translations.get('confirm_delete_title', _lang);
  static String get confirmDeleteExpense =>
      Translations.get('confirm_delete_expense', _lang);

  static String get customersTitle =>
      Translations.get('customers_title', _lang);
  static String get newCustomer => Translations.get('new_customer', _lang);
  static String get emptyCustomers =>
      Translations.get('empty_customers', _lang);
  static String get debtLabel => Translations.get('debt_label', _lang);
  static String get creditLabel => Translations.get('credit_label', _lang);
  static String get balanceLabel => Translations.get('balance_label', _lang);
  static String get addCustomerTitle =>
      Translations.get('add_customer_title', _lang);
  static String get fullName => Translations.get('full_name', _lang);
  static String get phoneNumber => Translations.get('phone_number', _lang);

  static String get staffAnalysis => Translations.get('staff_analysis', _lang);
  static String get searchWaiterHint =>
      Translations.get('search_waiter_hint', _lang);
  static String get allTypes => Translations.get('all_types', _lang);
  static String get fixedLabel => Translations.get('fixed_label', _lang);
  static String get percentageLabel =>
      Translations.get('percentage_label', _lang);
  static String get noWaitersFound =>
      Translations.get('no_waiters_found', _lang);
  static String get primaryStaff => Translations.get('primary_staff', _lang);
  static String get waiterHasOrdersError =>
      Translations.get('waiter_has_orders_error', _lang);
  static String get adminOnlyError =>
      Translations.get('admin_only_error', _lang);
  static String get waiterDeletedSuccess =>
      Translations.get('waiter_deleted_success', _lang);
  static String get serviceFeeFixed =>
      Translations.get('service_fee_fixed', _lang);
  static String get serviceFeePercentage =>
      Translations.get('service_fee_percentage', _lang);
  static String get exampleFixed => Translations.get('example_fixed', _lang);
  static String get examplePercentage =>
      Translations.get('example_percentage', _lang);
  static String get pinCodeLabel => Translations.get('pin_code_label', _lang);
  static String get digitsOnlyHint =>
      Translations.get('digits_only_hint', _lang);
  static String get activeStaff => Translations.get('active_staff', _lang);

  static String get aiMenu => Translations.get('ai_menu', _lang);
  static String get menuOptimization =>
      Translations.get('menu_optimization', _lang);
  static String get reorder => Translations.get('reorder', _lang);
  static String get searchProductHint =>
      Translations.get('search_product_hint', _lang);
  static String get allCategories => Translations.get('all_categories', _lang);
  static String get allStatuses => Translations.get('all_statuses', _lang);
  static String get active => Translations.get('active', _lang);
  static String get outOfStock => Translations.get('out_of_stock', _lang);
  static String get noProductsFound =>
      Translations.get('no_products_found', _lang);
  static String get statusLabel => Translations.get('status_label', _lang);
  static String get productDeletedSuccess =>
      Translations.get('product_deleted_success', _lang);
  static String get productImage => Translations.get('product_image', _lang);
  static String get selectImage => Translations.get('select_image', _lang);
  static String get setProduct => Translations.get('set_product', _lang);
  static String get addItem => Translations.get('add_item', _lang);
  static String get changeOrder => Translations.get('change_order', _lang);
  static String get searchCategoryHint =>
      Translations.get('search_category_hint', _lang);
  static String get categoryDeletedSuccess =>
      Translations.get('category_deleted_success', _lang);
  static String get confirmDeleteCategory =>
      Translations.get('confirm_delete_category', _lang);

  static String get currencyLabel => Translations.get('currency_label', _lang);
  static String get deleteImage => Translations.get('delete_image', _lang);
  static String get setProductDescription =>
      Translations.get('set_product_description', _lang);
  static String get bundleItems => Translations.get('bundle_items', _lang);
  static String get noItemsAdded => Translations.get('no_items_added', _lang);
  static String get selectProduct => Translations.get('select_product', _lang);
  static String get searchHint => Translations.get('search_hint', _lang);
  static String get close => Translations.get('close', _lang);
  static String get categoryHasProducts =>
      Translations.get('category_has_products', _lang);
  static String get categoryColor => Translations.get('category_color', _lang);
  static String get reorderCategories =>
      Translations.get('reorder_categories', _lang);
  static String get noServiceCharge =>
      Translations.get('no_service_charge', _lang);
}
