# CLAUDE.md — Legoland DB

This file describes the codebase structure, development conventions, and workflows for AI assistants working in this repository.

---

## Project Overview

**Legoland DB** is a multi-user web application for managing a personal LEGO collection. Users can register, log in, and perform full CRUD operations on their own LEGO set catalog entries. Data is isolated per user — no user can read or modify another user's items.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Python 3 |
| Web framework | Flask 3.0+ |
| ORM | Flask-SQLAlchemy 3.1+ |
| Database | SQLite (default), configurable via env var |
| Auth session | Flask-Login 0.6+ |
| Forms & CSRF | Flask-WTF 1.2+, WTForms 3.1+ |
| Password hashing | bcrypt 3.2+ |
| Templating | Jinja2 (built into Flask) |
| CSS | Bootstrap 5.3.3 (loaded from CDN) |
| Tests | pytest |

---

## Repository Structure

```
Legoland/
├── app.py           # Entire application: config, models, forms, routes
├── tests.py         # Full pytest test suite
├── requirements.txt # Python dependencies (pip)
├── templates/       # Jinja2 HTML templates
│   ├── base.html        # Base layout with Bootstrap navbar and flash messages
│   ├── index.html       # Public landing page
│   ├── register.html    # Registration form
│   ├── login.html       # Login form
│   ├── dashboard.html   # Authenticated user's item list
│   └── item_form.html   # Shared add/edit form for LEGO items
├── README.md        # Minimal project stub
└── CLAUDE.md        # This file
```

All application logic lives in `app.py`. There are no sub-packages, blueprints, or separate module files.

---

## app.py Layout

The file is organized into clearly commented sections:

1. **Imports** (lines 1–16): standard library, Flask extensions, WTForms fields and validators.
2. **App / extensions setup** (~lines 18–34): Flask app creation, config, SQLAlchemy, CSRFProtect, LoginManager.
3. **Models** (~lines 37–72): `User` and `Item` SQLAlchemy models plus the `user_loader` callback.
4. **Forms** (~lines 75–111): `RegistrationForm`, `LoginForm`, `ItemForm` — all `FlaskForm` subclasses.
5. **Routes** (~lines 114–224): route handlers for every endpoint.
6. **Entry point** (~lines 227–234): `db.create_all()` + `app.run()`.

---

## Database Models

### `User` (`users` table)
| Column | Type | Notes |
|---|---|---|
| `id` | Integer PK | |
| `username` | String(80) | unique, not null |
| `password_hash` | LargeBinary(60) | bcrypt hash, never plaintext |

- Passwords are set via `user.set_password(plain)` and verified via `user.check_password(plain)`.
- Owns a `items` relationship with `cascade="all, delete-orphan"` — deleting a user cascades to their items.

### `Item` (`items` table)
| Column | Type | Notes |
|---|---|---|
| `id` | Integer PK | |
| `name` | String(200) | required |
| `set_number` | String(50) | optional |
| `theme` | String(100) | optional |
| `year` | Integer | optional, 1949–2100 |
| `pieces` | Integer | optional, 1–100000 |
| `description` | Text | optional, max 1000 chars |
| `user_id` | Integer FK → users.id | not null |

---

## Routes

| Method | URL | Auth required | Description |
|---|---|---|---|
| GET | `/` | No | Landing page; redirects to dashboard if logged in |
| GET/POST | `/register` | No | Create account |
| GET/POST | `/login` | No | Authenticate |
| GET | `/logout` | Yes | End session |
| GET | `/dashboard` | Yes | List current user's items |
| GET/POST | `/items/add` | Yes | Create a new item |
| GET/POST | `/items/<id>/edit` | Yes | Edit an existing item (owner only) |
| POST | `/items/<id>/delete` | Yes | Delete an item (owner only) |

Authorization on edit/delete: if `item.user_id != current_user.id` the route calls `abort(403)`.

---

## Configuration

All configuration is set in `app.py`. Two values are read from environment variables with fallbacks:

| Config key | Env var | Default |
|---|---|---|
| `SECRET_KEY` | `SECRET_KEY` | Random bytes (`os.urandom(32)`) — sessions are invalidated on restart unless this is set |
| `SQLALCHEMY_DATABASE_URI` | `DATABASE_URL` | `sqlite:///legoland.db` |

For production, always set `SECRET_KEY` to a stable value.

---

## UI Language

All user-facing text in templates and flash messages is in **German**. When adding or modifying templates and flash strings, continue using German. Example flash messages:

- `"Registrierung erfolgreich! Bitte melde dich an."` — success
- `"Benutzername bereits vergeben."` — duplicate username
- `"Ungültige Anmeldedaten."` — wrong credentials
- `"Eintrag erfolgreich hinzugefügt."` — item added

---

## Development Setup

```bash
# 1. Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Run the development server (creates legoland.db automatically)
python app.py
```

The app runs at `http://127.0.0.1:5000` by default. The database file `legoland.db` is created in the working directory on first run and is excluded by `.gitignore`.

---

## Running Tests

```bash
pytest tests.py
```

- Tests use an **in-memory SQLite database** (`sqlite:///:memory:`), so they never touch the real `legoland.db`.
- **CSRF is disabled** in tests via `app.config["WTF_CSRF_ENABLED"] = False`.
- Each test gets a fresh database through the `client` pytest fixture, which calls `db.create_all()` before and `db.drop_all()` after.

### Test helpers

```python
_register(client, username="testuser", password="securepass")
_login(client, username="testuser", password="securepass")
```

Use these helpers to set up authenticated state inside tests rather than duplicating POST calls.

### Test coverage areas

| Area | Tests |
|---|---|
| Auth | `test_register_and_login`, `test_register_duplicate_username`, `test_login_wrong_password`, `test_dashboard_requires_login` |
| CRUD | `test_add_item`, `test_edit_item`, `test_delete_item` |
| Authorization | `test_cannot_edit_other_users_item`, `test_cannot_delete_other_users_item` |
| Security | `test_password_hashed_in_db` |

When adding new functionality, add corresponding tests to `tests.py` following the same fixture pattern.

---

## Security Conventions

- **Never store plaintext passwords.** Always use `user.set_password()` and `user.check_password()`.
- **CSRF protection is global** via `CSRFProtect(app)`. All POST forms must include `{{ form.hidden_tag() }}`.
- **Owner checks are mandatory** on all item mutation routes. Use `abort(403)` if `item.user_id != current_user.id`.
- **Login enforcement** uses `@login_required` on every authenticated route. Do not skip this decorator.
- Do not expose `password_hash` in any API response or template variable.

---

## Adding New Features — Patterns to Follow

### Adding a new model
1. Define the SQLAlchemy model class in `app.py` under the `# Models` section.
2. Add a foreign key to `users.id` if the data is user-owned.
3. No migration tool is in use — the app calls `db.create_all()` at startup, which only adds new tables. For schema changes on an existing database, drop and recreate the database in development.

### Adding a new route
1. Define the route function in `app.py` under the `# Routes` section.
2. Decorate with `@login_required` if authentication is needed.
3. If the resource is user-owned, include an ownership check with `abort(403)`.
4. Create or reuse a template in `templates/`. Extend `base.html`.
5. Add a corresponding test in `tests.py`.

### Adding a new form
1. Define the `FlaskForm` subclass under the `# Forms` section.
2. Use WTForms validators from `wtforms.validators`.
3. Include `{{ form.hidden_tag() }}` in the template to render the CSRF token.

---

## What Does Not Exist (Avoid Assuming)

- No database migrations (no Alembic, Flask-Migrate, etc.)
- No API endpoints — the app is server-rendered HTML only
- No JavaScript beyond what Bootstrap provides
- No logging configuration
- No Docker or container setup
- No CI/CD pipeline
- No production WSGI configuration (no `wsgi.py`, no Gunicorn/uWSGI setup)
- No environment file (`.env`) — set env vars manually or via your shell
