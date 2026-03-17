import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme/app_colors.dart';
import '../../models/shopping_list_item.dart';
import '../../services/shopping_service.dart';
import 'dish_detail_screen.dart';
import 'cooking_detail_screen.dart';

/// Màn hình Danh sách mua sắm (tab Đi chợ)
class ShoppingListScreen extends StatefulWidget {
  final ValueChanged<int>? onGoToFridge;

  const ShoppingListScreen({super.key, this.onGoToFridge});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  int _selectedTabIndex = 0; // 0: Tất cả, 1: Món ăn, 2: Nấu ăn
  List<ShoppingListSection> _sections = [];
  List<ShoppingListItem> _allItems = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _suggestionText =
      'Dựa trên thực đơn tuần này, bạn có thể cần thêm Hành tím và Nước mắm';
  static const bool _enableMockFallback = false;
  bool _isTransferringToFridge = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final sections = await ShoppingService.getCurrentSections();
    if (sections.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _allItems = _sections.expand((s) => s.items).toList();
        _isLoading = false;
      });
      return;
    }

    if (_enableMockFallback && kDebugMode) {
      _loadMockData();
    } else {
      _sections = [];
      _allItems = [];
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _loadMockData() {
    _sections = [
      ShoppingListSection(
        title: 'Canh chua cá lóc',
        recipeInfo: RecipeInfo(
          recipeId: 'r1',
          servings: 4,
          cookTime: 25,
          difficulty: 'medium',
          description:
              'Nồi canh chua cá lóc nóng hổi đặc trưng miền Nam với vị chua thanh của me, ngọt dịu của dứa, cà chua, bắp cải cùng thịt cá lóc săn chắc, đậm đà hương vị miền Tây sông nước.',
          tips:
              'Để nước canh trong và cá không bị tanh, nên ướp cá sơ với muối và cho cá vào nồi khi nước sôi mạnh. Bạc hà nên bóp với muối và rửa sạch để giảm độ ngứa.',
          steps: [
            'Sơ chế cá lóc (rửa muối/chanh), cắt khoanh. Ướp cá với chút nước mắm, tiêu.',
            'Chuẩn bị rau: Dứa thái miếng, cà chua bổ múi cau, dọc mùng tước vỏ thái vát bóp muối, đậu bắp cắt xéo.',
            'Đun sôi nước, cho me vào dầm lấy nước chua. Cho dứa và cà chua vào đun sôi lại.',
            'Cho cá vào nấu chín (khoảng 5-7 phút). Vớt bọt cho nước trong.',
            'Cho đậu bắp, dọc mùng, giá đỗ vào đun sôi bùng. Nêm nếm lại gia vị (đường, mắm) cho vị chua ngọt hài hòa.',
            'Tắt bếp, cho rau ngò om, ngò gai và vài lát ớt vào. Thưởng thức nóng.',
          ],
        ),
        items: [
          ShoppingListItem(
            id: '1',
            name: 'Cá lóc',
            detail: 'Khúc giữa - 500g',
            isChecked: false,
            recipeId: 'r1',
          ),
          ShoppingListItem(
            id: '2',
            name: 'Bạc hà',
            detail: '2 cây',
            isChecked: false,
            recipeId: 'r1',
          ),
          ShoppingListItem(
            id: '3',
            name: 'Dọc mùng',
            detail: '2 cây',
            isChecked: false,
            recipeId: 'r1',
          ),
          ShoppingListItem(
            id: '4',
            name: 'Ngò gai',
            detail: '1 bó nhỏ',
            isChecked: true,
            recipeId: 'r1',
          ),
          ShoppingListItem(
            id: '1a',
            name: 'Dứa (thơm)',
            detail: '1/2 quả - thái lát',
            isChecked: false,
            recipeId: 'r1',
          ),
          ShoppingListItem(
            id: '1b',
            name: 'Cà chua',
            detail: '2 quả - bổ múi cau',
            isChecked: false,
            recipeId: 'r1',
          ),
          ShoppingListItem(
            id: '1c',
            name: 'Me vắt',
            detail: '1 thìa - vắt lấy nước',
            isChecked: false,
            recipeId: 'r1',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Phở bò tái nạm',
        recipeInfo: RecipeInfo(
          recipeId: 'r2',
          servings: 4,
          cookTime: 240,
          difficulty: 'hard',
          description:
              'Tô phở bò nóng hổi, thơm lừng với nước dùng trong veo, đậm đà, những lát bò tái mềm, nạm bò giòn sần sật.',
          tips:
              'Để nước phở trong và thơm, nên hầm xương với lửa nhỏ và thường xuyên vớt bọt. Các loại gia vị khô nên rang thơm trước khi cho vào hầm.',
          steps: [
            'Hầm xương bò với gừng, hành tây nướng và các gia vị phở (quế, hồi, thảo quả) trong 4-6 tiếng.',
            'Sơ chế thịt bò: Thái mỏng bắp bò. Rửa sạch rau thơm, giá đỗ.',
            'Lọc lấy nước dùng trong, nêm nếm gia vị vừa miệng.',
            'Trần bánh phở qua nước sôi rồi cho vào tô.',
            'Xếp thịt bò lên trên, chan nước dùng đang sôi sùng sục để bò tái chín đều.',
            'Thêm hành lá, ngò và thưởng thức với tương tương đen, tương ớt.',
          ],
        ),
        items: [
          ShoppingListItem(
            id: '7',
            name: 'Xương bò',
            detail: '1 kg - hầm nước dùng',
            isChecked: false,
            recipeId: 'r2',
          ),
          ShoppingListItem(
            id: '8',
            name: 'Bắp bò',
            detail: '300g - thái lát tái',
            isChecked: false,
            recipeId: 'r2',
          ),
          ShoppingListItem(
            id: '9',
            name: 'Bánh phở tươi',
            detail: '4 phần',
            isChecked: false,
            recipeId: 'r2',
          ),
          ShoppingListItem(
            id: '9a',
            name: 'Hành tây, gừng',
            detail: 'Nướng thơm cho nước dùng',
            isChecked: false,
            recipeId: 'r2',
          ),
          ShoppingListItem(
            id: '9b',
            name: 'Hoa hồi, quế, thảo quả',
            detail: 'Rang thơm',
            isChecked: false,
            recipeId: 'r2',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Bún chả Hà Nội',
        recipeInfo: RecipeInfo(
          recipeId: 'r3',
          servings: 3,
          cookTime: 45,
          difficulty: 'medium',
          description:
              'Món bún chả trứ danh Hà Thành với những miếng chả heo nướng thơm lừng, chả băm đậm đà, ăn cùng bún tươi và nước chấm chua ngọt.',
          tips:
              'Để chả nướng không bị khô, phết một lớp dầu ăn hoặc nước ướp trong quá trình nướng. Chọn thịt nạc vai có lẫn mỡ để chả mềm.',
        ),
        items: [
          ShoppingListItem(
            id: '10',
            name: 'Thịt ba chỉ',
            detail: '300g - thái lát ướp nướng',
            isChecked: false,
            recipeId: 'r3',
          ),
          ShoppingListItem(
            id: '11',
            name: 'Thịt nạc vai xay',
            detail: '200g - viên chả băm',
            isChecked: false,
            recipeId: 'r3',
          ),
          ShoppingListItem(
            id: '12',
            name: 'Bún tươi',
            detail: '3 phần',
            isChecked: false,
            recipeId: 'r3',
          ),
          ShoppingListItem(
            id: '12a',
            name: 'Hành tím, tỏi',
            detail: 'Băm ướp thịt',
            isChecked: false,
            recipeId: 'r3',
          ),
          ShoppingListItem(
            id: '12b',
            name: 'Nước mắm, đường, dấm',
            detail: 'Pha nước chấm',
            isChecked: false,
            recipeId: 'r3',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Thịt kho tàu',
        recipeInfo: RecipeInfo(
          recipeId: 'r4',
          servings: 4,
          cookTime: 90,
          difficulty: 'easy',
          description:
              'Món thịt kho Tàu đậm đà, mặn ngọt hài hòa với miếng thịt ba chỉ mềm tan, béo ngậy cùng trứng vịt luộc thấm vị. Đây là món ăn không thể thiếu trong mâm cơm Tết truyền thống của người miền Nam.',
          tips:
              'Nên chọn thịt ba chỉ có tỷ lệ nạc mỡ 7:3. Kho bằng nước dừa tươi sẽ giúp màu thịt đẹp tự nhiên và nước kho ngọt thanh mà không cần dùng nhiều bột ngọt.',
          steps: [
            'Sơ chế thịt ba chỉ: Rửa sạch với muối và rượu trắng, cắt miếng vuông khoảng 4-5cm. Chần sơ thịt qua nước sôi với vài lát gừng để khử mùi.',
            'Ướp thịt: Ướp thịt với nước mắm ngon, đường, tỏi băm, hành tím băm và chút tiêu trắng ít nhất 30 phút.',
            'Luộc trứng: Trứng vịt luộc chín, bóc vỏ. Có thể chiên sơ trứng qua dầu để vỏ trứng dai giòn thấm vị hơn.',
            'Kho thịt: Đun nóng chút dầu ăn, thắng nước màu từ đường. Cho thịt vào đảo săn cho thấm màu.',
            'Đổ nước dừa tươi vào sâm sấp mặt thịt. Đun sôi bùng lên rồi hạ lửa nhỏ liu riu. Vớt sạch bọt.',
            'Khi thịt bắt đầu mềm, cho trứng vào. Nêm nếm lại gia vị cho vừa miệng.',
            'Tiếp tục kho đến khi nước hơi sánh lại và thịt mềm rục. Tắt bếp và thưởng thức.',
          ],
        ),
        items: [
          ShoppingListItem(
            id: '13',
            name: 'Thịt ba chỉ',
            detail: '500g - cắt miếng vuông',
            isChecked: false,
            recipeId: 'r4',
          ),
          ShoppingListItem(
            id: '14',
            name: 'Trứng vịt',
            detail: '4–6 quả - luộc bóc vỏ',
            isChecked: false,
            recipeId: 'r4',
          ),
          ShoppingListItem(
            id: '15',
            name: 'Nước dừa tươi',
            detail: '1 quả - hoặc 200ml',
            isChecked: false,
            recipeId: 'r4',
          ),
          ShoppingListItem(
            id: '15a',
            name: 'Nước mắm, đường',
            detail: 'Ướp và nêm',
            isChecked: false,
            recipeId: 'r4',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Gỏi cuốn tôm thịt',
        recipeInfo: RecipeInfo(
          recipeId: 'r5',
          servings: 4,
          cookTime: 30,
          difficulty: 'easy',
          description:
              'Món khai vị tươi mát, lành mạnh với tôm tươi, thịt luộc, bún và rất nhiều rau sống cuộn trong lớp bánh tráng mỏng dai. Đây là món ăn được CNN bình chọn là một trong 50 món ăn ngon nhất thế giới.',
          tips:
              'Luộc tôm với chút giấm, muối và gừng để tôm đỏ đẹp và không tanh. Xếp tôm ngửa mặt đỏ ra ngoài bánh tráng để cuốn gỏi nhìn bắt mắt hơn.',
          steps: [
            'Sơ chế nguyên liệu: Rau sống rửa sạch, ngâm muối loãng. Tôm rút chỉ lưng. Thịt rửa sạch.',
            'Luộc tôm và thịt: Luộc tôm chín tới, vớt ra ngâm nước đá, lột vỏ, chẻ đôi. Thịt luộc chín với hành tím, gừng, thái lát mỏng.',
            'Chuẩn bị bún: Chần sơ bún qua nước sôi cho sợi bún tơi và sạch.',
            'Cuốn gỏi: Thấm nước sơ qua bánh tráng cho mềm. Xếp xà lách, rau thơm, bún và thịt lên một góc bánh tráng.',
            'Tiến hành cuộn chặt tay 1 vòng, sau đó xếp tôm theo hàng ngang (mặt đỏ hướng xuống dưới).',
            'Gấp hai đầu bánh tráng lại và tiếp tục cuộn tròn đến hết. Có thể cài thêm một cọng hẹ cho đẹp.',
            'Pha nước chấm: Làm tương hột xào tỏi ớt hoặc nước mắm chua ngọt để chấm kèm.',
          ],
        ),
        items: [
          ShoppingListItem(
            id: '16',
            name: 'Tôm tươi',
            detail: '200g - luộc bóc vỏ',
            isChecked: false,
            recipeId: 'r5',
          ),
          ShoppingListItem(
            id: '17',
            name: 'Thịt ba chỉ',
            detail: '200g - luộc thái lát',
            isChecked: false,
            recipeId: 'r5',
          ),
          ShoppingListItem(
            id: '18',
            name: 'Bánh tráng',
            detail: '1 gói - loại cuốn gỏi',
            isChecked: false,
            recipeId: 'r5',
          ),
          ShoppingListItem(
            id: '18a',
            name: 'Bún tươi, xà lách, rau thơm',
            detail: 'Rửa sạch để ráo',
            isChecked: false,
            recipeId: 'r5',
          ),
        ],
      ),

      // ─── Các món thêm mới để đa dạng lựa chọn ───
      ShoppingListSection(
        title: 'Bánh mì thịt nướng',
        recipeInfo: RecipeInfo(
          recipeId: 'r6',
          servings: 2,
          cookTime: 25,
          difficulty: 'easy',
          description:
              'Ổ bánh mì giòn rụm kẹp thịt nướng, đồ chua, dưa leo và rau thơm, ăn sáng nhanh gọn mà vẫn đầy đủ năng lượng.',
          tips:
              'Nướng thịt trên chảo gang hoặc than hoa sẽ thơm hơn, phết thêm chút mật ong để màu đẹp.',
        ),
        items: [
          ShoppingListItem(
            id: '19',
            name: 'Bánh mì',
            detail: '2 ổ - loại vỏ giòn',
            isChecked: false,
            recipeId: 'r6',
          ),
          ShoppingListItem(
            id: '19a',
            name: 'Thịt vai heo',
            detail: '250g - thái mỏng ướp nướng',
            isChecked: false,
            recipeId: 'r6',
          ),
          ShoppingListItem(
            id: '19b',
            name: 'Đồ chua',
            detail: 'Cà rốt & củ cải muối chua',
            isChecked: false,
            recipeId: 'r6',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Cơm chiên dương châu',
        recipeInfo: RecipeInfo(
          recipeId: 'r7',
          servings: 3,
          cookTime: 20,
          difficulty: 'easy',
          description:
              'Cơm chiên vàng ươm với trứng, tôm, xúc xích và đậu Hà Lan, hạt cơm tơi, thơm mùi dầu mè.',
          tips: 'Dùng cơm nguội để qua đêm để hạt cơm tơi và không bị dính.',
        ),
        items: [
          ShoppingListItem(
            id: '20',
            name: 'Cơm nguội',
            detail: '2 bát tô - để lạnh',
            isChecked: false,
            recipeId: 'r7',
          ),
          ShoppingListItem(
            id: '20a',
            name: 'Tôm tươi nhỏ',
            detail: '100g - bóc vỏ',
            isChecked: false,
            recipeId: 'r7',
          ),
          ShoppingListItem(
            id: '20b',
            name: 'Xúc xích hoặc lạp xưởng',
            detail: '1–2 cây - thái hạt lựu',
            isChecked: false,
            recipeId: 'r7',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Mì xào bò rau cải',
        recipeInfo: RecipeInfo(
          recipeId: 'r8',
          servings: 2,
          cookTime: 15,
          difficulty: 'easy',
          description:
              'Mì xào nhanh với thịt bò, cải xanh, cà rốt và hành tây, đậm vị nước tương và dầu hào.',
          tips:
              'Xào bò nhanh trên lửa lớn trước, vớt ra rồi mới cho lại để không bị dai.',
        ),
        items: [
          ShoppingListItem(
            id: '21',
            name: 'Mì trứng tươi',
            detail: '2 vắt',
            isChecked: false,
            recipeId: 'r8',
          ),
          ShoppingListItem(
            id: '21a',
            name: 'Thịt bò thăn',
            detail: '150g - thái lát mỏng',
            isChecked: false,
            recipeId: 'r8',
          ),
          ShoppingListItem(
            id: '21b',
            name: 'Cải thìa / cải ngọt',
            detail: '1 bó nhỏ',
            isChecked: false,
            recipeId: 'r8',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Bún bò Huế',
        recipeInfo: RecipeInfo(
          recipeId: 'r9',
          servings: 4,
          cookTime: 180,
          difficulty: 'hard',
          description:
              'Tô bún bò Huế cay nồng, nước dùng đỏ cam thơm mùi sả, mắm ruốc và ớt.',
          tips:
              'Mắm ruốc nên hòa tan và lọc kỹ trước khi cho vào nồi để nước trong.',
        ),
        items: [
          ShoppingListItem(
            id: '22',
            name: 'Xương bò / xương heo',
            detail: '1.5 kg - hầm nước dùng',
            isChecked: false,
            recipeId: 'r9',
          ),
          ShoppingListItem(
            id: '22a',
            name: 'Giò heo',
            detail: '1 cái - chặt khoanh',
            isChecked: false,
            recipeId: 'r9',
          ),
          ShoppingListItem(
            id: '22b',
            name: 'Bún sợi to',
            detail: '4 phần',
            isChecked: false,
            recipeId: 'r9',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Cánh gà chiên nước mắm',
        recipeInfo: RecipeInfo(
          recipeId: 'r10',
          servings: 3,
          cookTime: 30,
          difficulty: 'easy',
          description:
              'Cánh gà chiên giòn ngoài, thấm sốt nước mắm tỏi ớt mặn ngọt, rất đưa cơm.',
          tips:
              'Ướp gà với chút bột bắp để vỏ giòn hơn, chiên 2 lần để giữ độ giòn.',
        ),
        items: [
          ShoppingListItem(
            id: '23',
            name: 'Cánh gà',
            detail: '8–10 cái',
            isChecked: false,
            recipeId: 'r10',
          ),
          ShoppingListItem(
            id: '23a',
            name: 'Nước mắm, đường, tỏi, ớt',
            detail: 'Làm sốt',
            isChecked: false,
            recipeId: 'r10',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Lẩu thái hải sản',
        recipeInfo: RecipeInfo(
          recipeId: 'r11',
          servings: 4,
          cookTime: 40,
          difficulty: 'medium',
          description:
              'Nồi lẩu chua cay với tôm, mực, nghêu và nhiều loại rau nhúng.',
          tips:
              'Dùng sả, lá chanh và nước cốt chanh tươi để hương vị thanh hơn.',
        ),
        items: [
          ShoppingListItem(
            id: '24',
            name: 'Tôm, mực, nghêu',
            detail: 'Tổng 500–700g',
            isChecked: false,
            recipeId: 'r11',
          ),
          ShoppingListItem(
            id: '24a',
            name: 'Gói gia vị lẩu Thái',
            detail: '1 gói',
            isChecked: false,
            recipeId: 'r11',
          ),
          ShoppingListItem(
            id: '24b',
            name: 'Rau nhúng lẩu',
            detail: 'Cải thảo, rau muống, nấm...',
            isChecked: false,
            recipeId: 'r11',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Bò né chảo gang',
        recipeInfo: RecipeInfo(
          recipeId: 'r12',
          servings: 2,
          cookTime: 20,
          difficulty: 'medium',
          description:
              'Bò né nóng xèo xèo trên chảo gang với trứng, pate và bánh mì.',
          tips:
              'Làm nóng chảo thật kỹ trước khi cho bò để tạo tiếng “né” hấp dẫn.',
        ),
        items: [
          ShoppingListItem(
            id: '25',
            name: 'Thịt bò phi lê',
            detail: '200g - ướp tiêu tỏi',
            isChecked: false,
            recipeId: 'r12',
          ),
          ShoppingListItem(
            id: '25a',
            name: 'Bánh mì & trứng gà',
            detail: '2 ổ & 2 quả',
            isChecked: false,
            recipeId: 'r12',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Miến xào cua biển',
        recipeInfo: RecipeInfo(
          recipeId: 'r13',
          servings: 3,
          cookTime: 30,
          difficulty: 'medium',
          description:
              'Miến xào thấm vị nước cua, ăn cùng rau thơm và hành phi.',
          tips: 'Ngâm miến vừa đủ mềm, không để quá lâu sẽ bị nát khi xào.',
        ),
        items: [
          ShoppingListItem(
            id: '26',
            name: 'Miến dong',
            detail: '200g - ngâm mềm',
            isChecked: false,
            recipeId: 'r13',
          ),
          ShoppingListItem(
            id: '26a',
            name: 'Thịt cua / ghẹ',
            detail: '200g',
            isChecked: false,
            recipeId: 'r13',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Salad ức gà sốt mè rang',
        recipeInfo: RecipeInfo(
          recipeId: 'r14',
          servings: 2,
          cookTime: 20,
          difficulty: 'easy',
          description:
              'Món salad thanh mát với ức gà luộc xé, rau xanh và sốt mè rang béo bùi.',
          tips:
              'Không luộc ức gà quá lâu để thịt không bị khô, ngâm lại trong nước luộc vài phút sau khi tắt bếp.',
        ),
        items: [
          ShoppingListItem(
            id: '27',
            name: 'Ức gà',
            detail: '1 miếng - luộc xé sợi',
            isChecked: false,
            recipeId: 'r14',
          ),
          ShoppingListItem(
            id: '27a',
            name: 'Xà lách, cà chua bi',
            detail: 'Rửa sạch để ráo',
            isChecked: false,
            recipeId: 'r14',
          ),
          ShoppingListItem(
            id: '27b',
            name: 'Sốt mè rang',
            detail: '1 chai nhỏ',
            isChecked: false,
            recipeId: 'r14',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Bánh xèo miền Tây',
        recipeInfo: RecipeInfo(
          recipeId: 'r15',
          servings: 4,
          cookTime: 50,
          difficulty: 'medium',
          description:
              'Bánh xèo giòn rụm, nhân tôm thịt và giá đỗ, ăn kèm rau sống và nước mắm chua ngọt.',
          tips:
              'Pha bột hơi lỏng và dùng chảo chống dính tốt để bánh mỏng, giòn.',
        ),
        items: [
          ShoppingListItem(
            id: '28',
            name: 'Bột bánh xèo',
            detail: '1 gói',
            isChecked: false,
            recipeId: 'r15',
          ),
          ShoppingListItem(
            id: '28a',
            name: 'Tôm, thịt ba chỉ, giá đỗ',
            detail: 'Nhân bánh',
            isChecked: false,
            recipeId: 'r15',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Bún riêu cua',
        recipeInfo: RecipeInfo(
          recipeId: 'r16',
          servings: 4,
          cookTime: 60,
          difficulty: 'medium',
          description:
              'Tô bún riêu với riêu cua, giò heo, đậu hũ chiên và cà chua chua nhẹ.',
          tips: 'Khuấy riêu nhẹ tay sau khi đổ vào nồi để không bị vỡ nát.',
        ),
        items: [
          ShoppingListItem(
            id: '29',
            name: 'Cua đồng xay / riêu cua đóng hộp',
            detail: '1–2 hũ',
            isChecked: false,
            recipeId: 'r16',
          ),
          ShoppingListItem(
            id: '29a',
            name: 'Đậu hũ, bún tươi, cà chua',
            detail: 'Tùy khẩu phần',
            isChecked: false,
            recipeId: 'r16',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Cá kho tộ',
        recipeInfo: RecipeInfo(
          recipeId: 'r17',
          servings: 3,
          cookTime: 45,
          difficulty: 'easy',
          description:
              'Cá kho đậm đà, thịt cá chắc, nước kho sánh, ăn với cơm trắng rất hao cơm.',
          tips: 'Thắng nước màu trước khi cho cá giúp màu đẹp và thơm.',
        ),
        items: [
          ShoppingListItem(
            id: '30',
            name: 'Cá basa / cá trắm',
            detail: '500g - cắt khúc',
            isChecked: false,
            recipeId: 'r17',
          ),
          ShoppingListItem(
            id: '30a',
            name: 'Nước mắm, đường, tiêu',
            detail: 'Ướp và kho',
            isChecked: false,
            recipeId: 'r17',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Gà kho gừng',
        recipeInfo: RecipeInfo(
          recipeId: 'r18',
          servings: 4,
          prepTime: 15,
          cookTime: 30,
          difficulty: 'easy',
          description:
              'Món ăn đậm đà hương vị truyền thống Việt Nam với vị cay nồng của gừng sả hòa quyện cùng thịt gà mềm ngọt, rất thích hợp cho bữa cơm gia đình.',
          tips: 'Phi thơm gừng trước rồi mới cho gà vào đảo cho thấm mùi.',
        ),
        items: [
          ShoppingListItem(
            id: '31',
            name: 'Gà ta chặt miếng',
            detail: '600g',
            isChecked: false,
            recipeId: 'r18',
          ),
          ShoppingListItem(
            id: '31a',
            name: 'Gừng tươi, nước mắm',
            detail: 'Kho đậm vị',
            isChecked: false,
            recipeId: 'r18',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Bò hầm rau củ',
        recipeInfo: RecipeInfo(
          recipeId: 'r19',
          servings: 4,
          cookTime: 120,
          difficulty: 'medium',
          description:
              'Thịt bò hầm mềm với khoai tây, cà rốt và cần tây, dùng kèm bánh mì hoặc cơm.',
          tips: 'Dùng phần nạm hoặc bắp bò có gân để hầm sẽ ngon hơn.',
        ),
        items: [
          ShoppingListItem(
            id: '32',
            name: 'Thịt bò hầm',
            detail: '700g - cắt vuông',
            isChecked: false,
            recipeId: 'r19',
          ),
          ShoppingListItem(
            id: '32a',
            name: 'Khoai tây, cà rốt, cần tây',
            detail: 'Cắt khúc',
            isChecked: false,
            recipeId: 'r19',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Mì quảng gà',
        recipeInfo: RecipeInfo(
          recipeId: 'r20',
          servings: 3,
          cookTime: 45,
          difficulty: 'medium',
          description:
              'Mì quảng với thịt gà, trứng cút, đậu phộng rang và rau sống, nước chan sền sệt.',
          tips: 'Nước chan chỉ cần xâm xấp mì, không cần quá nhiều như phở.',
        ),
        items: [
          ShoppingListItem(
            id: '33',
            name: 'Mì quảng khô',
            detail: '3 phần',
            isChecked: false,
            recipeId: 'r20',
          ),
          ShoppingListItem(
            id: '33a',
            name: 'Gà, trứng cút, đậu phộng rang',
            detail: 'Nhân mì',
            isChecked: false,
            recipeId: 'r20',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Bánh canh chả cá',
        recipeInfo: RecipeInfo(
          recipeId: 'r21',
          servings: 4,
          cookTime: 50,
          difficulty: 'medium',
          description:
              'Bánh canh sợi to với nước dùng xương, chả cá dai và hành ngò.',
          tips: 'Luộc sợi bánh canh riêng rồi xả nước lạnh để không bị dính.',
        ),
        items: [
          ShoppingListItem(
            id: '34',
            name: 'Bánh canh',
            detail: '1 gói',
            isChecked: false,
            recipeId: 'r21',
          ),
          ShoppingListItem(
            id: '34a',
            name: 'Chả cá thu / chả cá basa',
            detail: '300g',
            isChecked: false,
            recipeId: 'r21',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Cháo ếch Singapore',
        recipeInfo: RecipeInfo(
          recipeId: 'r22',
          servings: 2,
          cookTime: 40,
          difficulty: 'medium',
          description:
              'Cháo trắng mịn ăn kèm ếch xào sốt sánh, thơm hành gừng và nước tương.',
          tips:
              'Xào ếch trên lửa lớn cho săn, sau đó mới cho nước sốt để thấm vị.',
        ),
        items: [
          ShoppingListItem(
            id: '35',
            name: 'Đùi ếch',
            detail: '300–400g',
            isChecked: false,
            recipeId: 'r22',
          ),
          ShoppingListItem(
            id: '35a',
            name: 'Gạo tẻ, gạo nếp',
            detail: 'Pha 1:1 nấu cháo',
            isChecked: false,
            recipeId: 'r22',
          ),
        ],
      ),
      ShoppingListSection(
        title: 'Súp bí đỏ kem tươi',
        recipeInfo: RecipeInfo(
          recipeId: 'r23',
          servings: 2,
          cookTime: 30,
          difficulty: 'easy',
          description:
              'Súp bí đỏ xay mịn, béo nhẹ với kem tươi, ăn khai vị rất hợp.',
          tips: 'Xào bí với bơ trước khi ninh giúp dậy mùi thơm.',
        ),
        items: [
          ShoppingListItem(
            id: '36',
            name: 'Bí đỏ',
            detail: '400g - gọt vỏ, cắt miếng',
            isChecked: false,
            recipeId: 'r23',
          ),
          ShoppingListItem(
            id: '36a',
            name: 'Kem tươi, sữa tươi',
            detail: 'Pha vừa béo',
            isChecked: false,
            recipeId: 'r23',
          ),
        ],
      ),

      ShoppingListSection(
        title: 'Cần mua thêm',
        recipeInfo: null,
        items: [
          ShoppingListItem(
            id: '5',
            name: 'Sữa tươi không đường',
            detail: '1 hộp 1 lít',
            isChecked: false,
          ),
          ShoppingListItem(
            id: '6',
            name: 'Trứng gà',
            detail: '1 vỉ - 10 quả',
            isChecked: true,
          ),
        ],
      ),
    ];
    _allItems = _sections.expand((s) => s.items).toList();
  }

  Future<void> _openDishDetail(ShoppingListSection section) async {
    final updatedItems = await Navigator.push<List<ShoppingListItem>>(
      context,
      MaterialPageRoute(
        builder: (context) => DishDetailScreen(section: section),
      ),
    );
    if (updatedItems != null && mounted) {
      setState(() {
        for (final item in updatedItems) {
          final idx = _allItems.indexWhere((e) => e.id == item.id);
          if (idx >= 0) _allItems[idx] = item;
        }
        _sections = _sections.map((sec) {
          if (sec.title != section.title) return sec;
          return ShoppingListSection(
            title: sec.title,
            recipeInfo: sec.recipeInfo,
            items: sec.items.map((i) {
              final found = updatedItems.where((u) => u.id == i.id).toList();
              return found.isEmpty ? i : found.first;
            }).toList(),
          );
        }).toList();
      });
    }
  }

  void _openCookingDetail(ShoppingListSection section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CookingDetailScreen(section: section),
      ),
    );
  }

  int get _checkedCount => _allItems.where((i) => i.isChecked).length;
  int get _totalCount => _allItems.length;
  int get _remainingCount => _totalCount - _checkedCount;

  /// Lọc section theo tab + ô tìm kiếm: 0 Tất cả, 1 Đi chợ, 2 Nấu món ăn
  List<ShoppingListSection> get _filteredSections {
    final query = _searchQuery.trim().toLowerCase();

    List<ShoppingListSection> baseSections;
    if (_selectedTabIndex == 1 || _selectedTabIndex == 2) {
      baseSections = _sections.where((s) => s.isRecipeSection).toList();
    } else {
      baseSections = _sections;
    }

    if (query.isEmpty) return baseSections;

    return baseSections.where((s) {
      final inTitle = s.title.toLowerCase().contains(query);
      final desc = s.recipeInfo?.description?.toLowerCase() ?? '';
      final inDesc = desc.contains(query);
      return inTitle || inDesc;
    }).toList();
  }

  Future<void> _toggleItem(ShoppingListItem item) async {
    final originalChecked = item.isChecked;

    setState(() {
      final idx = _allItems.indexWhere((i) => i.id == item.id);
      if (idx >= 0) {
        _allItems[idx] = _allItems[idx].copyWith(
          isChecked: !_allItems[idx].isChecked,
        );
      }
      _sections = _sections.map((section) {
        return ShoppingListSection(
          title: section.title,
          recipeInfo: section.recipeInfo,
          items: section.items.map((i) {
            if (i.id == item.id) return i.copyWith(isChecked: !i.isChecked);
            return i;
          }).toList(),
        );
      }).toList();
    });

    final success = await ShoppingService.setPurchased(
      itemId: item.id,
      isPurchased: !originalChecked,
    );

    if (!success && mounted) {
      // Revert optimistic UI update if backend update failed.
      setState(() {
        final idx = _allItems.indexWhere((i) => i.id == item.id);
        if (idx >= 0) {
          _allItems[idx] = _allItems[idx].copyWith(isChecked: originalChecked);
        }
        _sections = _sections.map((section) {
          return ShoppingListSection(
            title: section.title,
            recipeInfo: section.recipeInfo,
            items: section.items.map((i) {
              if (i.id == item.id) {
                return i.copyWith(isChecked: originalChecked);
              }
              return i;
            }).toList(),
          );
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể cập nhật trạng thái mua sắm. Vui lòng thử lại.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _onMoveToFridge() async {
    if (_isTransferringToFridge) return;

    final checked = _allItems.where((i) => i.isChecked).toList();
    if (checked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chưa có mục nào được chọn'),
          backgroundColor: AppColors.textSecondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isTransferringToFridge = true);
    final result = await ShoppingService.transferToFridge(items: checked);
    if (!mounted) return;
    setState(() => _isTransferringToFridge = false);

    if (result.successCount > 0) {
      widget.onGoToFridge?.call(result.successCount);
    }

    if (result.failedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã thêm ${result.successCount} mục, còn ${result.failedCount} mục chưa chuyển được.',
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (result.successCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể chuyển mục nào vào tủ lạnh. Vui lòng thử lại.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddItemDialog() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final unitController = TextEditingController();
    final notesController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool submitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm mục mua sắm'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên sản phẩm *',
                        hintText: 'Ví dụ: Hành tím',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Số lượng',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: unitController,
                            decoration: const InputDecoration(
                              labelText: 'Đơn vị',
                              hintText: 'g, kg, chai...',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Vui lòng nhập tên sản phẩm'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => submitting = true);
                          final quantity = double.tryParse(
                            quantityController.text.trim(),
                          );
                          final success = await ShoppingService.addItem(
                            name: name,
                            quantity: quantity,
                            unit: unitController.text,
                            notes: notesController.text,
                          );

                          if (!context.mounted) return;
                          Navigator.pop(context, success);
                        },
                  child: const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    notesController.dispose();

    if (!mounted || created == null) return;

    if (created) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm mục mua sắm'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể thêm mục mua sắm'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ──── Header: Tiêu đề ────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Danh sách mua sắm',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Thêm mục',
                onPressed: _showAddItemDialog,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primary,
              ),
            ],
          ),
        ),

        if (_isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        if (!_isLoading) ...[
          // ──── Tab bar: Tất cả | Món ăn | Tủ lạnh ────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTab(0, 'Tất cả'),
                  _buildTab(1, 'Đi chợ'),
                  _buildTab(2, 'Nấu món ăn'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ──── Thanh tìm món ăn theo sở thích (chỉ hiện ở tab Đi chợ/Nấu ăn) ────
          if (_selectedTabIndex == 1 || _selectedTabIndex == 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSearchBar(),
            ),
          if (_selectedTabIndex == 1 || _selectedTabIndex == 2)
            const SizedBox(height: 12),

          // ──── Thống kê nhanh ────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildStatChip('$_totalCount mục', AppColors.textSecondary),
                const SizedBox(width: 10),
                _buildStatChip('$_checkedCount đã mua', AppColors.primary),
                const SizedBox(width: 10),
                _buildStatChip('$_remainingCount còn lại', AppColors.warning),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ──── Danh sách + Gợi ý ────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionsList(),
                  const SizedBox(height: 20),
                  _buildSuggestionCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // ──── Thanh hành động: Đã mua xong | Vào tủ lạnh ────
          _buildBottomActionBar(),
        ],
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Ô tìm kiếm món ăn theo sở thích (theo tên/ mô tả món)
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Tìm món theo sở thích (ví dụ: cá, bò, cay, miền Nam...)',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.textHint, size: 22),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSectionsList() {
    final sections = _filteredSections;
    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.shopping_basket_outlined,
                size: 56,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 12),
              Text(
                _selectedTabIndex == 1 || _selectedTabIndex == 2
                    ? 'Chưa có món ăn nào trong danh sách'
                    : 'Chưa có mục nào cần mua thêm',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Tab Đi chợ/Nấu ăn: hiển thị danh sách thẻ món
    if (_selectedTabIndex == 1 || _selectedTabIndex == 2) {
      return _buildDishCards(sections);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildSectionCard(section),
        );
      }).toList(),
    );
  }

  /// Danh sách thẻ món ăn (tab Món ăn) – bấm vào mở chi tiết nguyên liệu
  Widget _buildDishCards(List<ShoppingListSection> sections) {
    return Column(
      children: sections.map((section) {
        final info = section.recipeInfo!;
        final checked = section.items.where((i) => i.isChecked).length;
        final total = section.items.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (_selectedTabIndex == 2) {
                  _openCookingDetail(section);
                } else {
                  _openDishDetail(section);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.inputBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: AppColors.textHint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${info.servings} phần',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: AppColors.textHint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${info.cookTime} phút',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: info.difficulty == 'easy'
                                      ? AppColors.primaryLight
                                      : info.difficulty == 'hard'
                                      ? AppColors.error.withValues(alpha: 0.12)
                                      : const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  info.difficultyLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: info.difficulty == 'easy'
                                        ? AppColors.primary
                                        : info.difficulty == 'hard'
                                        ? AppColors.error
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$total nguyên liệu cần mua • $checked đã mua',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionCard(ShoppingListSection section) {
    final isRecipe = section.recipeInfo != null;
    final info = section.recipeInfo;
    final checkedInSection = section.items.where((i) => i.isChecked).length;
    final totalInSection = section.items.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section: tên món + thông tin chi tiết
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isRecipe)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    if (isRecipe) const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$checkedInSection/$totalInSection',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (info != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${info.servings} phần ăn',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${info.cookTime} phút',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: info.difficulty == 'easy'
                              ? AppColors.primaryLight
                              : info.difficulty == 'hard'
                              ? AppColors.error.withValues(alpha: 0.12)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          info.difficultyLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: info.difficulty == 'easy'
                                ? AppColors.primary
                                : info.difficulty == 'hard'
                                ? AppColors.error
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!isRecipe) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Nguyên liệu linh hoạt cho bữa ăn hàng ngày',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: section.items
                  .map((item) => _buildListItem(item))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(ShoppingListItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _toggleItem(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.isChecked
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.inputBorder,
                width: item.isChecked ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: item.isChecked,
                    onChanged: (_) => _toggleItem(item),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: item.isChecked
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                          decoration: item.isChecked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (item.detail.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.detail,
                          style: TextStyle(
                            fontSize: 13,
                            color: item.isChecked
                                ? AppColors.textHint
                                : AppColors.textSecondary,
                            decoration: item.isChecked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.drag_handle, size: 20, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_outlined, color: Color(0xFF1976D2), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gợi ý từ Bếp Trợ Lý',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _suggestionText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1565C0),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.restaurant_outlined,
            color: const Color(0xFF1976D2).withValues(alpha: 0.7),
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_checkedCount',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Đã mua xong',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isTransferringToFridge ? null : _onMoveToFridge,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isTransferringToFridge)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    else
                      const Text(
                        'Vào tủ lạnh',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
