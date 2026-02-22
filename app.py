import os
import bcrypt
from flask import Flask, render_template, redirect, url_for, flash, request, abort
from flask_sqlalchemy import SQLAlchemy
from flask_login import (
    LoginManager,
    UserMixin,
    login_user,
    logout_user,
    login_required,
    current_user,
)
from flask_wtf import FlaskForm
from flask_wtf.csrf import CSRFProtect
from wtforms import StringField, PasswordField, IntegerField, TextAreaField, SubmitField
from wtforms.validators import DataRequired, Length, NumberRange, Optional

# ---------------------------------------------------------------------------
# App / extensions setup
# ---------------------------------------------------------------------------

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", os.urandom(32))
app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get(
    "DATABASE_URL", "sqlite:///legoland.db"
)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)
csrf = CSRFProtect(app)
login_manager = LoginManager(app)
login_manager.login_view = "login"
login_manager.login_message = "Bitte melde dich an, um fortzufahren."
login_manager.login_message_category = "warning"


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------


class User(UserMixin, db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.LargeBinary(60), nullable=False)
    items = db.relationship("Item", backref="owner", lazy=True, cascade="all, delete-orphan")

    def set_password(self, password: str) -> None:
        self.password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt())

    def check_password(self, password: str) -> bool:
        return bcrypt.checkpw(password.encode(), self.password_hash)


class Item(db.Model):
    __tablename__ = "items"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), nullable=False)
    set_number = db.Column(db.String(50), nullable=True)
    theme = db.Column(db.String(100), nullable=True)
    year = db.Column(db.Integer, nullable=True)
    pieces = db.Column(db.Integer, nullable=True)
    description = db.Column(db.Text, nullable=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)


@login_manager.user_loader
def load_user(user_id: str):
    return db.session.get(User, int(user_id))


# ---------------------------------------------------------------------------
# Forms
# ---------------------------------------------------------------------------


class RegistrationForm(FlaskForm):
    username = StringField(
        "Benutzername",
        validators=[DataRequired(), Length(min=3, max=80)],
    )
    password = PasswordField(
        "Passwort",
        validators=[DataRequired(), Length(min=8)],
    )
    submit = SubmitField("Registrieren")


class LoginForm(FlaskForm):
    username = StringField("Benutzername", validators=[DataRequired()])
    password = PasswordField("Passwort", validators=[DataRequired()])
    submit = SubmitField("Anmelden")


class ItemForm(FlaskForm):
    name = StringField("Name", validators=[DataRequired(), Length(max=200)])
    set_number = StringField("Set-Nummer", validators=[Optional(), Length(max=50)])
    theme = StringField("Thema", validators=[Optional(), Length(max=100)])
    year = IntegerField(
        "Jahr",
        validators=[Optional(), NumberRange(min=1949, max=2100)],
    )
    pieces = IntegerField(
        "Teile",
        validators=[Optional(), NumberRange(min=1, max=100000)],
    )
    description = TextAreaField("Beschreibung", validators=[Optional(), Length(max=1000)])
    submit = SubmitField("Speichern")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@app.route("/")
def index():
    if current_user.is_authenticated:
        return redirect(url_for("dashboard"))
    return render_template("index.html")


@app.route("/register", methods=["GET", "POST"])
def register():
    if current_user.is_authenticated:
        return redirect(url_for("dashboard"))
    form = RegistrationForm()
    if form.validate_on_submit():
        if User.query.filter_by(username=form.username.data).first():
            flash("Benutzername bereits vergeben.", "danger")
            return render_template("register.html", form=form)
        user = User(username=form.username.data)
        user.set_password(form.password.data)
        db.session.add(user)
        db.session.commit()
        flash("Registrierung erfolgreich! Bitte melde dich an.", "success")
        return redirect(url_for("login"))
    return render_template("register.html", form=form)


@app.route("/login", methods=["GET", "POST"])
def login():
    if current_user.is_authenticated:
        return redirect(url_for("dashboard"))
    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(username=form.username.data).first()
        if user and user.check_password(form.password.data):
            login_user(user)
            next_page = request.args.get("next")
            return redirect(next_page or url_for("dashboard"))
        flash("Ungültige Anmeldedaten.", "danger")
    return render_template("login.html", form=form)


@app.route("/logout")
@login_required
def logout():
    logout_user()
    flash("Erfolgreich abgemeldet.", "info")
    return redirect(url_for("index"))


@app.route("/dashboard")
@login_required
def dashboard():
    items = Item.query.filter_by(user_id=current_user.id).order_by(Item.name).all()
    return render_template("dashboard.html", items=items)


@app.route("/items/add", methods=["GET", "POST"])
@login_required
def add_item():
    form = ItemForm()
    if form.validate_on_submit():
        item = Item(
            name=form.name.data,
            set_number=form.set_number.data or None,
            theme=form.theme.data or None,
            year=form.year.data,
            pieces=form.pieces.data,
            description=form.description.data or None,
            user_id=current_user.id,
        )
        db.session.add(item)
        db.session.commit()
        flash("Eintrag erfolgreich hinzugefügt.", "success")
        return redirect(url_for("dashboard"))
    return render_template("item_form.html", form=form, title="Eintrag hinzufügen")


@app.route("/items/<int:item_id>/edit", methods=["GET", "POST"])
@login_required
def edit_item(item_id: int):
    item = db.get_or_404(Item, item_id)
    if item.user_id != current_user.id:
        abort(403)
    form = ItemForm(obj=item)
    if form.validate_on_submit():
        item.name = form.name.data
        item.set_number = form.set_number.data or None
        item.theme = form.theme.data or None
        item.year = form.year.data
        item.pieces = form.pieces.data
        item.description = form.description.data or None
        db.session.commit()
        flash("Eintrag erfolgreich aktualisiert.", "success")
        return redirect(url_for("dashboard"))
    return render_template("item_form.html", form=form, title="Eintrag bearbeiten", item=item)


@app.route("/items/<int:item_id>/delete", methods=["POST"])
@login_required
def delete_item(item_id: int):
    item = db.get_or_404(Item, item_id)
    if item.user_id != current_user.id:
        abort(403)
    db.session.delete(item)
    db.session.commit()
    flash("Eintrag erfolgreich gelöscht.", "info")
    return redirect(url_for("dashboard"))


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(debug=False)
