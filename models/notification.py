from . import db
from datetime import datetime

class Notification(db.Model):
    __tablename__ = 'notifications'
    
    notification_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.user_id'), nullable=False)
    type = db.Column(db.Enum('expiry_alert', 'recipe_suggestion', 'system', 'meal_reminder'), default='expiry_alert')
    title = db.Column(db.String(255), nullable=False)
    body = db.Column(db.Text, nullable=False)
    related_item_id = db.Column(db.Integer)
    related_recipe_ids = db.Column(db.JSON)
    is_read = db.Column(db.Boolean, default=False)
    is_sent = db.Column(db.Boolean, default=False)
    sent_at = db.Column(db.DateTime)
    read_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f'<Notification {self.title}>'
