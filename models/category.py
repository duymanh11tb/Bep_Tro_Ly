from . import db
from datetime import datetime

class Category(db.Model):
    __tablename__ = 'categories'
    
    category_id = db.Column(db.Integer, primary_key=True)
    category_code = db.Column(db.String(50), unique=True, nullable=False)
    name_vi = db.Column(db.String(100), nullable=False)
    name_en = db.Column(db.String(100), nullable=False)
    icon = db.Column(db.String(10))
    color = db.Column(db.String(7))
    default_fridge_days = db.Column(db.Integer, default=7)
    default_freezer_days = db.Column(db.Integer, default=90)
    default_pantry_days = db.Column(db.Integer, default=365)
    sort_order = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    pantry_items = db.relationship('PantryItem', backref='category', lazy='dynamic')
    
    def __repr__(self):
        return f'<Category {self.name_vi}>'
