from . import db, login_manager
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

class User(UserMixin, db.Model):
    __tablename__ = 'users'
    
    user_id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    display_name = db.Column(db.String(100))
    phone_number = db.Column(db.String(20))
    photo_url = db.Column(db.String(500))
    dietary_restrictions = db.Column(db.JSON)
    cuisine_preferences = db.Column(db.JSON)
    allergies = db.Column(db.JSON)
    skill_level = db.Column(db.Enum('beginner', 'intermediate', 'advanced'), default='beginner')
    notification_enabled = db.Column(db.Boolean, default=True)
    notification_time = db.Column(db.Time, default='18:00:00')
    expiry_alert_days = db.Column(db.Integer, default=2)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_active = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    pantry_items = db.relationship('PantryItem', backref='user', lazy='dynamic')
    meal_plans = db.relationship('MealPlan', backref='user', lazy='dynamic')
    shopping_lists = db.relationship('ShoppingList', backref='user', lazy='dynamic')
    notifications = db.relationship('Notification', backref='user', lazy='dynamic')
    favorites = db.relationship('UserFavorite', backref='user', lazy='dynamic')
    ratings = db.relationship('UserRating', backref='user', lazy='dynamic')
    activity_logs = db.relationship('ActivityLog', backref='user', lazy='dynamic')
    
    def get_id(self):
        return str(self.user_id)
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
    def __repr__(self):
        return f'<User {self.email}>'


@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))
