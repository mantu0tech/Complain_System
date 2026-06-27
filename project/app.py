import os
import joblib
import boto3
from flask import Flask, render_template, request, redirect, url_for, flash, session
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_login import LoginManager, login_user, login_required, logout_user, current_user, UserMixin
from werkzeug.utils import secure_filename
from sqlalchemy import case
from dotenv import load_dotenv
load_dotenv()

# --- Configuration ---

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'static', 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app = Flask(__name__)

app.secret_key = os.getenv("SECRET_KEY")


AWS_REGION = os.getenv("AWS_REGION")

s3 = boto3.client("s3", region_name=AWS_REGION)
sns = boto3.client("sns", region_name=AWS_REGION)

BUCKET_NAME = os.getenv("BUCKET_NAME")

SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN")

app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv("DATABASE_URL")
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
required_vars = [
    "SECRET_KEY",
    "DATABASE_URL",
    "BUCKET_NAME",
    "SNS_TOPIC_ARN"
]

for var in required_vars:
    if not os.getenv(var):
        raise ValueError(f"Missing environment variable: {var}")
# --- Initialize extensions ---
db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
login_manager = LoginManager(app)
login_manager.login_view = 'login'

# --- Load Trained AI Model ---
try:
    model = joblib.load("priority_model.pkl")
    print("AI Model loaded successfully!")
except Exception as e:
    print(f"⚠️ Model not loaded: {e}")
    model = None


class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    first_name = db.Column(db.String(80), nullable=False)
    last_name = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    phone = db.Column(db.String(20))
    address = db.Column(db.String(250))
    password_hash = db.Column(db.String(255), nullable=False)
    profile_pic = db.Column(db.String(255), nullable=True)

    def set_password(self, password):
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')

class Staff(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)

    def set_password(self, password):
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')

DEPARTMENTS = {
    'Water Supply': {'username': 'water', 'password': 'staff123'},
    'Electricity': {'username': 'electricity', 'password': 'staff123'},
    'Sanitation': {'username': 'sanitation', 'password': 'staff123'},
    'Roads': {'username': 'roads', 'password': 'staff123'},
    'Other': {'username': 'other', 'password': 'staff123'},
}
class Complaint(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    title = db.Column(db.String(200), nullable=False)
    category = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=False)
    location = db.Column(db.String(200), nullable=False)
    status = db.Column(db.String(50), default='Pending')
    priority = db.Column(db.String(50), default='Medium')
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())
    image = db.Column(db.String(255), nullable=True)
    assigned_staff_id = db.Column(db.Integer, db.ForeignKey('staff.id'), nullable=True)
    assigned_dept = db.Column(db.String(100), nullable=True)
    notes = db.Column(db.Text, nullable=True)
    proof_image = db.Column(db.String(255), nullable=True)

    user = db.relationship('User', backref=db.backref('complaints', lazy=True))
    assigned_staff = db.relationship('Staff', backref=db.backref('assigned_complaints', lazy=True))

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route("/")
def home():
    return render_template("index.html")

@app.route("/register", methods=["GET", "POST"])
def register():
    registration_success = False
    if request.method == "POST":
        first_name = request.form["first_name"]
        last_name = request.form["last_name"]
        email = request.form["email"]
        phone = request.form["phone"]
        address = request.form["address"]
        password = request.form["password"]
        confirm_password = request.form["confirm_password"]

        if password != confirm_password:
            flash("Passwords do not match!", "danger")
            return redirect(url_for("register"))

        if User.query.filter_by(email=email).first():
            flash("Email already registered!", "warning")
            return redirect(url_for("register"))

        profile_pic_file = request.files.get("profile_pic")
        filename = None
        if profile_pic_file and profile_pic_file.filename != "":
            filename = secure_filename(profile_pic_file.filename)
            profile_pic_file.save(os.path.join(app.config["UPLOAD_FOLDER"], filename))

        user = User(
            first_name=first_name,
            last_name=last_name,
            email=email,
            phone=phone,
            address=address,
            profile_pic=filename
        )
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
        registration_success = True

    return render_template("rege.html", registration_success=registration_success)

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email = request.form["username"]
        password = request.form["password"]
        user = User.query.filter_by(email=email).first()
        if user and bcrypt.check_password_hash(user.password_hash, password):
            login_user(user)
            flash("Login successful!", "success")
            return redirect(url_for("citizen_dash"))
        else:
            flash("Invalid email or password!", "danger")
            return redirect(url_for("login"))
    return render_template("login.html")

@app.route("/logout")
@login_required
def logout():
    logout_user()
    flash("You have been logged out successfully!", "success")
    return redirect(url_for("login"))

@app.route("/citizen_dash")
@login_required
def citizen_dash():
    complaints = Complaint.query.filter_by(user_id=current_user.id).all()
    total_complaints = len(complaints)
    pending = len([c for c in complaints if c.status == 'Pending'])
    resolved = len([c for c in complaints if c.status == 'Resolved'])
    high_priority = len([c for c in complaints if c.priority == 'High'])

    return render_template("citizen_dash.html",
                           user=current_user,
                           username=current_user.first_name,
                           complaints=complaints,
                           total_complaints=total_complaints,
                           pending=pending,
                           resolved=resolved,
                           high_priority=high_priority)
@app.route("/submit_complaint", methods=["GET", "POST"])
@login_required
def submit_complaint():
    if request.method == "POST":
        title = request.form.get("title")
        category = request.form.get("category")
        description = request.form.get("description")
        location = request.form.get("location")

        if not title or not category or not description or not location:
            flash("All fields are required!", "danger")
            return redirect(url_for("submit_complaint"))

        image_file = request.files.get("image")
        filename = None
        image_url = None

        if image_file and image_file.filename != "":
            filename = secure_filename(image_file.filename)

            s3.upload_fileobj(
                image_file,
                BUCKET_NAME,
                filename
            )

            image_url = f"https://{BUCKET_NAME}.s3.amazonaws.com/{filename}"

        predicted_priority = "Medium"

        try:
            if model:
                predicted_priority = model.predict([description])[0]
        except Exception as e:
            print("Prediction Error:", e)

        complaint = Complaint(
            user_id=current_user.id,
            title=title,
            category=category,
            description=description,
            location=location,
            priority=predicted_priority,
            image=image_url
        )

        db.session.add(complaint)
        db.session.commit()

        try:
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject="Complaint Registered was a success",
                Message=f"""
Complaint Registered Successfully

Complaint ID: {complaint.id}
Title: {complaint.title}
Category: {complaint.category}
Priority: {complaint.priority}
Location: {complaint.location}

Status: Pending
"""
            )

            print("SNS notification was a success")

        except Exception as e:
            print("SNS Error:", e)

        flash("Complaint submitted successfully!", "success")
        return redirect(url_for("my_complaints"))

    return render_template("complaint_form.html")
@app.route("/my_complaints")
@login_required
def my_complaints():
    complaints = Complaint.query.filter_by(user_id=current_user.id).order_by(Complaint.created_at.desc()).all()
    return render_template("my_complaints.html", complaints=complaints)


@app.route("/admin_login", methods=["GET", "POST"])
def admin_login():
    if request.method == "POST":
        username = request.form.get("username")
        password = request.form.get("password")
        if username == "admin" and password == "admin":
            session['admin_logged_in'] = True
            flash("Admin login successful!", "success")
            return redirect(url_for("admin"))
        else:
            flash("Invalid admin credentials!", "danger")
    return render_template("admin_login.html")

@app.route("/admin_logout")
def admin_logout():
    session.pop('admin_logged_in', None)
    flash("Admin logged out successfully!", "success")
    return redirect(url_for("home"))

@app.route("/admin")
def admin():
    if not session.get('admin_logged_in'):
        return redirect(url_for('admin_login'))

    users = User.query.all()
    complaints = Complaint.query.order_by(Complaint.created_at.desc()).all()
    high_priority_complaints = Complaint.query.filter_by(priority='High').filter(Complaint.status != 'Resolved').order_by(Complaint.created_at.desc()).limit(5).all()

    users_count = len(users)
    total_complaints = len(complaints)
    resolved = len([c for c in complaints if c.status == 'Resolved'])
    pending = len([c for c in complaints if c.status == 'Pending'])
    high_priority = len([c for c in complaints if c.priority == 'High'])
    in_progress = len([c for c in complaints if c.status == 'In Progress'])

    return render_template("admin.html",
                           users_count=users_count,
                           total_complaints=total_complaints,
                           resolved=resolved,
                           pending=pending,
                           high_priority=high_priority,
                           in_progress=in_progress,
                           high_priority_complaints=high_priority_complaints)

@app.route("/admin_users")
def admin_users():
    if not session.get('admin_logged_in'):
        return redirect(url_for('admin_login'))

    users = User.query.all()
    return render_template("admin_users.html", users=users)

@app.route("/admin_complaints")
def admin_complaints():
    if not session.get('admin_logged_in'):
        return redirect(url_for('admin_login'))

    sort_by = request.args.get('sort', 'date')
    # Status order: Unresolved first (1), Resolved last (2)
    status_order = case(
        (Complaint.status == 'Resolved', 2),
        else_=1
    )

    if sort_by == 'priority':
        # Sort by status (unresolved first), then priority: High first, then Medium, then Low
        priority_order = case(
            (Complaint.priority == 'High', 1),
            (Complaint.priority == 'Medium', 2),
            (Complaint.priority == 'Low', 3),
            else_=4
        )
        complaints = Complaint.query.order_by(status_order, priority_order, Complaint.created_at.desc()).all()
    else:
        # Sort by status (unresolved first), then date descending
        complaints = Complaint.query.order_by(status_order, Complaint.created_at.desc()).all()
    departments = list(DEPARTMENTS.keys())
    return render_template("admin_complaints.html", complaints=complaints, sort_by=sort_by, departments=departments)

@app.route("/assign_complaint/<int:id>", methods=["POST"])
def assign_complaint(id):
    if not session.get('admin_logged_in'):
        return redirect(url_for('admin_login'))

    complaint = Complaint.query.get_or_404(id)
    dept = request.form.get("dept")

    if dept:
        complaint.assigned_dept = dept
        db.session.commit()
        flash("Complaint assigned to department successfully!", "success")
    else:
        flash("Please select a department!", "danger")
    return redirect(url_for("admin_complaints"))

@app.route("/delete_complaint/<int:id>", methods=["POST"])
def delete_complaint(id):
    complaint = Complaint.query.get_or_404(id)
    db.session.delete(complaint)
    db.session.commit()
    flash("Complaint deleted successfully!", "success")
    return redirect(url_for("admin_complaints"))

@app.route("/staff_login", methods=["GET", "POST"])
def staff_login():
    if request.method == "POST":
        username = request.form.get("username")
        password = request.form.get("password")

        for dept, creds in DEPARTMENTS.items():
            if creds['username'] == username and creds['password'] == password:
                session['staff_logged_in'] = True
                session['staff_dept'] = dept
                session['staff_name'] = dept
                flash(f"{dept} login successful!", "success")
                return redirect(url_for("staff_dash"))
        flash("Invalid staff credentials!", "danger")
    return render_template("staff_login.html")

@app.route("/staff_logout")
def staff_logout():
    session.pop('staff_logged_in', None)
    session.pop('staff_id', None)
    session.pop('staff_name', None)
    flash("Staff logged out successfully!", "success")
    return redirect(url_for("home"))

@app.route("/staff_dash")
def staff_dash():
    if not session.get('staff_logged_in'):
        return redirect(url_for('staff_login'))
    staff_dept = session.get('staff_dept')
    complaints = Complaint.query.filter_by(assigned_dept=staff_dept).order_by(Complaint.created_at.desc()).all()

    total_assigned = len(complaints)
    in_progress = len([c for c in complaints if c.status == 'In Progress'])
    resolved = len([c for c in complaints if c.status == 'Resolved'])
    pending = len([c for c in complaints if c.status == 'Pending'])

    return render_template("staff_dash.html",
                           complaints=complaints,
                           staff_name=session.get('staff_name'),
                           total_assigned=total_assigned,
                           in_progress=in_progress,
                           resolved=resolved,
                           pending=pending)

@app.route("/staff_complaints")
def staff_complaints():
    if not session.get('staff_logged_in'):
        return redirect(url_for('staff_login'))

    staff_dept = session.get('staff_dept')
    complaints = Complaint.query.filter_by(assigned_dept=staff_dept).order_by(Complaint.created_at.desc()).all()
    return render_template("staff_complaints.html", complaints=complaints, staff_name=session.get('staff_name'))

@app.route("/staff_update/<int:id>", methods=["GET", "POST"])
def staff_update(id):
    if not session.get('staff_logged_in'):
        return redirect(url_for('staff_login'))

    complaint = Complaint.query.get_or_404(id)
    staff_dept = session.get('staff_dept')
    if complaint.assigned_dept != staff_dept:
        flash("You are not authorized to update this complaint!", "danger")
        return redirect(url_for("staff_complaints"))

    if request.method == "POST":
        status = request.form.get("status")
        notes = request.form.get("notes")

        if status:
            complaint.status = status

        if notes:
            complaint.notes = notes

        proof_file = request.files.get("proof_image")
        if proof_file and proof_file.filename != "":
            filename = secure_filename(proof_file.filename)
            proof_file.save(os.path.join(app.config["UPLOAD_FOLDER"], filename))
            complaint.proof_image = filename

        db.session.commit()
        flash("Complaint updated successfully!", "success")
        return redirect(url_for("staff_complaints"))

    return render_template("staff_update.html", complaint=complaint)

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(host="0.0.0.0", port=5000, debug=True)
