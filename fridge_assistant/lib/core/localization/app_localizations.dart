import 'package:fridge_assistant/core/localization/app_material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('vi'),
    Locale('en'),
  ];

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localization = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localization ?? AppLocalizations(const Locale('vi'));
  }

  String text(String value) {
    if (locale.languageCode != 'en') return value;

    final literal = _englishLiterals[value];
    if (literal != null) return literal;

    for (final rule in _englishRules) {
      final match = rule.pattern.firstMatch(value);
      if (match != null) {
        return rule.replace(match);
      }
    }

    return _translateByFragments(value);
  }

  InlineSpan translateSpan(InlineSpan span) {
    if (locale.languageCode != 'en') return span;

    if (span is TextSpan) {
      return TextSpan(
        text: span.text == null ? null : text(span.text!),
        children: span.children?.map(translateSpan).toList(),
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel == null
            ? null
            : text(span.semanticsLabel!),
        locale: span.locale,
        spellOut: span.spellOut,
      );
    }

    if (span is WidgetSpan) {
      return span;
    }

    return span;
  }

  static String _translateByFragments(String value) {
    var result = value;
    var changed = false;

    for (final item in _sortedEnglishFragments) {
      final next = _replaceCaseAware(result, item.source, item.target);
      if (next != result) {
        result = next;
        changed = true;
      }
    }

    if (!changed) return value;
    return _cleanSpacing(result);
  }

  static String _replaceCaseAware(
    String input,
    String source,
    String target,
  ) {
    if (source.isEmpty) return input;

    final variants = <String, String>{
      source: target,
      source.toLowerCase(): target.toLowerCase(),
      _capitalize(source): _capitalize(target),
      source.toUpperCase(): target.toUpperCase(),
    };

    var output = input;
    for (final entry in variants.entries) {
      output = output.replaceAll(entry.key, entry.value);
    }
    return output;
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static String _cleanSpacing(String value) {
    return value
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll(' ,', ',')
        .replaceAll(' .', '.')
        .replaceAll(' :', ':')
        .replaceAll('( ', '(')
        .replaceAll(' )', ')')
        .trim();
  }

  static String _englishWeekday(String value) {
    const weekdays = {
      'Chủ nhật': 'Sunday',
      'Thứ hai': 'Monday',
      'Thứ ba': 'Tuesday',
      'Thứ tư': 'Wednesday',
      'Thứ năm': 'Thursday',
      'Thứ sáu': 'Friday',
      'Thứ bảy': 'Saturday',
    };
    return weekdays[value] ?? value;
  }

  static String _englishMonth(String number) {
    const months = {
      '1': 'January',
      '2': 'February',
      '3': 'March',
      '4': 'April',
      '5': 'May',
      '6': 'June',
      '7': 'July',
      '8': 'August',
      '9': 'September',
      '10': 'October',
      '11': 'November',
      '12': 'December',
    };
    return months[number] ?? number;
  }

  static const Map<String, String> _englishLiterals = {
    'Bếp Trợ Lý': 'Kitchen Assistant',
    'Bếp trợ lí': 'Kitchen Assistant',
    'Sống xanh, nấu ăn ngon lành': 'Live green, cook delicious meals',
    'Đăng nhập hoặc tạo tài khoản mới': 'Sign in or create a new account',
    'Đăng nhập': 'Sign in',
    'Đăng ký': 'Register',
    'Đăng nhập Google thất bại': 'Google sign-in failed',
    'Đăng nhập thất bại': 'Sign-in failed',
    'Đăng ký thất bại': 'Registration failed',
    'Đăng nhập với Google': 'Sign in with Google',
    'Hoặc': 'Or',
    'Nhập email của bạn': 'Enter your email',
    'Mật khẩu': 'Password',
    'Nhập mật khẩu của bạn': 'Enter your password',
    'Quên mật khẩu?': 'Forgot password?',
    'Vui lòng nhập email': 'Please enter your email',
    'Email không hợp lệ': 'Invalid email',
    'Vui lòng nhập mật khẩu': 'Please enter your password',
    'Nhập mật khẩu': 'Enter password',
    'Nhập lại mật khẩu': 'Confirm password',
    'Nhập lại mật khẩu của bạn': 'Re-enter your password',
    'Vui lòng nhập lại mật khẩu': 'Please confirm your password',
    'Mật khẩu không khớp': 'Passwords do not match',
    'Đã có lỗi xảy ra. Vui lòng thử lại.': 'Something went wrong. Please try again.',
    'Người bạn đồng hành trong gian bếp': 'Your smart companion in the kitchen',
    'Theo dõi mọi nguyên liệu trong tủ lạnh của bạn một cách dễ dàng và trực quan.':
        'Track everything in your fridge easily and clearly.',
    'Bắt đầu ngay': 'Get started',
    'Chưa có tài khoản? ': "Don't have an account? ",
    'Cài đặt': 'Settings',
    'Thông tin cá nhân': 'Personal information',
    'Đổi mật khẩu': 'Change password',
    'Sở thích ăn uống': 'Dietary preferences',
    'Mức độ nấu ăn': 'Cooking level',
    'Hiện SP đã hết hạn': 'Show expired items',
    'Hiển thị nguyên liệu đã hết hạn trên trang chủ':
        'Show expired ingredients on the dashboard',
    'Gợi ý công thức hàng ngày': 'Daily recipe suggestions',
    'Hiển thị các công thức gợi ý bởi AI trên trang chủ':
        'Show AI recipe suggestions on the dashboard',
    'Ngôn ngữ': 'Language',
    'Trợ giúp & Phản hồi': 'Help & Feedback',
    'Về Bếp Trợ Lý': 'About Kitchen Assistant',
    'Đăng xuất': 'Sign out',
    'Hủy': 'Cancel',
    'Đăng xuất thành công': 'Signed out successfully',
    'Bạn đã đăng xuất hoàn toàn khỏi Google.':
        'You have fully signed out of Google.',
    'Chọn ngôn ngữ ưu tiên': 'Choose your preferred language',
    'Tuỳ chọn này sẽ được dùng cho trải nghiệm cá nhân hoá và các cập nhật giao diện sau này.':
        'This setting will be used for personalization and future UI translations.',
    'Đã lưu ngôn ngữ ưu tiên: English':
        'Saved preferred language: English',
    'Tiếng Việt': 'Vietnamese',
    'Ngôn ngữ mặc định của ứng dụng': 'Default app language',
    'Dùng cho cấu hình ưu tiên và hỗ trợ sau này':
        'Used for preference settings and future support',
    'Trợ lý bếp thông minh giúp quản lý tủ lạnh, gợi ý công thức và lập lịch bữa ăn.':
        'A smart kitchen assistant that helps manage your fridge, suggest recipes, and plan meals.',
    'Quên mật khẩu': 'Forgot password',
    'Nhập email đăng ký để mở yêu cầu hỗ trợ đặt lại mật khẩu.':
        'Enter your registered email to open a password reset support request.',
    'Email đăng ký': 'Registered email',
    'Tiếp tục': 'Continue',
    'Đã mở ứng dụng email để gửi yêu cầu đặt lại mật khẩu.':
        'Opened your email app to send the password reset request.',
    'Không mở được email. Đã sao chép địa chỉ hỗ trợ để bạn liên hệ thủ công.':
        'Could not open email. The support address has been copied so you can contact us manually.',
    'Đăng nhập thành công!': 'Signed in successfully!',
    'Đăng ký thành công!': 'Registered successfully!',
    'Hồ sơ của bạn': 'Your profile',
    'Người dùng': 'User',
    'Đã cập nhật thông tin hồ sơ': 'Profile updated successfully',
    'Lỗi khi cập nhật': 'Failed to update',
    'Đã cập nhật ảnh đại diện': 'Profile photo updated',
    'Lỗi cập nhật ảnh': 'Failed to update photo',
    'Cập nhật hồ sơ': 'Update profile',
    'Cài đặt ứng dụng': 'App settings',
    'Thông báo hết hạn': 'Expiry notifications',
    'Hiển thị nguyên liệu hết hạn và sắp hết hạn trong ứng dụng':
        'Show expired and soon-to-expire ingredients in the app',
    'Gợi ý món ăn': 'Recipe suggestions',
    'Bật hoặc tắt phần gợi ý công thức trong ứng dụng':
        'Turn recipe suggestions on or off in the app',
    'Hệ thống sẽ gợi ý món ăn dựa trên các thông tin này.':
        'The app will recommend dishes based on this information.',
    'Chế độ ăn': 'Diet type',
    'Dị ứng / Nguyên liệu tránh': 'Allergies / ingredients to avoid',
    'Ẩm thực yêu thích': 'Favorite cuisines',
    'Họ và tên': 'Full name',
    'Email': 'Email',
    'Số điện thoại': 'Phone number',
    'Món đã nấu': 'Cooked dishes',
    'Trong tủ': 'In fridge',
    'Sắp hết hạn': 'Expiring soon',
    'GỬI PHẢN HỒI CHO CHÚNG TÔI': 'SEND US FEEDBACK',
    'LIÊN HỆ HỖ TRỢ': 'SUPPORT CONTACT',
    'Vấn đề bạn gặp phải': 'Issue you encountered',
    'Chi tiết phản hồi': 'Feedback details',
    'Gửi phản hồi': 'Send feedback',
    'Đã mở ứng dụng email để bạn gửi phản hồi.':
        'Opened your email app so you can send feedback.',
    'Không mở được email. Đã sao chép địa chỉ hỗ trợ để bạn gửi thủ công.':
        'Could not open email. The support address has been copied for manual sending.',
    'Hotline': 'Hotline',
    'Email hỗ trợ': 'Support email',
    'Nhắn Zalo': 'Message on Zalo',
    'Đang mở trình gọi điện hỗ trợ.': 'Opening the support dialer.',
    'Không mở được trình gọi điện. Đã sao chép số hotline.':
        'Could not open the dialer. The hotline number has been copied.',
    'Đã mở ứng dụng email hỗ trợ.': 'Opened the support email app.',
    'Không mở được email. Đã sao chép địa chỉ hỗ trợ.':
        'Could not open email. The support address has been copied.',
    'Đã mở Zalo hỗ trợ.': 'Opened support on Zalo.',
    'Không mở được Zalo. Đã sao chép đường dẫn hỗ trợ.':
        'Could not open Zalo. The support link has been copied.',
    'Gợi ý hôm nay': "Today's suggestions",
    'Khám phá': 'Explore',
    'Xem công thức': 'View recipe',
    'Thống kê tủ lạnh': 'Fridge statistics',
    'Quét HD': 'Scan',
    'Thêm món': 'Add item',
    'Quản lý tủ': 'Manage fridge',
    'Tìm kiếm': 'Search',
    'Có thể nấu': 'Can cook',
    'Món ăn từ nguyên liệu có sẵn!':
        'Meals you can make with available ingredients!',
    'Đã tiết kiệm': 'Saved',
    'Tháng này bạn làm rất tốt !':
        "You're doing great this month!",
    'Tổng quan': 'Overview',
    'Tủ lạnh': 'Fridge',
    'Lịch ăn uống': 'Meal plan',
    'Đi chợ': 'Shopping',
    'Chưa có tủ lạnh nào': 'No fridge found',
    'Chọn tủ lạnh': 'Choose fridge',
    'Chọn tủ lạnh đích': 'Choose destination fridge',
    'Vui lòng điền đầy đủ thông tin': 'Please fill in all required information',
    'Không thể cập nhật trạng thái mua sắm. Vui lòng thử lại.':
        'Could not update shopping status. Please try again.',
    'Hoàn tác': 'Undo',
    'Xóa khỏi danh sách?': 'Remove from the list?',
    'Không thể xóa. Vui lòng thử lại.':
        'Could not delete. Please try again.',
    'Chưa có mục nào được chọn': 'No items selected',
    'Không thể chuyển mục nào vào tủ lạnh. Vui lòng thử lại.':
        'Could not move any items to the fridge. Please try again.',
    'Thêm mục mua sắm': 'Add shopping item',
    'Tên sản phẩm *': 'Product name *',
    'Ghi chú': 'Notes',
    'Đã thêm mục mua sắm': 'Shopping item added',
    'Không thể thêm mục mua sắm': 'Could not add shopping item',
    'Danh sách mua sắm': 'Shopping list',
    'Thêm mục': 'Add item',
    'Nấu món ăn': 'Cook dish',
    'Chưa có món ăn nào trong danh sách': 'No dishes in the list yet',
    'Chưa có mục nào cần mua thêm': 'No extra items to buy',
    'Nguyên liệu linh hoạt cho bữa ăn hàng ngày':
        'Flexible ingredients for everyday meals',
    'Gợi ý từ Bếp Trợ Lý': 'Suggestions from Kitchen Assistant',
    'Đã mua xong': 'Purchased',
    'Vào tủ lạnh': 'Move to fridge',
    'Dễ': 'Easy',
    'Khó': 'Hard',
    'Trung bình': 'Medium',
    'Nguyên liệu': 'Ingredient',
    'Hoạt động tủ lạnh': 'Fridge activity',
    'Thêm vào': 'Added',
    'Lấy ra': 'Taken out',
    'Loại bỏ': 'Discarded',
    'Nấu ăn': 'Cooking',
    'Khác': 'Other',
    'Đã hết hạn': 'Expired',
    'Hết hạn hôm nay': 'Expires today',
    'Dưới 15 phút': 'Under 15 minutes',
    'Cần mua thêm': 'Need to buy more',
    'Đổi mật khẩu thành công!': 'Password changed successfully!',
    'Tạo mật khẩu mới': 'Create a new password',
    'Mật khẩu mới phải khác với mật khẩu cũ.':
        'The new password must be different from the current password.',
    'Mật khẩu hiện tại': 'Current password',
    'Nhập mật khẩu hiện tại': 'Enter current password',
    'Vui lòng nhập mật khẩu hiện tại':
        'Please enter your current password',
    'Mật khẩu mới': 'New password',
    'Nhập mật khẩu mới': 'Enter new password',
    'Vui lòng nhập mật khẩu mới': 'Please enter a new password',
    'Mật khẩu phải có ít nhất 6 ký tự':
        'Password must be at least 6 characters',
    'Xác nhận mật khẩu mới': 'Confirm new password',
    'Nhập lại mật khẩu mới': 'Re-enter the new password',
    'Vui lòng xác nhận mật khẩu mới':
        'Please confirm the new password',
    'Mật khẩu xác nhận không khớp':
        'Confirmation password does not match',
    'Xác nhận thay đổi': 'Confirm changes',
    'Tất cả': 'All',
    'Nhật ký hoạt động': 'Activity log',
    'Không có hoạt động nào': 'No activity yet',
    'HÔM NAY': 'TODAY',
    'HÔM QUA': 'YESTERDAY',
    'TUẦN TRƯỚC': 'LAST WEEK',
    'CŨ HƠN': 'OLDER',
    'Đã tạo tủ lạnh mới thành công': 'Fridge created successfully',
    'Thêm tủ lạnh mới': 'Add a new fridge',
    'Thiết lập tủ lạnh của bạn': 'Set up your fridge',
    'Nhập thông tin chi tiết để bắt đầu quản lý thực phẩm hiệu quả hơn':
        'Enter the details to start managing food more efficiently.',
    'Tên tủ lạnh': 'Fridge name',
    'Ví dụ: Tủ lạnh nhà, văn phòng':
        'Example: Home fridge, office fridge',
    'Vui lòng nhập tên tủ': 'Please enter a fridge name',
    'Mô tả/ Vị trí': 'Description / location',
    'Ví dụ: Tầng 1, phòng bếp': 'Example: Floor 1, kitchen',
    'Tạo tủ lạnh': 'Create fridge',
    'Huỷ bỏ': 'Cancel',
    'Đã cập nhật thành công': 'Updated successfully',
    'Xác nhận xóa': 'Confirm deletion',
    'Bạn có chắc chắn muốn xóa tủ lạnh này không? Mọi dữ liệu liên quan sẽ bị mất.':
        'Are you sure you want to delete this fridge? All related data will be lost.',
    'Xóa': 'Delete',
    'Đã xóa tủ lạnh thành công': 'Fridge deleted successfully',
    'Chỉnh sửa': 'Edit',
    'Chỉnh sửa tin nhắn': 'Edit message',
    'Nội dung tin nhắn...': 'Message content...',
    'Lưu': 'Save',
    'Xóa tin nhắn?': 'Delete message?',
    'Bạn có chắc chắn muốn xóa tin nhắn này không?':
        'Are you sure you want to delete this message?',
    'Trò chuyện nhóm': 'Group chat',
    'Chưa có tin nhắn nào.\nHãy bắt đầu cuộc trò chuyện!':
        'No messages yet.\nStart the conversation!',
    'Đang có 1 người gõ...': '1 person is typing...',
    'Nhập tin nhắn...': 'Type a message...',
    'Rời khỏi tủ lạnh': 'Leave fridge',
    'Rời khỏi': 'Leave',
    'Đã rời khỏi tủ lạnh thành công':
        'Left the fridge successfully',
    'Tủ lạnh ảo': 'Virtual fridge',
    'Chọn tủ lạnh để xem và quản lý nguyên liệu':
        'Choose a fridge to view and manage ingredients',
    'DANH SÁCH TỦ LẠNH': 'FRIDGE LIST',
    'Nhấn "Thêm tủ lạnh mới" để bắt đầu quản lý thực phẩm':
        'Tap "Add a new fridge" to start managing food',
    'THÀNH VIÊN CHUNG': 'SHARED MEMBERS',
    'Quản lý': 'Manage',
    'Chưa có thành viên nào': 'No members yet',
    'Đang chọn': 'Selected',
    'Tạm ngưng': 'Paused',
    'Đang hoạt động': 'Active',
    'Thêm nguyên liệu': 'Add ingredient',
    'Mời thành viên mới': 'Invite new member',
    'Nhập email người dùng': 'Enter user email',
    'Mời': 'Invite',
    'Xác nhận': 'Confirm',
    'Bạn có chắc muốn xóa thành viên này khỏi tủ lạnh?':
        'Are you sure you want to remove this member from the fridge?',
    'Chủ tủ': 'Owner',
    'Chờ duyệt': 'Pending',
    'Thành viên': 'Member',
    'Thêm thành viên': 'Add member',
    'ĐANG QUẢN LÝ': 'MANAGING',
    'Email hoặc SĐT': 'Email or phone number',
    'Ẩn danh': 'Anonymous',
    'Không có email': 'No email',
    'Gửi lời mời': 'Send invitation',
    'Chào mừng bạn đến với Bếp Trợ Lý':
        'Welcome to Kitchen Assistant',
    'Mặc định': 'Default',
    'Hãy chọn ít nhất 1 nguyên liệu để gợi ý.':
        'Please choose at least 1 ingredient for suggestions.',
    'Tạm thời chưa có món phù hợp, vui lòng thử lại sau.':
        'No suitable dishes are available right now. Please try again later.',
    'Bữa sáng': 'Breakfast',
    'Bữa trưa': 'Lunch',
    'Bữa tối': 'Dinner',
    'Chủ nhật': 'Sunday',
    'Thứ hai': 'Monday',
    'Thứ ba': 'Tuesday',
    'Thứ tư': 'Wednesday',
    'Thứ năm': 'Thursday',
    'Thứ sáu': 'Friday',
    'Thứ bảy': 'Saturday',
    'Gợi ý luôn': 'Quick suggest',
    'Theo nguyên liệu': 'By ingredients',
    'Chọn nguyên liệu bạn đang có': 'Choose the ingredients you have',
    'Bạn chưa có nguyên liệu trong tủ. Vẫn có thể dùng nút Gợi ý luôn.':
        'You do not have ingredients in the fridge yet. You can still use Quick suggest.',
    'Kết quả gợi ý ngay': 'Instant suggestion results',
    'Chưa có gợi ý khám phá lúc này.':
        'No discovery suggestions at the moment.',
    'Kết quả theo nguyên liệu': 'Ingredient-based results',
    'Chọn nguyên liệu rồi nhấn Theo nguyên liệu để xem món phù hợp.':
        'Choose ingredients and tap By ingredients to see matching dishes.',
    'Gợi ý cho bạn': 'Suggestions for you',
    'Xem thêm': 'See more',
    'Giữ và kéo món vào khung bữa ăn để lên lịch nhanh.':
        'Hold and drag a dish into a meal slot to plan quickly.',
    'Chưa có dữ liệu gợi ý.': 'No suggestion data yet.',
    'Kéo thả món ăn vào đây': 'Drag a dish here',
    'Chưa đọc': 'Unread',
    'Hạn sử dụng': 'Expiry date',
    'Gợi ý': 'Suggestions',
    'Thông báo': 'Notifications',
    'Chưa có thông báo nào': 'No notifications yet',
    'Không có thông báo phù hợp': 'No matching notifications',
    'Đã hiển thị tất cả thông báo': 'All notifications are displayed',
    'Thêm vào giỏ': 'Add to cart',
    'Từ chối': 'Decline',
    'Chấp nhận': 'Accept',
    'Vừa xong': 'Just now',
    'Rau củ': 'Vegetables',
    'Thịt cá': 'Meat & seafood',
    'Sữa': 'Dairy',
    'Trái cây': 'Fruits',
    'Xóa sản phẩm': 'Delete product',
    'Không thể xóa sản phẩm. Vui lòng thử lại.':
        'Could not delete the product. Please try again.',
    'An toàn': 'Safe',
    'Không rõ hạn': 'Unknown expiry',
    'Hôm nay': 'Today',
    'Còn 1 ngày': '1 day left',
    'Kho thực phẩm': 'Food storage',
    'Tủ lạnh này đang tạm ngưng. Bạn không thể thực hiện thay đổi.':
        'This fridge is paused. You cannot make changes.',
    'Tìm kiếm nguyên liệu': 'Search ingredients',
    'Hiển thị sản phẩm hết hạn': 'Show expired items',
    'Tủ lạnh đang trống': 'The fridge is empty',
    'Nhấn nút + để thêm nguyên liệu mới':
        'Tap + to add a new ingredient',
    'Khẩn cấp': 'Urgent',
    'HSD: Không rõ': 'EXP: Unknown',
    'HSD: Quá hạn': 'EXP: Overdue',
    'HSD : Hôm nay': 'EXP: Today',
    'HSD : Ngày mai': 'EXP: Tomorrow',
    'Không có nguyên liệu cần dùng ngay':
        'No ingredients need immediate use',
    'Không có nguyên liệu phù hợp': 'No matching ingredients',
    'Hiện tại không có nguyên liệu nào cần xử lý gấp.':
        'There are no ingredients that need urgent attention right now.',
    'Hành động ngay!': 'Take action now!',
    'Gam': 'Gram',
    'Lít': 'Liter',
    'Cái': 'Piece',
    'Quả': 'Fruit',
    'Bó': 'Bunch',
    'Hộp': 'Box',
    'Gói': 'Pack',
    'Chai': 'Bottle',
    'Lon': 'Can',
    'Bịch': 'Bag',
    'Vui lòng chọn tủ lạnh để thêm':
        'Please choose a fridge first',
    'Vui lòng nhập đầy đủ tên nguyên liệu':
        'Please enter the full ingredient name',
    'Vui lòng nhập số lượng hợp lệ lớn hơn 0':
        'Please enter a valid quantity greater than 0',
    'Vui lòng chọn đơn vị đo lường (Gam, Kg, Hộp, Gói...)':
        'Please choose a measurement unit (Gram, Kg, Box, Pack...)',
    'Vui lòng nhập ngày mua': 'Please enter the purchase date',
    'Vui lòng chọn Hạn sử dụng của nguyên liệu':
        'Please choose the ingredient expiry date',
    'Lỗi thêm sản phẩm. Vui lòng thử lại.':
        'Failed to add product. Please try again.',
    'Thêm Nguyên Liệu': 'Add Ingredient',
    'HOẶC NHẬP THỦ CÔNG': 'OR ENTER MANUALLY',
    'Tên Nguyên Liệu': 'Ingredient Name',
    'Số Lượng': 'Quantity',
    'Đơn Vị': 'Unit',
    'Ngày Mua': 'Purchase Date',
    'Hạn Sử Dụng': 'Expiry Date',
    'Tìm kiếm hoặc quét mã vạch': 'Search or scan barcode',
    'Tính năng chụp ảnh đang phát triển':
        'Camera capture is under development',
    'Chụp ảnh nguyên liệu': 'Capture ingredient photo',
    'Vd: Thịt bò, Cà chua': 'E.g. Beef, Tomato',
    'Thêm vào Tủ Lạnh': 'Add to Fridge',
    'Trung cấp': 'Intermediate',
    'Người mới bắt đầu': 'Beginner',
    'Món đơn giản, ít bước thực hiện và sử dụng nguyên liệu phổ biến.':
        'Simple dishes with few steps and common ingredients.',
    'Đa dạng thực đơn, kỹ thuật nấu nướng cơ bản và cân bằng dinh dưỡng.':
        'A varied menu with basic cooking techniques and balanced nutrition.',
    'Siêu đầu bếp': 'Master chef',
    'Công thức phức tạp, nhiều bước yêu cầu kỹ năng cao và trang trí tinh tế.':
        'Complex recipes with many steps, advanced skills, and refined presentation.',
    'Đã cập nhật mức độ nấu ăn': 'Cooking level updated',
    'Chọn trình độ của bạn để Bếp Trợ Lý gợi ý những công thức phù hợp nhất, giúp bạn tận dụng nguyên liệu hiệu quả.':
        'Choose your level so Kitchen Assistant can suggest the most suitable recipes and help you use ingredients efficiently.',
    'Bình thường': 'Normal',
    'Đậu phộng': 'Peanuts',
    'Sữa & chế phẩm': 'Dairy products',
    'Hải sản': 'Seafood',
    'Hàn Quốc': 'Korean',
    'Nhật Bản': 'Japanese',
    'Trung Quốc': 'Chinese',
    'Món Âu': 'Western',
    'Đã cập nhật sở thích ăn uống!': 'Dietary preferences updated!',
    'Chọn các chế độ ăn uống và nguyên liệu bạn muốn tránh. Bếp trợ lý sẽ gợi ý công thức phù hợp nhất cho bạn.':
        'Choose dietary styles and ingredients you want to avoid. Kitchen Assistant will suggest the most suitable recipes for you.',
    'CHẾ ĐỘ ĂN': 'DIET TYPES',
    'DỊ ỨNG VÀ NGUYÊN LIỆU CẦN TRÁNH':
        'ALLERGIES AND INGREDIENTS TO AVOID',
    'ẨM THỰ YÊU THÍCH': 'FAVORITE CUISINES',
    'Bạn có chắc chắn muốn đăng xuất không?':
        'Are you sure you want to sign out?',
    'Thiết lập này sẽ đồng bộ giữa hồ sơ và màn cài đặt của ứng dụng.':
        'This setting will sync between the profile and app settings screens.',
    'Chuẩn bị': 'Prep',
    'Nấu': 'Cook',
    'Khẩu phần': 'Servings',
    'Độ khó': 'Difficulty',
    'Thêm vào danh sách mua': 'Add to shopping list',
    'Bắt đầu nấu': 'Start cooking',
    'Chuẩn bị đủ nguyên liệu để nấu':
        'Prepare enough ingredients to cook',
    'Chưa có danh sách nguyên liệu.': 'No ingredient list yet.',
    'Cần mua': 'Need to buy',
    'Hiện chưa có thêm món mới để gợi ý.':
        'There are no more new dishes to suggest right now.',
    'Công thức cho bạn': 'Recipes for you',
    'Theo tủ lạnh': 'From fridge',
    'Theo vùng miền': 'By region',
    'Tìm kiếm công thức...': 'Search recipes...',
    'Chưa có công thức phù hợp với bộ lọc hiện tại.':
        'No recipes match the current filters.',
    'Gợi ý mới': 'New suggestions',
    'Dùng ngay': 'Use now',
    'Ảnh minh họa': 'Illustration',
    'Thiết bị không hỗ trợ đèn flash.':
        'This device does not support flash.',
    'Chụp ảnh thất bại, vui lòng thử lại.':
        'Photo capture failed, please try again.',
    'Không nhận diện được nguyên liệu rõ ràng từ ảnh.':
        'Could not clearly recognize ingredients from the image.',
    'Quét chữ thất bại, vui lòng thử lại.':
        'Text scan failed, please try again.',
    'Đã nhận diện mã vạch': 'Barcode recognized',
    'Tên sản phẩm': 'Product name',
    'Nhập tên để lưu vào tủ lạnh':
        'Enter a name to save to the fridge',
    'Số lượng': 'Quantity',
    'Đơn vị': 'Unit',
    'Bỏ qua': 'Skip',
    'Vui lòng nhập tên sản phẩm': 'Please enter a product name',
    'Số lượng phải lớn hơn 0': 'Quantity must be greater than 0',
    'Lưu vào tủ lạnh': 'Save to fridge',
    'Nguyên liệu nhận diện được': 'Recognized ingredients',
    'Chọn món bạn muốn thêm vào tủ lạnh':
        'Choose the items you want to add to the fridge',
    'Thêm từ quét camera': 'Add from camera scan',
    'Không thêm được nguyên liệu nào.':
        'Could not add any ingredients.',
    'Nhập nguyên liệu': 'Enter ingredient',
    'Tên nguyên liệu': 'Ingredient name',
    'Ví dụ: Cà chua': 'Example: Tomato',
    'Thêm thủ công từ màn quét': 'Add manually from scan screen',
    'Thêm nguyên liệu thất bại, vui lòng thử lại.':
        'Failed to add ingredient, please try again.',
    'Quét nguyên liệu': 'Scan ingredients',
    'Nhập thủ công': 'Manual entry',
    'Đèn Flash': 'Flash',
    'Xem tất cả': 'View all',
    'Không mở được camera': 'Could not open the camera',
    'Đang nhận diện nguyên liệu...': 'Recognizing ingredients...',
    'Căn chỉnh mã vạch hoặc hóa đơn vào khung':
        'Align the barcode or receipt inside the frame',
    'Loại vấn đề bạn gặp phải......': 'Describe the issue type......',
    'Hãy mô tả vấn đề hoặc ý kiến của bạn....':
        'Describe your issue or feedback....',
    '[Hỗ trợ] Bếp Trợ Lý': '[Support] Kitchen Assistant',
    'Xin chào, tôi cần được hỗ trợ thêm về ứng dụng.':
        'Hello, I need more support with the app.',
    'Xin chào, tôi cần được hỗ trợ nhanh về ứng dụng Bếp Trợ Lý.':
        'Hello, I need quick support with the Kitchen Assistant app.',
    'TÀI KHOẢN': 'ACCOUNT',
    'SỞ THÍCH & TÙY CHỈNH': 'PREFERENCES & CUSTOMIZATION',
    'THÔNG BÁO': 'NOTIFICATIONS',
    'ỨNG DỤNG': 'APP',
    'Phần ăn': 'Servings',
    'Hẹn giờ nấu': 'Cooking timer',
    'Tạm dừng': 'Pause',
    'Bắt đầu': 'Start',
    'Đặt lại': 'Reset',
    'Nguyên liệu cần chuẩn bị': 'Ingredients to prepare',
    'Bí quyết từ Bếp Trợ Lý': 'Tips from Kitchen Assistant',
    'Các bước thực hiện': 'Steps',
    'Thời gian nấu chưa kết thúc, hãy chờ đếm ngược về 00:00.':
        'The cooking time has not ended yet, please wait for the countdown to reach 00:00.',
    'Hãy hoàn thành tất cả các bước nhé!':
        'Please complete all steps!',
    'Hoàn thành món ăn ✨': 'Finish dish ✨',
    'Đang thực hiện...': 'In progress...',
    'Món ăn đã sẵn sàng': 'Dish is ready',
    'Đã hiểu': 'Got it',
    'Mẹo chế biến': 'Cooking tip',
    'Canh chua cá lóc': 'Snakehead sour soup',
    'Phở bò tái nạm': 'Rare beef and brisket pho',
    'Bún chả Hà Nội': 'Hanoi grilled pork vermicelli',
    'Thịt kho tàu': 'Braised pork and eggs',
    'Gỏi cuốn tôm thịt': 'Fresh spring rolls with shrimp and pork',
    'Bánh mì thịt nướng': 'Grilled pork banh mi',
    'Cơm chiên dương châu': 'Yangzhou fried rice',
    'Mì xào bò rau cải': 'Stir-fried noodles with beef and greens',
    'Bún bò Huế': 'Bun Bo Hue',
    'Cánh gà chiên nước mắm': 'Fish-sauce fried chicken wings',
    'Lẩu thái hải sản': 'Thai seafood hotpot',
    'Bò né chảo gang': 'Sizzling beef on cast-iron skillet',
    'Miến xào cua biển': 'Stir-fried glass noodles with crab',
    'Salad ức gà sốt mè rang':
        'Chicken breast salad with sesame dressing',
    'Bánh xèo miền Tây': 'Mekong crispy pancake',
    'Bún riêu cua': 'Crab tomato vermicelli soup',
    'Cá kho tộ': 'Braised fish in clay pot',
    'Bò hầm rau củ': 'Beef stew with vegetables',
    'Mì quảng gà': 'Chicken Mi Quang',
    'Bánh canh chả cá': 'Fish cake thick noodle soup',
    'Cháo ếch Singapore': 'Singapore frog porridge',
    'Súp bí đỏ kem tươi': 'Creamy pumpkin soup',
    'Đậu hũ hấp nấm': 'Steamed tofu with mushrooms',
    'Canh bí đỏ rau củ': 'Pumpkin vegetable soup',
    'Bún chay nấm rau': 'Vegetarian noodle soup with mushrooms and greens',
    'Miến xào rau củ chay':
        'Vegetarian stir-fried glass noodles with vegetables',
    'Ức gà áp chảo salad': 'Pan-seared chicken breast salad',
    'Canh nấm rau cải': 'Mushroom and greens soup',
    'Tôm hấp bí ngòi': 'Steamed shrimp with zucchini',
    'Salad ức gà dưa leo': 'Chicken breast cucumber salad',
    'Cơm gạo lứt bò xào rau':
        'Brown rice with beef and stir-fried vegetables',
    'Cá hấp rau củ': 'Steamed fish with vegetables',
    'Yến mạch trái cây sữa chua': 'Oats with fruit and yogurt',
    'Gà áp chảo khoai lang': 'Pan-seared chicken with sweet potato',
    'Mì xào trứng': 'Stir-fried noodles with egg',
    'Cơm chiên rau củ trứng': 'Fried rice with vegetables and egg',
    'Cà tím áp chảo sốt mắm': 'Pan-seared eggplant in fish sauce',
    'Trứng chiên hành': 'Omelet with scallions',
    'Canh cải thịt bằm': 'Greens soup with minced pork',
    'Mì nước trứng hành': 'Egg noodle soup with shallots',
    'Gà xào sả ớt': 'Stir-fried chicken with lemongrass and chili',
    'Đậu hũ sốt cà chua': 'Tofu in tomato sauce',
    'Bò xào bông cải': 'Stir-fried beef with broccoli',
    'Cá sốt cà chua': 'Fish in tomato sauce',
    'Ăn chay': 'Vegetarian',
    'Giảm cân': 'Weight loss',
    'Eat Clean': 'Eat Clean',
    'Món chay Việt Nam': 'Vietnamese vegetarian dishes',
    'Món Việt ít dầu mỡ': 'Low-oil Vietnamese dishes',
    'Món Việt Eat Clean': 'Vietnamese Eat Clean dishes',
    'Miền Bắc': 'Northern region',
    'Miền Trung': 'Central region',
    'Miền Nam': 'Southern region',
    'Ẩm thực miền Bắc Việt Nam': 'Northern Vietnamese cuisine',
    'Ẩm thực miền Trung Việt Nam': 'Central Vietnamese cuisine',
    'Ẩm thực miền Nam Việt Nam': 'Southern Vietnamese cuisine',
    'Việt Nam': 'Vietnam',
    'English': 'English',
  };

  static final List<_RegexRule> _englishRules = [
    _RegexRule(
      RegExp(r'^Phiên bản (.+)$'),
      (match) => 'Version ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Thành viên từ (.+)$'),
      (match) => 'Member since ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Xin chào, (.+) 👋$'),
      (match) => 'Hello, ${match.group(1)} 👋',
    ),
    _RegexRule(
      RegExp(r'^([A-Za-zÀ-ỹà-ỹ ]+), (\d{1,2}) tháng (\d{1,2})$'),
      (match) =>
          '${_englishWeekday(match.group(1)!.trim())}, ${_englishMonth(match.group(3)!)} ${match.group(2)}',
    ),
    _RegexRule(
      RegExp(r'^Hết hạn: (\d+) ngày$'),
      (match) => 'Expires in ${match.group(1)} days',
    ),
    _RegexRule(
      RegExp(r'^Hết hạn : (\d+) ngày$'),
      (match) => 'Expires in ${match.group(1)} days',
    ),
    _RegexRule(
      RegExp(r'^Hết hạn: hôm nay$'),
      (_) => 'Expires today',
    ),
    _RegexRule(
      RegExp(r'^Hết hạn: mai$'),
      (_) => 'Expires tomorrow',
    ),
    _RegexRule(
      RegExp(r'^Hết hạn : mai$'),
      (_) => 'Expires tomorrow',
    ),
    _RegexRule(
      RegExp(r'^Đã thêm (.+)$'),
      (match) => 'Added ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Đã lấy (.+)$'),
      (match) => 'Took ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Đã bỏ (.+)$'),
      (match) => 'Discarded ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Đã nấu (.+)$'),
      (match) => 'Cooked ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^(\d+) phút$'),
      (match) => '${match.group(1)} min',
    ),
    _RegexRule(
      RegExp(r'^(\d+) giờ (\d+) phút$'),
      (match) => '${match.group(1)} h ${match.group(2)} min',
    ),
    _RegexRule(
      RegExp(r'^(\d+) giờ$'),
      (match) => '${match.group(1)} h',
    ),
    _RegexRule(
      RegExp(r'^Dùng (\d+) nguyên liệu sắp hết$'),
      (match) => 'Uses ${match.group(1)} ingredients expiring soon',
    ),
    _RegexRule(
      RegExp(r'^(\d+) mục$'),
      (match) => '${match.group(1)} items',
    ),
    _RegexRule(
      RegExp(r'^(\d+) đã mua$'),
      (match) => '${match.group(1)} purchased',
    ),
    _RegexRule(
      RegExp(r'^(\d+) còn lại$'),
      (match) => '${match.group(1)} remaining',
    ),
    _RegexRule(
      RegExp(r'^(\d+) nguyên liệu cần mua • (\d+) đã mua$'),
      (match) =>
          '${match.group(1)} ingredients to buy • ${match.group(2)} purchased',
    ),
    _RegexRule(
      RegExp(r'^(\d+) phần$'),
      (match) => '${match.group(1)} servings',
    ),
    _RegexRule(
      RegExp(r'^(\d+) phần ăn$'),
      (match) => '${match.group(1)} servings',
    ),
    _RegexRule(
      RegExp(r'^(\d+) người$'),
      (match) => '${match.group(1)} people',
    ),
    _RegexRule(
      RegExp(r'^(\d+) nguyên liệu cần dùng ngay$'),
      (match) => '${match.group(1)} ingredients need immediate use',
    ),
    _RegexRule(
      RegExp(r'^(\d+) nguyên liệu$'),
      (match) => '${match.group(1)} ingredients',
    ),
    _RegexRule(
      RegExp(r'^(\d+) thành viên$'),
      (match) => '${match.group(1)} members',
    ),
    _RegexRule(
      RegExp(r'^(\d+) sắp hết hạn$'),
      (match) => '${match.group(1)} expiring soon',
    ),
    _RegexRule(
      RegExp(r'^Đã lưu ngôn ngữ ưu tiên: (.+)$'),
      (match) => 'Saved preferred language: ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Gợi ý cho (.+)$'),
      (match) => 'Suggestions for ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Phản hồi sẽ được gửi kèm email tài khoản: (.+)$'),
      (match) =>
          'Feedback will be sent with the account email: ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Đã thêm "(.+)" vào tủ lạnh!$'),
      (match) => 'Added "${match.group(1)}" to the fridge!',
    ),
    _RegexRule(
      RegExp(r'^Đã thêm "(.+)" \((.+)\) vào tủ lạnh\.$'),
      (match) => 'Added "${match.group(1)}" (${match.group(2)}) to the fridge.',
    ),
    _RegexRule(
      RegExp(r'^Đã thêm "(.+)" vào (.+)\.$'),
      (match) => 'Added "${match.group(1)}" to ${match.group(2)}.',
    ),
    _RegexRule(
      RegExp(r'^Đã tự thêm "(.+)" vào tủ lạnh\.$'),
      (match) => 'Automatically added "${match.group(1)}" to the fridge.',
    ),
    _RegexRule(
      RegExp(r'^Đã thêm (\d+) nguyên liệu vào tủ lạnh\.$'),
      (match) => 'Added ${match.group(1)} ingredients to the fridge.',
    ),
    _RegexRule(
      RegExp(
        r'^Đã thêm (\d+) món\. Còn (\d+) món chưa thêm được, vui lòng thử lại\.$',
      ),
      (match) =>
          'Added ${match.group(1)} dishes. ${match.group(2)} dishes could not be added yet, please try again.',
    ),
    _RegexRule(
      RegExp(
        r'^Bạn còn thiếu (\d+) nguyên liệu\. Hãy mua bổ sung trước khi nấu\.$',
      ),
      (match) =>
          'You are missing ${match.group(1)} ingredients. Please buy them before cooking.',
    ),
    _RegexRule(
      RegExp(r'^Bạn còn (\d+) nguyên liệu chưa tích xác nhận chuẩn bị\.$'),
      (match) =>
          'You still have ${match.group(1)} ingredients that are not marked as prepared.',
    ),
    _RegexRule(
      RegExp(r'^Sản phẩm mã (.+)$'),
      (match) => 'Product code ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Gợi ý: (.+)$'),
      (match) => 'Suggestion: ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Thêm từ mã vạch: (.+)$'),
      (match) => 'Add from barcode: ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^Thêm tự động từ mã vạch: (.+)$'),
      (match) => 'Auto-add from barcode: ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^HSD: (.+)$'),
      (match) => 'EXP: ${match.group(1)}',
    ),
    _RegexRule(
      RegExp(r'^HSD : (.+)$'),
      (match) => 'EXP: ${match.group(1)}',
    ),
  ];

  static final List<_TextReplacement> _sortedEnglishFragments =
      [..._englishFragments]
        ..sort((a, b) => b.source.length.compareTo(a.source.length));

  static const List<_TextReplacement> _englishFragments = [
    _TextReplacement(
      'dựa trên thực đơn tuần này, bạn có thể cần thêm',
      'Based on this week\'s menu, you may need to add',
    ),
    _TextReplacement(
      'tủ lạnh đang cần sự chú ý của bạn',
      'your fridge needs attention',
    ),
    _TextReplacement(
      'phù hợp bữa cơm hằng ngày',
      'that fit everyday meals',
    ),
    _TextReplacement(
      'nguyên liệu trong tủ lạnh của bạn',
      'ingredients in your fridge',
    ),
    _TextReplacement('thanh nhẹ', 'light and gentle'),
    _TextReplacement('nhanh gọn', 'quick and easy'),
    _TextReplacement('đậm đà', 'rich and savory'),
    _TextReplacement('dễ làm', 'easy to make'),
    _TextReplacement('giàu đạm', 'high in protein'),
    _TextReplacement('ít dầu mỡ', 'low in oil'),
    _TextReplacement('ít dầu', 'low oil'),
    _TextReplacement('ít calo', 'low calorie'),
    _TextReplacement('giàu chất xơ', 'high in fiber'),
    _TextReplacement('hợp bữa tối', 'great for dinner'),
    _TextReplacement('hợp bữa sáng', 'great for breakfast'),
    _TextReplacement('hợp bữa trưa', 'great for lunch'),
    _TextReplacement('hợp cơm', 'goes well with rice'),
    _TextReplacement('bữa sáng', 'breakfast'),
    _TextReplacement('bữa trưa', 'lunch'),
    _TextReplacement('bữa tối', 'dinner'),
    _TextReplacement('bữa ăn', 'meal'),
    _TextReplacement('món chay', 'vegetarian dish'),
    _TextReplacement('món eat clean', 'Eat Clean dish'),
    _TextReplacement('món quen thuộc', 'a familiar dish'),
    _TextReplacement('món dân dã', 'a rustic dish'),
    _TextReplacement('món cơ bản', 'a basic dish'),
    _TextReplacement('món xào', 'stir-fried dish'),
    _TextReplacement('món canh', 'soup dish'),
    _TextReplacement('món ăn', 'dish'),
    _TextReplacement('nước dùng', 'broth'),
    _TextReplacement('nước tương', 'soy sauce'),
    _TextReplacement('nước mắm', 'fish sauce'),
    _TextReplacement('nước dừa', 'coconut water'),
    _TextReplacement('nước chấm', 'dipping sauce'),
    _TextReplacement('dầu oliu', 'olive oil'),
    _TextReplacement('dầu ăn', 'cooking oil'),
    _TextReplacement('đậu hũ', 'tofu'),
    _TextReplacement('hành boa rô', 'leek'),
    _TextReplacement('hành tím', 'shallot'),
    _TextReplacement('hành lá', 'scallion'),
    _TextReplacement('rau xà lách', 'lettuce greens'),
    _TextReplacement('rau ngót', 'sweet leaf greens'),
    _TextReplacement('rau cải', 'greens'),
    _TextReplacement('rau củ', 'vegetables'),
    _TextReplacement('bông cải', 'broccoli'),
    _TextReplacement('bắp cải', 'cabbage'),
    _TextReplacement('bí ngòi', 'zucchini'),
    _TextReplacement('bí đỏ', 'pumpkin'),
    _TextReplacement('khoai lang', 'sweet potato'),
    _TextReplacement('cà rốt', 'carrot'),
    _TextReplacement('cà chua', 'tomato'),
    _TextReplacement('cà tím', 'eggplant'),
    _TextReplacement('dưa leo', 'cucumber'),
    _TextReplacement('đậu que', 'green beans'),
    _TextReplacement('gạo lứt', 'brown rice'),
    _TextReplacement('yến mạch', 'oats'),
    _TextReplacement('sữa chua', 'yogurt'),
    _TextReplacement('thịt bằm', 'minced pork'),
    _TextReplacement('thịt bò', 'beef'),
    _TextReplacement('thịt gà', 'chicken'),
    _TextReplacement('thịt ba chỉ', 'pork belly'),
    _TextReplacement('ức gà', 'chicken breast'),
    _TextReplacement('cá hồi', 'salmon'),
    _TextReplacement('cá ngừ', 'tuna'),
    _TextReplacement('cá lóc', 'snakehead fish'),
    _TextReplacement('cá rô', 'climbing perch'),
    _TextReplacement('cá', 'fish'),
    _TextReplacement('tôm', 'shrimp'),
    _TextReplacement('mực', 'squid'),
    _TextReplacement('trứng vịt', 'duck eggs'),
    _TextReplacement('trứng gà', 'chicken eggs'),
    _TextReplacement('trứng', 'egg'),
    _TextReplacement('bún', 'rice noodles'),
    _TextReplacement('miến', 'glass noodles'),
    _TextReplacement('mì quảng', 'Mi Quang'),
    _TextReplacement('mì tôm', 'instant noodles'),
    _TextReplacement('mì', 'noodles'),
    _TextReplacement('gừng', 'ginger'),
    _TextReplacement('tỏi', 'garlic'),
    _TextReplacement('sả', 'lemongrass'),
    _TextReplacement('ớt chuông', 'bell pepper'),
    _TextReplacement('ớt', 'chili'),
    _TextReplacement('tiêu', 'pepper'),
    _TextReplacement('đường', 'sugar'),
    _TextReplacement('xà lách', 'lettuce'),
    _TextReplacement('chuối', 'banana'),
    _TextReplacement('nấm', 'mushrooms'),
    _TextReplacement('gà', 'chicken'),
    _TextReplacement('bò', 'beef'),
    _TextReplacement('heo', 'pork'),
    _TextReplacement('cơm nguội', 'leftover rice'),
    _TextReplacement('cơm', 'rice'),
    _TextReplacement('hải sản', 'seafood'),
    _TextReplacement('rau', 'vegetables'),
    _TextReplacement('xào', 'stir-fried'),
    _TextReplacement('chiên', 'fried'),
    _TextReplacement('hấp', 'steamed'),
    _TextReplacement('kho', 'braised'),
    _TextReplacement('luộc', 'boiled'),
    _TextReplacement('nướng', 'grilled'),
    _TextReplacement('salad', 'salad'),
    _TextReplacement('canh', 'soup'),
    _TextReplacement('sốt', 'sauce'),
    _TextReplacement('rất dễ ăn', 'very easy to enjoy'),
    _TextReplacement('ngon cơm', 'great with rice'),
    _TextReplacement('ấm bụng', 'comforting'),
    _TextReplacement('mềm thơm', 'soft and fragrant'),
    _TextReplacement('đậm vị', 'flavorful'),
    _TextReplacement('nấu nhanh', 'quick to cook'),
    _TextReplacement('rất hợp', 'very suitable'),
    _TextReplacement('đủ chất', 'well-balanced'),
    _TextReplacement('no lâu', 'keeps you full longer'),
    _TextReplacement('thơm', 'fragrant'),
    _TextReplacement('nhẹ bụng', 'light on the stomach'),
    _TextReplacement('phù hợp', 'suitable'),
    _TextReplacement('Sơ chế', 'Prep'),
    _TextReplacement('Cắt', 'Cut'),
    _TextReplacement('Rửa sạch', 'Wash well'),
    _TextReplacement('Xếp', 'Arrange'),
    _TextReplacement('Hấp chín', 'Steam until cooked'),
    _TextReplacement('Thêm', 'Add'),
    _TextReplacement('Nấu', 'Cook'),
    _TextReplacement('Trụng', 'Blanch'),
    _TextReplacement('Ngâm', 'Soak'),
    _TextReplacement('Xào', 'Stir-fry'),
    _TextReplacement('Cho', 'Add'),
    _TextReplacement('Ướp', 'Marinate'),
    _TextReplacement('Áp chảo', 'Pan-sear'),
    _TextReplacement('Ăn cùng', 'Serve with'),
    _TextReplacement('Luộc', 'Boil'),
    _TextReplacement('Trộn', 'Mix'),
    _TextReplacement('Dùng', 'Use'),
    _TextReplacement('Có thể', 'You can'),
    _TextReplacement('Chiên sơ', 'Lightly fry'),
    _TextReplacement('Rắc', 'Sprinkle'),
    _TextReplacement('Đun sôi', 'Bring to a boil'),
    _TextReplacement('Thưởng thức', 'Enjoy'),
    _TextReplacement('Nêm', 'Season'),
    _TextReplacement('vừa ăn', 'to taste'),
    _TextReplacement('rồi', 'then'),
    _TextReplacement('trước khi', 'before'),
    _TextReplacement('đến khi', 'until'),
    _TextReplacement('dùng ngay', 'serve immediately'),
    _TextReplacement('thưởng thức nóng', 'enjoy hot'),
    _TextReplacement('trong ngày bận', 'on busy days'),
    _TextReplacement('gợi ý', 'suggestion'),
    _TextReplacement('nguyên liệu', 'ingredients'),
    _TextReplacement('thành viên', 'members'),
    _TextReplacement('sắp hết hạn', 'expiring soon'),
    _TextReplacement('hết hạn', 'expired'),
    _TextReplacement('miền bắc', 'northern region'),
    _TextReplacement('miền trung', 'central region'),
    _TextReplacement('miền nam', 'southern region'),
  ];
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((item) => item.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

class _RegexRule {
  const _RegexRule(this.pattern, this.replace);

  final RegExp pattern;
  final String Function(Match match) replace;
}

class _TextReplacement {
  const _TextReplacement(this.source, this.target);

  final String source;
  final String target;
}

extension AppLocalizationContext on BuildContext {
  String tr(String value) => AppLocalizations.of(this).text(value);
}
