from . import db
from datetime import datetime

class ActivityLog(db.Model):
    __tablename__ = 'activity_logs'
    
    log_id = db.Column(db.BigInteger, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.user_id'), nullable=False)
    activity_type = db.Column(db.Enum('view_recipe', 'cook_recipe', 'add_ingredient', 'use_ingredient', 'search'), nullable=False)
    related_recipe_id = db.Column(db.Integer)
    related_item_id = db.Column(db.Integer)
    extra_data = db.Column(db.JSON)  # Renamed from 'metadata' (reserved keyword)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f'<ActivityLog {self.activity_type}>'


class UserFavorite(db.Model):
    __tablename__ = 'user_favorites'
    
    favorite_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.user_id'), nullable=False)
    recipe_id = db.Column(db.Integer, db.ForeignKey('recipes.recipe_id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f'<UserFavorite user={self.user_id} recipe={self.recipe_id}>'


class UserRating(db.Model):
    __tablename__ = 'user_ratings'
    
    rating_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.user_id'), nullable=False)
    recipe_id = db.Column(db.Integer, db.ForeignKey('recipes.recipe_id'), nullable=False)
    rating = db.Column(db.Integer, nullable=False)
    review = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f'<UserRating user={self.user_id} recipe={self.recipe_id} rating={self.rating}>'
