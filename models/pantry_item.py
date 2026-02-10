from . import db
from datetime import datetime

class PantryItem(db.Model):
    __tablename__ = 'pantry_items'
    
    item_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.user_id'), nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('categories.category_id'))
    name_vi = db.Column(db.String(200), nullable=False)
    name_en = db.Column(db.String(200))
    quantity = db.Column(db.Numeric(10, 2), nullable=False)
    unit = db.Column(db.String(20), nullable=False)
    purchase_date = db.Column(db.Date)
    expiry_date = db.Column(db.Date)
    location = db.Column(db.Enum('fridge', 'freezer', 'pantry'), default='fridge')
    add_method = db.Column(db.Enum('manual', 'barcode', 'ocr'), default='manual')
    barcode = db.Column(db.String(50))
    image_url = db.Column(db.String(500))
    notes = db.Column(db.Text)
    status = db.Column(db.Enum('active', 'used', 'expired', 'deleted'), default='active')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f'<PantryItem {self.name_vi}>'
