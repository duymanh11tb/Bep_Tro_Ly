"""Bếp Trợ Lý API - Flask Backend."""
import os
import logging
from flask import Flask, jsonify, request
from config import Config
from models import db, login_manager, User
from functools import wraps
import jwt
from datetime import datetime, timedelta

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config.from_object(Config)

# Initialize extensions
db.init_app(app)
login_manager.init_app(app)


# ==================== JWT Helpers ====================

def create_token(user_id):
    """Create JWT token for a user."""
    payload = {
        'user_id': user_id,
        'exp': datetime.utcnow() + timedelta(days=30),
        'iat': datetime.utcnow()
    }
    return jwt.encode(payload, app.config['SECRET_KEY'], algorithm='HS256')


def token_required(f):
    """Decorator to require JWT token for protected routes."""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        if not token:
            return jsonify({'error': 'Token không được cung cấp'}), 401
        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = db.session.get(User, data['user_id'])
            if not current_user:
                return jsonify({'error': 'User không tồn tại'}), 401
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token đã hết hạn'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Token không hợp lệ'}), 401
        return f(current_user, *args, **kwargs)
    return decorated


def _user_to_dict(user, full=False):
    """Serialize user to dict. full=True includes all profile fields."""
    data = {
        'user_id': user.user_id,
        'email': user.email,
        'display_name': user.display_name,
    }
    if full:
        data.update({
            'phone_number': user.phone_number,
            'photo_url': user.photo_url,
            'dietary_restrictions': user.dietary_restrictions,
            'cuisine_preferences': user.cuisine_preferences,
            'allergies': user.allergies,
            'skill_level': user.skill_level,
            'notification_enabled': user.notification_enabled,
            'created_at': user.created_at.isoformat() if user.created_at else None,
        })
    else:
        data['photo_url'] = user.photo_url
        data['skill_level'] = user.skill_level
    return data


# ==================== API ROUTES ====================

@app.route('/')
def index():
    return jsonify({
        'app': 'Bếp Trợ Lý API',
        'version': '1.0.0',
        'status': 'running',
    })


@app.route('/health')
def health():
    """Health check endpoint for monitoring."""
    try:
        db.session.execute(db.text('SELECT 1'))
        return jsonify({'status': 'healthy', 'db': 'ok'})
    except Exception as e:
        logger.error(f'Health check failed: {e}')
        return jsonify({'status': 'unhealthy', 'db': str(e)}), 503


# ==================== AUTH API ====================

@app.route('/api/auth/register', methods=['POST'])
def register():
    """Đăng ký tài khoản mới."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Dữ liệu không hợp lệ'}), 400

    email = data.get('email', '').strip().lower()
    password = data.get('password', '')
    display_name = data.get('display_name', '')

    if not email or not password:
        return jsonify({'error': 'Email và mật khẩu là bắt buộc'}), 400
    if len(password) < 6:
        return jsonify({'error': 'Mật khẩu phải có ít nhất 6 ký tự'}), 400

    if User.query.filter_by(email=email).first():
        return jsonify({'error': 'Email đã được sử dụng'}), 409

    try:
        user = User(
            email=email,
            display_name=display_name or email.split('@')[0]
        )
        user.set_password(password)
        db.session.add(user)
        db.session.commit()

        return jsonify({
            'message': 'Đăng ký thành công!',
            'user': _user_to_dict(user),
            'token': create_token(user.user_id)
        }), 201
    except Exception as e:
        db.session.rollback()
        logger.error(f'Register error: {e}')
        return jsonify({'error': 'Lỗi đăng ký'}), 500


@app.route('/api/auth/login', methods=['POST'])
def login():
    """Đăng nhập."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Dữ liệu không hợp lệ'}), 400

    email = data.get('email', '').strip().lower()
    password = data.get('password', '')

    if not email or not password:
        return jsonify({'error': 'Email và mật khẩu là bắt buộc'}), 400

    user = User.query.filter_by(email=email).first()
    if not user or not user.check_password(password):
        return jsonify({'error': 'Email hoặc mật khẩu không đúng'}), 401

    user.last_active = datetime.utcnow()
    db.session.commit()

    return jsonify({
        'message': 'Đăng nhập thành công!',
        'user': _user_to_dict(user),
        'token': create_token(user.user_id)
    })


@app.route('/api/auth/me', methods=['GET'])
@token_required
def get_me(current_user):
    """Lấy thông tin user hiện tại (cần token)."""
    return jsonify({'user': _user_to_dict(current_user, full=True)})


# ==================== AI RECIPE SUGGESTION API ====================

@app.route('/api/recipes/suggest', methods=['POST'])
@token_required
def suggest_recipes(current_user):
    """Gợi ý món ăn dựa trên nguyên liệu."""
    from services import AIRecipeService

    data = request.get_json() or {}
    ingredients = data.get('ingredients', [])
    if not ingredients:
        return jsonify({
            'error': 'Vui lòng cung cấp danh sách nguyên liệu',
            'example': {'ingredients': ['thịt bò', 'hành tây', 'cà chua']}
        }), 400

    result = AIRecipeService().suggest_recipes(
        ingredients,
        data.get('preferences', {}),
        data.get('limit', 5)
    )
    return jsonify(result) if result['success'] else (jsonify(result), 500)


@app.route('/api/recipes/suggest-from-pantry', methods=['POST'])
@token_required
def suggest_from_pantry(current_user):
    """Gợi ý món ăn từ nguyên liệu trong tủ lạnh của user."""
    from services import AIRecipeService

    data = request.get_json() or {}
    result = AIRecipeService().suggest_from_pantry(
        current_user.user_id,
        data.get('preferences', {}),
        data.get('limit', 5)
    )
    return jsonify(result) if result['success'] else (jsonify(result), 400)


# ==================== Error Handlers ====================

@app.errorhandler(404)
def not_found(e):
    return jsonify({'error': 'Endpoint không tồn tại'}), 404


@app.errorhandler(500)
def server_error(e):
    return jsonify({'error': 'Lỗi server'}), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)
