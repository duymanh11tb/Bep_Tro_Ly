"""Production-ready configuration using environment variables."""
import os


class Config:
    # Flask
    SECRET_KEY = os.environ.get('SECRET_KEY')

    # Gemini AI
    GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')

    # TiDB Cloud Database
    TIDB_HOST = os.environ.get('TIDB_HOST')
    TIDB_PORT = int(os.environ.get('TIDB_PORT', 4000))
    TIDB_USER = os.environ.get('TIDB_USER')
    TIDB_PASSWORD = os.environ.get('TIDB_PASSWORD')
    TIDB_DATABASE = os.environ.get('TIDB_DATABASE')

    # SQLAlchemy
    SQLALCHEMY_DATABASE_URI = (
        f"mysql+pymysql://{TIDB_USER}:{TIDB_PASSWORD}@{TIDB_HOST}:{TIDB_PORT}/{TIDB_DATABASE}"
        "?ssl_verify_cert=false&ssl_verify_identity=false"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_recycle': 3600,
        'pool_pre_ping': True,
        'pool_size': 5,
        'max_overflow': 10,
        'connect_args': {
            'ssl': {'ssl': True}
        }
    }
