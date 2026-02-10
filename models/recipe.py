from . import db
from datetime import datetime

class Recipe(db.Model):
    __tablename__ = 'recipes'
    
    recipe_id = db.Column(db.Integer, primary_key=True)
    title_vi = db.Column(db.String(255), nullable=False)
    title_en = db.Column(db.String(255))
    description = db.Column(db.Text)
    cuisine = db.Column(db.String(50))
    meal_types = db.Column(db.JSON)
    difficulty = db.Column(db.Enum('easy', 'medium', 'hard'), default='easy')
    prep_time = db.Column(db.Integer)
    cook_time = db.Column(db.Integer)
    total_time = db.Column(db.Integer)
    servings = db.Column(db.Integer, default=2)
    main_image_url = db.Column(db.String(500))
    video_url = db.Column(db.String(500))
    instructions = db.Column(db.JSON)
    calories = db.Column(db.Integer)
    protein = db.Column(db.Numeric(5, 1))
    carbs = db.Column(db.Numeric(5, 1))
    fat = db.Column(db.Numeric(5, 1))
    fiber = db.Column(db.Numeric(5, 1))
    tags = db.Column(db.JSON)
    is_vegetarian = db.Column(db.Boolean, default=False)
    is_vegan = db.Column(db.Boolean, default=False)
    is_dairy_free = db.Column(db.Boolean, default=False)
    is_gluten_free = db.Column(db.Boolean, default=False)
    source = db.Column(db.Enum('api', 'user_generated', 'admin'), default='api')
    source_api = db.Column(db.String(50))
    author_user_id = db.Column(db.Integer)
    is_public = db.Column(db.Boolean, default=True)
    view_count = db.Column(db.Integer, default=0)
    favorite_count = db.Column(db.Integer, default=0)
    rating_average = db.Column(db.Numeric(3, 2), default=0.00)
    rating_count = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    ingredients = db.relationship('RecipeIngredient', backref='recipe', lazy='dynamic')
    meal_plan_items = db.relationship('MealPlanItem', backref='recipe', lazy='dynamic')
    favorites = db.relationship('UserFavorite', backref='recipe', lazy='dynamic')
    ratings = db.relationship('UserRating', backref='recipe', lazy='dynamic')
    
    def __repr__(self):
        return f'<Recipe {self.title_vi}>'


class RecipeIngredient(db.Model):
    __tablename__ = 'recipe_ingredients'
    
    ingredient_id = db.Column(db.Integer, primary_key=True)
    recipe_id = db.Column(db.Integer, db.ForeignKey('recipes.recipe_id'), nullable=False)
    name_vi = db.Column(db.String(200), nullable=False)
    name_en = db.Column(db.String(200))
    quantity = db.Column(db.Numeric(10, 2))
    unit = db.Column(db.String(20))
    is_optional = db.Column(db.Boolean, default=False)
    category_code = db.Column(db.String(50))
    display_order = db.Column(db.Integer, default=0)
    
    def __repr__(self):
        return f'<RecipeIngredient {self.name_vi}>'
