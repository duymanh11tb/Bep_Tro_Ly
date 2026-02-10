from . import db
from datetime import datetime

class ShoppingList(db.Model):
    __tablename__ = 'shopping_lists'
    
    list_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.user_id'), nullable=False)
    title = db.Column(db.String(255), nullable=False)
    status = db.Column(db.Enum('active', 'completed', 'archived'), default='active')
    total_items = db.Column(db.Integer, default=0)
    purchased_items = db.Column(db.Integer, default=0)
    estimated_total = db.Column(db.Numeric(10, 2), default=0.00)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    items = db.relationship('ShoppingListItem', backref='shopping_list', lazy='dynamic')
    
    def __repr__(self):
        return f'<ShoppingList {self.title}>'


class ShoppingListItem(db.Model):
    __tablename__ = 'shopping_list_items'
    
    item_id = db.Column(db.Integer, primary_key=True)
    list_id = db.Column(db.Integer, db.ForeignKey('shopping_lists.list_id'), nullable=False)
    name_vi = db.Column(db.String(200), nullable=False)
    name_en = db.Column(db.String(200))
    quantity = db.Column(db.Numeric(10, 2))
    unit = db.Column(db.String(20))
    category_code = db.Column(db.String(50))
    is_purchased = db.Column(db.Boolean, default=False)
    purchased_at = db.Column(db.DateTime)
    from_recipe_id = db.Column(db.Integer)
    from_recipe_title = db.Column(db.String(255))
    estimated_price = db.Column(db.Numeric(10, 2))
    actual_price = db.Column(db.Numeric(10, 2))
    notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f'<ShoppingListItem {self.name_vi}>'
