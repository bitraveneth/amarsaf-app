class L10n {
  const L10n(this.code);

  final String code;

  bool get bn => code == 'bn';

  String get appName => 'AmarSaf';
  String get fieldBook => bn ? 'মাঠের খাতা' : 'Field book';
  String get signIn => bn ? 'প্রবেশ করুন' : 'Sign in';
  String get signingIn => bn ? 'প্রবেশ হচ্ছে…' : 'Signing in…';
  String get email => bn ? 'ইমেইল' : 'Email';
  String get password => bn ? 'পাসওয়ার্ড' : 'Password';
  String get showPassword => bn ? 'পাসওয়ার্ড দেখান' : 'Show password';
  String get hidePassword => bn ? 'পাসওয়ার্ড লুকান' : 'Hide password';
  String get accountFromOffice => bn
      ? 'এই অ্যাকাউন্ট অফিস থেকে দেওয়া।'
      : 'Your account comes from the office.';
  String get forgotPassword => bn ? 'পাসওয়ার্ড ভুলে গেছেন?' : 'Forgot password';
  String get officeResetsPassword => bn
      ? 'পাসওয়ার্ড অফিস রিসেট করে। নতুন পাসওয়ার্ডের জন্য অফিসে বলুন।'
      : 'The office resets passwords. Ask the office for a new one.';
  String get back => bn ? 'ফিরে যান' : 'Back';
  String get server => bn ? 'সার্ভার' : 'Server';
  String get serverHint => bn
      ? 'খালি রাখলে erp.amarsaf.com ব্যবহার হবে'
      : 'Leave blank to use erp.amarsaf.com';
  String get language => bn ? 'ভাষা' : 'Language';
  String get logout => bn ? 'বের হন' : 'Sign out';
  String get hello => bn ? 'আসসালামু আলাইকুম' : 'Hello';
  String get salesTitle => bn ? 'বিক্রয় কর্মী' : 'Sales';
  String get dealerTitle => bn ? 'ডিলার' : 'Dealer';
  String get attendance => bn ? 'আজকের উপস্থিতি' : "Today's attendance";
  String get taMonth => bn ? 'এ মাসের টিএ' : 'TA this month';
  String get daMonth => bn ? 'এ মাসের ডিএ' : 'DA this month';
  String get openVisits => bn ? 'বাকি ভিজিট' : 'Open visits';
  String get punch => bn ? 'হাজিরা' : 'Punch';
  String get visits => bn ? 'ভিজিট' : 'Visits';
  String get allowance => bn ? 'টিএ / ডিএ' : 'TA / DA';
  String get orderForDealer => bn ? 'ডিলারের অর্ডার' : 'Order for a dealer';
  String get products => bn ? 'পণ্য' : 'Products';
  String get newOrder => bn ? 'নতুন অর্ডার' : 'New order';
  String get myOrders => bn ? 'আমার অর্ডার' : 'My orders';
  String get dues => bn ? 'বকেয়া' : 'Dues';
  String get punchIn => bn ? 'হাজিরা দিন' : 'Punch in';
  String get punchOut => bn ? 'হাজিরা শেষ' : 'Punch out';
  String get onShift => bn ? 'শিফটে আছেন' : 'On shift';
  String get offShift => bn ? 'শিফট বন্ধ' : 'Off shift';
  String get notPunched => bn ? 'আজ এখনো হাজিরা হয়নি' : 'Not punched in yet';
  String get inAt => bn ? 'ঢুকেছেন' : 'In at';
  String get outAt => bn ? 'বের হয়েছেন' : 'Out at';
  String get pingNote => bn
      ? 'শিফট চলাকালীন অ্যাপ খোলা থাকলে প্রায় ১২ মিনিট পর পর লোকেশন পাঠানো হয়। হাজিরা শেষ হলে বা অ্যাপ বন্ধ থাকলে আর পাঠায় না।'
      : 'While you are punched in and this app is open, your location is sent about every 12 minutes. Punch out, or leave the app, and it stops.';
  String get waitingPunch => bn ? 'হাজিরা সিঙ্কের অপেক্ষায়' : 'Punch waiting to sync';
  String get lastPing => bn ? 'শেষ লোকেশন' : 'Last ping';
  String get today => bn ? 'আজ' : 'Today';
  String get addVisit => bn ? 'ভিজিট যোগ' : 'Add visit';
  String get dealer => bn ? 'ডিলার' : 'Dealer';
  String get slot => bn ? 'সময়' : 'Slot';
  String get notes => bn ? 'নোট' : 'Notes';
  String get save => bn ? 'সেভ' : 'Save';
  String get complete => bn ? 'সম্পন্ন' : 'Mark visited';
  String get completeWithoutGps => bn ? 'লোকেশন ছাড়া সম্পন্ন' : 'Complete without GPS';
  String get visited => bn ? 'হয়েছে' : 'Visited';
  String get planned => bn ? 'পরিকল্পিত' : 'Planned';
  String get amount => bn ? 'টাকা' : 'Amount';
  String get takePhoto => bn ? 'বিলের ছবি তুলুন' : 'Take bill photo';
  String get choosePhoto => bn ? 'গ্যালারি থেকে' : 'Choose from gallery';
  String get photoAttached => bn ? 'ছবি যোগ হয়েছে' : 'Photo attached';
  String get removePhoto => bn ? 'ছবি সরান' : 'Remove photo';
  String get submit => bn ? 'জমা দিন' : 'Submit';
  String get description => bn ? 'বিবরণ' : 'Description';
  String get date => bn ? 'তারিখ' : 'Date';
  String get deliveryDate => bn ? 'ডেলিভারির তারিখ' : 'Delivery date';
  String get search => bn ? 'খুঁজুন' : 'Search';
  String get searchProducts => bn ? 'নাম বা এসকেইউ' : 'Name or SKU';
  String get placeOrder => bn ? 'অর্ডার দিন' : 'Place order';
  String get orderType => bn ? 'অর্ডারের ধরন' : 'Order type';
  String get regular => bn ? 'নিয়মিত' : 'Regular';
  String get bulk => bn ? 'বাল্ক' : 'Bulk';
  String get sample => bn ? 'নমুনা' : 'Sample';
  String get returnOrder => bn ? 'ফেরত' : 'Return';
  String get noProducts => bn ? 'এই খোঁজে কোনো পণ্য নেই' : 'No products match that search';
  String get noOrders => bn ? 'এখনো কোনো অর্ডার নেই' : 'No orders yet';
  String get noBills => bn ? 'এখনো কোনো বিল নেই' : 'No bills yet';
  String get noVisits => bn ? 'আজকের কোনো ভিজিট নেই' : 'No visits for today';
  String get noDealers => bn ? 'আপনার জোনে কোনো ডিলার নেই' : 'No dealers in your zone';
  String get noStatement => bn ? 'এই সময়ে কোনো লেনদেন নেই' : 'No movements in this period';
  String get outstanding => bn ? 'বকেয়া' : 'Outstanding';
  String get closingBalance => bn ? 'শেষ ব্যালেন্স' : 'Closing balance';
  String get openOrders => bn ? 'খোলা অর্ডার' : 'Open orders';
  String get deliveredMonth => bn ? 'এ মাসে ডেলিভারি' : 'Delivered this month';
  String get retry => bn ? 'আবার চেষ্টা' : 'Try again';
  String get sync => bn ? 'সিঙ্ক' : 'Sync';
  String get queued => bn ? 'অপেক্ষমাণ' : 'waiting';
  String get syncFailed => bn ? 'সিঙ্ক হয়নি' : 'Could not sync';
  String get discard => bn ? 'ব্যর্থগুলো মুছুন' : 'Discard failed';
  String get driverLater => bn
      ? 'ড্রাইভারের স্ক্রিন এখনো এই অ্যাপে নেই।'
      : 'Driver screens are not in this app yet.';
  String get officeOnly => bn
      ? 'এই কাজ অফিসের কম্পিউটারেই থাকে।'
      : 'This work stays on the office computer.';
  String get noRole => bn
      ? 'এই লগইনে কর্মী বা ডিলার যুক্ত নেই। অফিসে বলুন অ্যাকাউন্ট ঠিক করতে।'
      : 'This login is not linked to an employee or a dealer. Ask the office to fix the account.';
  String get offlineSaved => bn
      ? 'নেট নেই। ফোনে জমা আছে, সিঙ্ক হলে সার্ভারে যাবে।'
      : 'No network. Saved on this phone and will send when you sync.';
  String get locationNeeded => bn
      ? 'হাজিরার জন্য লোকেশন চালু করুন।'
      : 'Turn on location to punch.';
  String get saved => bn ? 'সার্ভারে সেভ হয়েছে' : 'Saved on the server';
  String get required => bn ? 'এটি দিন' : 'This is required';
  String get invalidAmount => bn ? 'টাকার পরিমাণ দিন' : 'Enter an amount';
  String get pickDealer => bn ? 'একজন ডিলার বেছে নিন' : 'Choose a dealer';
  String get addItem => bn ? 'অন্তত একটি পণ্য দিন' : 'Add at least one product';
  String get status => bn ? 'স্ট্যাটাস' : 'Status';
  String get total => bn ? 'মোট' : 'Total';
  String get loading => bn ? 'লোড হচ্ছে…' : 'Loading…';
  String get recentBills => bn ? 'সাম্প্রতিক বিল' : 'Recent bills';
  String get targets => bn ? 'এ মাসের টার্গেট' : 'Target this month';
  String get achieved => bn ? 'অর্জিত' : 'Achieved';
  String get remaining => bn ? 'বাকি' : 'Remaining';
  String get statement => bn ? 'স্টেটমেন্ট' : 'Statement';
  String get ref => bn ? 'রেফারেন্স' : 'Reference';
  String get cancel => bn ? 'বাতিল' : 'Cancel';
  String get confirm => bn ? 'ঠিক আছে' : 'Confirm';
  String get qty => bn ? 'পরিমাণ' : 'Qty';
  String get price => bn ? 'দাম' : 'Price';
  String get cart => bn ? 'ঝুড়ি' : 'Cart';
  String get emptyCart => bn ? 'ঝুড়ি খালি' : 'Cart is empty';
  String get zoneNote => bn
      ? 'শুধু আপনার জোনের ডিলার।'
      : 'Dealers in your zone only.';
  String get home => bn ? 'হোম' : 'Home';
  String get pull => bn ? 'টেনে রিফ্রেশ' : 'Pull to refresh';
  String get signedOutNote => bn
      ? 'পাঠানোর আগে যে কাজ জমা ছিল, সেটি এই ফোনেই থাকবে। আবার ঢুকলে সিঙ্ক হবে।'
      : 'Work still waiting to send stays on this phone and syncs the next time you sign in.';
  String get billOptional => bn
      ? 'বিলের ছবি না দিলেও জমা যায়, থাকলে সঙ্গে যায়।'
      : 'A bill photo is optional. If you add one, it is stored with the claim.';
  String get typeTa => 'TA';
  String get typeDa => 'DA';
  String get nothingToSync => bn ? 'পাঠানোর মতো কিছু নেই' : 'Nothing waiting to send';
  String get synced => bn ? 'সিঙ্ক হয়ে গেছে' : 'Synced';
  String get gpsSaved => bn ? 'লোকেশন সেভ হয়েছে' : 'Location saved';
  String get visitSaved => bn ? 'ভিজিট যোগ হয়েছে' : 'Visit added';
  String get orderPlaced => bn ? 'অর্ডার কনফার্ম' : 'Order confirmed';
  String get claimSaved => bn ? 'বিল জমা হয়েছে' : 'Claim submitted';
  String get loadFailed => bn ? 'লোড করা যায়নি' : 'Could not load';
  String get searchDealers => bn ? 'ডিলারের নাম' : 'Dealer name';

  String orderTypeLabel(String type) {
    switch (type) {
      case 'bulk':
        return bulk;
      case 'sample':
        return sample;
      case 'return':
        return returnOrder;
      default:
        return regular;
    }
  }

  String statusLabel(String status) {
    switch (status) {
      case 'visited':
        return visited;
      case 'planned':
        return planned;
      case 'confirmed':
        return bn ? 'কনফার্ম' : 'Confirmed';
      case 'delivered':
        return bn ? 'ডেলিভার্ড' : 'Delivered';
      case 'submitted':
        return bn ? 'জমা' : 'Submitted';
      default:
        return status;
    }
  }
}
