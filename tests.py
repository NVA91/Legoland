"""Basic tests for the Legoland DB web application."""
import pytest
from app import app, db, User, Item


@pytest.fixture()
def client():
    app.config["TESTING"] = True
    app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///:memory:"
    app.config["WTF_CSRF_ENABLED"] = False
    with app.app_context():
        db.create_all()
        yield app.test_client()
        db.drop_all()


def _register(client, username="testuser", password="securepass"):
    return client.post(
        "/register",
        data={"username": username, "password": password},
        follow_redirects=True,
    )


def _login(client, username="testuser", password="securepass"):
    return client.post(
        "/login",
        data={"username": username, "password": password},
        follow_redirects=True,
    )


# ---------------------------------------------------------------------------
# Authentication tests
# ---------------------------------------------------------------------------


def test_index_page(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert "Legoland DB" in resp.get_data(as_text=True)


def test_register_and_login(client):
    resp = _register(client)
    assert resp.status_code == 200
    assert "Registrierung erfolgreich" in resp.get_data(as_text=True)

    resp = _login(client)
    assert resp.status_code == 200
    assert "Meine Lego" in resp.get_data(as_text=True)


def test_register_duplicate_username(client):
    _register(client)
    resp = _register(client)
    assert "Benutzername bereits vergeben" in resp.get_data(as_text=True)


def test_login_wrong_password(client):
    _register(client)
    resp = _login(client, password="wrongpass")
    assert "Ungültige Anmeldedaten" in resp.get_data(as_text=True)


def test_dashboard_requires_login(client):
    resp = client.get("/dashboard", follow_redirects=True)
    assert "Bitte melde dich an" in resp.get_data(as_text=True)


# ---------------------------------------------------------------------------
# CRUD tests
# ---------------------------------------------------------------------------


def test_add_item(client):
    _register(client)
    _login(client)
    resp = client.post(
        "/items/add",
        data={"name": "Millennium Falcon", "set_number": "75192",
              "theme": "Star Wars", "year": 2017, "pieces": 7541},
        follow_redirects=True,
    )
    assert resp.status_code == 200
    assert "Millennium Falcon" in resp.get_data(as_text=True)


def test_edit_item(client):
    _register(client)
    _login(client)
    client.post(
        "/items/add",
        data={"name": "Old Name"},
        follow_redirects=True,
    )
    with app.app_context():
        item = Item.query.first()
        item_id = item.id

    resp = client.post(
        f"/items/{item_id}/edit",
        data={"name": "New Name"},
        follow_redirects=True,
    )
    assert "New Name" in resp.get_data(as_text=True)


def test_delete_item(client):
    _register(client)
    _login(client)
    client.post(
        "/items/add",
        data={"name": "To Delete"},
        follow_redirects=True,
    )
    with app.app_context():
        item = Item.query.first()
        item_id = item.id

    resp = client.post(f"/items/{item_id}/delete", follow_redirects=True)
    assert resp.status_code == 200
    assert "To Delete" not in resp.get_data(as_text=True)


def test_cannot_edit_other_users_item(client):
    _register(client, username="user1", password="password1")
    _register(client, username="user2", password="password2")

    _login(client, username="user1", password="password1")
    client.post("/items/add", data={"name": "User1 Item"}, follow_redirects=True)

    with app.app_context():
        item = Item.query.first()
        item_id = item.id

    # Log in as user2 and try to edit user1's item
    client.get("/logout", follow_redirects=True)
    _login(client, username="user2", password="password2")
    resp = client.post(f"/items/{item_id}/edit", data={"name": "Hacked"})
    assert resp.status_code == 403


def test_cannot_delete_other_users_item(client):
    _register(client, username="user1", password="password1")
    _register(client, username="user2", password="password2")

    _login(client, username="user1", password="password1")
    client.post("/items/add", data={"name": "User1 Item"}, follow_redirects=True)

    with app.app_context():
        item = Item.query.first()
        item_id = item.id

    client.get("/logout", follow_redirects=True)
    _login(client, username="user2", password="password2")
    resp = client.post(f"/items/{item_id}/delete")
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# Password security tests
# ---------------------------------------------------------------------------


def test_password_hashed_in_db(client):
    _register(client)
    with app.app_context():
        user = User.query.filter_by(username="testuser").first()
        assert user is not None
        assert user.password_hash != b"securepass"
        assert user.check_password("securepass")
        assert not user.check_password("wrongpass")
