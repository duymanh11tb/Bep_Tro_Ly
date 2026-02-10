from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager

db = SQLAlchemy()
login_manager = LoginManager()

from .user import User
from .category import Category
from .pantry_item import PantryItem
from .recipe import Recipe, RecipeIngredient
from .meal_plan import MealPlan, MealPlanItem
from .shopping_list import ShoppingList, ShoppingListItem
from .notification import Notification
from .user_activity import ActivityLog, UserFavorite, UserRating
from .ai_cache import AIRecipeCache

__all__ = [
    'db', 'login_manager',
    'User', 'Category', 'PantryItem',
    'Recipe', 'RecipeIngredient',
    'MealPlan', 'MealPlanItem',
    'ShoppingList', 'ShoppingListItem',
    'Notification',
    'ActivityLog', 'UserFavorite', 'UserRating',
    'AIRecipeCache'
]
