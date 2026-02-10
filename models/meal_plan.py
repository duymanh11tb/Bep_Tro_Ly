from . import db
from datetime import datetime

class MealPlan(db.Model):
    __tablename__ = 'meal_plans'
    
    plan_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.user_id'), nullable=False)
    week_start = db.Column(db.Date, nullable=False)
    week_end = db.Column(db.Date, nullable=False)
    title = db.Column(db.String(255), default='Meal Plan')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    items = db.relationship('MealPlanItem', backref='meal_plan', lazy='dynamic')
    
    def __repr__(self):
        return f'<MealPlan {self.title}>'


class MealPlanItem(db.Model):
    __tablename__ = 'meal_plan_items'
    
    item_id = db.Column(db.Integer, primary_key=True)
    plan_id = db.Column(db.Integer, db.ForeignKey('meal_plans.plan_id'), nullable=False)
    recipe_id = db.Column(db.Integer, db.ForeignKey('recipes.recipe_id'), nullable=False)
    meal_date = db.Column(db.Date, nullable=False)
    meal_type = db.Column(db.Enum('breakfast', 'lunch', 'dinner', 'snack'), nullable=False)
    is_cooked = db.Column(db.Boolean, default=False)
    cooked_at = db.Column(db.DateTime)
    notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f'<MealPlanItem {self.meal_type} - {self.meal_date}>'
