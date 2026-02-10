"""
AI Recipe Suggestion Service
Sử dụng Google Gemini AI để đề xuất công thức món ăn dựa trên nguyên liệu có sẵn
"""

import json
import hashlib
from datetime import datetime, timedelta
from google import genai
from flask import current_app


class AIRecipeService:
    """
    Service để đề xuất món ăn sử dụng Hybrid Approach:
    1. Tìm trong database trước
    2. Bổ sung bằng AI nếu cần
    """
    
    def __init__(self, api_key: str = None):
        """
        Khởi tạo service với Gemini API key
        """
        self.api_key = api_key or current_app.config.get('GEMINI_API_KEY')
        if self.api_key:
            self.client = genai.Client(api_key=self.api_key)
        else:
            self.client = None
    
    def suggest_recipes(
        self, 
        ingredients: list[str], 
        preferences: dict = None,
        limit: int = 5
    ) -> dict:
        """
        Gợi ý món ăn dựa trên nguyên liệu
        
        Args:
            ingredients: List các nguyên liệu có sẵn (tiếng Việt)
            preferences: Dict preferences như dietary_restrictions, cuisine, difficulty
            limit: Số lượng món muốn gợi ý
            
        Returns:
            Dict chứa danh sách recipes được đề xuất
        """
        if not ingredients:
            return {
                'success': False,
                'error': 'Vui lòng cung cấp ít nhất một nguyên liệu',
                'recipes': []
            }
        
        # Kiểm tra cache trước
        cache_key = self._generate_cache_key(ingredients, preferences)
        cached_result = self._get_from_cache(cache_key)
        if cached_result:
            return {
                'success': True,
                'source': 'cache',
                'recipes': cached_result
            }
        
        # Gọi AI để generate suggestions
        try:
            ai_recipes = self._generate_ai_suggestions(ingredients, preferences, limit)
            
            # Cache kết quả
            self._save_to_cache(cache_key, ai_recipes)
            
            return {
                'success': True,
                'source': 'ai',
                'recipes': ai_recipes
            }
        except Exception as e:
            return {
                'success': False,
                'error': f'Lỗi AI: {str(e)}',
                'recipes': []
            }
    
    def _generate_ai_suggestions(
        self, 
        ingredients: list[str], 
        preferences: dict = None,
        limit: int = 5
    ) -> list[dict]:
        """
        Gọi Gemini API để generate recipe suggestions
        """
        if not self.client:
            raise ValueError("Gemini API key chưa được cấu hình")
        
        # Xây dựng prompt
        preferences = preferences or {}
        dietary = preferences.get('dietary_restrictions', [])
        cuisine = preferences.get('cuisine', 'Việt Nam')
        difficulty = preferences.get('difficulty', 'any')
        
        dietary_text = f"Chế độ ăn đặc biệt: {', '.join(dietary)}" if dietary else ""
        difficulty_text = f"Độ khó: {difficulty}" if difficulty != 'any' else ""
        
        prompt = f"""Bạn là chuyên gia ẩm thực Việt Nam với kinh nghiệm 20 năm.

Nguyên liệu có sẵn: {', '.join(ingredients)}
Phong cách ẩm thực: {cuisine}
{dietary_text}
{difficulty_text}

Hãy đề xuất {limit} món ăn có thể nấu với các nguyên liệu trên.

QUAN TRỌNG: Trả về JSON format CHÍNH XÁC như sau, KHÔNG thêm markdown code block:
{{
    "recipes": [
        {{
            "name": "Tên món ăn",
            "description": "Mô tả ngắn gọn về món ăn (1-2 câu)",
            "difficulty": "easy hoặc medium hoặc hard",
            "prep_time": số phút chuẩn bị,
            "cook_time": số phút nấu,
            "servings": số người ăn,
            "ingredients_used": ["nguyên liệu 1", "nguyên liệu 2"],
            "ingredients_missing": ["nguyên liệu cần mua thêm nếu có"],
            "match_score": số từ 0.0 đến 1.0 (tỷ lệ nguyên liệu khớp),
            "instructions": [
                "Bước 1: ...",
                "Bước 2: ...",
                "Bước 3: ..."
            ],
            "tips": "Mẹo nấu ăn"
        }}
    ]
}}

Sắp xếp theo match_score từ cao đến thấp (ưu tiên món dùng nhiều nguyên liệu có sẵn nhất)."""

        # Gọi Gemini API
        response = self.client.models.generate_content(
            model="gemini-2.0-flash",
            contents=prompt
        )
        
        # Parse response
        response_text = response.text.strip()
        
        # Loại bỏ markdown code block nếu có
        if response_text.startswith('```'):
            lines = response_text.split('\n')
            response_text = '\n'.join(lines[1:-1])
        
        try:
            result = json.loads(response_text)
            return result.get('recipes', [])
        except json.JSONDecodeError:
            # Thử tìm JSON trong response
            import re
            json_match = re.search(r'\{[\s\S]*\}', response_text)
            if json_match:
                result = json.loads(json_match.group())
                return result.get('recipes', [])
            raise ValueError("Không thể parse AI response")
    
    def _generate_cache_key(self, ingredients: list[str], preferences: dict = None) -> str:
        """
        Tạo cache key từ ingredients và preferences
        """
        # Normalize ingredients
        normalized = sorted([i.lower().strip() for i in ingredients])
        key_data = {
            'ingredients': normalized,
            'preferences': preferences or {}
        }
        key_string = json.dumps(key_data, sort_keys=True, ensure_ascii=False)
        return hashlib.md5(key_string.encode()).hexdigest()
    
    def _get_from_cache(self, cache_key: str) -> list[dict] | None:
        """
        Lấy kết quả từ cache (trong database)
        """
        try:
            from models import db
            from models.ai_cache import AIRecipeCache
            
            cache_entry = AIRecipeCache.query.filter_by(
                cache_key=cache_key
            ).first()
            
            if cache_entry and cache_entry.expires_at > datetime.utcnow():
                return cache_entry.response_data
            
            # Xóa cache đã hết hạn
            if cache_entry:
                db.session.delete(cache_entry)
                db.session.commit()
                
            return None
        except Exception:
            return None
    
    def _save_to_cache(self, cache_key: str, recipes: list[dict], ttl_hours: int = 24):
        """
        Lưu kết quả vào cache
        """
        try:
            from models import db
            from models.ai_cache import AIRecipeCache
            
            # Xóa cache cũ nếu có
            AIRecipeCache.query.filter_by(cache_key=cache_key).delete()
            
            # Tạo cache mới
            cache_entry = AIRecipeCache(
                cache_key=cache_key,
                response_data=recipes,
                expires_at=datetime.utcnow() + timedelta(hours=ttl_hours)
            )
            db.session.add(cache_entry)
            db.session.commit()
        except Exception as e:
            # Log error nhưng không raise
            print(f"Cache error: {e}")
    
    def suggest_from_pantry(self, user_id: int, preferences: dict = None, limit: int = 5) -> dict:
        """
        Gợi ý món ăn từ nguyên liệu trong tủ lạnh của user
        
        Args:
            user_id: ID của user
            preferences: Dict preferences
            limit: Số lượng món muốn gợi ý
            
        Returns:
            Dict chứa danh sách recipes được đề xuất
        """
        from models import PantryItem
        
        # Lấy nguyên liệu active từ pantry
        pantry_items = PantryItem.query.filter_by(
            user_id=user_id,
            status='active'
        ).all()
        
        if not pantry_items:
            return {
                'success': False,
                'error': 'Tủ lạnh của bạn đang trống. Hãy thêm nguyên liệu trước!',
                'recipes': []
            }
        
        # Lấy danh sách tên nguyên liệu
        ingredients = [item.name_vi for item in pantry_items]
        
        # Gọi hàm suggest chính
        return self.suggest_recipes(ingredients, preferences, limit)
