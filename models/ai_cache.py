"""
AI Recipe Cache Model
Lưu cache kết quả AI để tiết kiệm API calls
"""

from . import db
from datetime import datetime


class AIRecipeCache(db.Model):
    __tablename__ = 'ai_recipe_cache'
    
    cache_id = db.Column(db.Integer, primary_key=True)
    cache_key = db.Column(db.String(64), unique=True, nullable=False, index=True)
    response_data = db.Column(db.JSON, nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f'<AIRecipeCache {self.cache_key[:8]}...>'
    
    @property
    def is_expired(self) -> bool:
        return datetime.utcnow() > self.expires_at
