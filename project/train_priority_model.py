import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import joblib

data = {
    "Complaint": [
        "Garbage not collected from street",
        "Water supply is not working",
        "Street lights are not working",
        "Potholes on road need repair",
        "Illegal construction in area",
        "Mosquito breeding in garbage dump",
        "Broken drainage pipe",
        "Tree fallen on road",
        "Sewage water overflow near house",
        "Noise pollution from factory",
        "Electric wire hanging dangerously",
        "Tap water dirty and smelly",
        "Street flooding during rain",
        "Public toilet not cleaned",
        "Dustbin missing in locality",
        "Animal menace stray dogs biting people",
        "Roadside garbage burning",
        "Traffic signal not working",
        "Illegal parking blocking road",
        "Open manhole on street",
        "Park bench is broken",
        "Graffiti on public wall",
        "Street sign is missing",
        "Public garden needs watering",
        "Community center needs painting",
        "Footpath tiles are loose",
        "Bus stop shelter is damaged",
        "Playground equipment is rusty",
        "Street name plate is faded",
        "Public notice board is empty"
    ],
    "Department": [
        "Sanitation", "Water", "Electricity", "Roads", "Municipal", "Sanitation",
        "Drainage", "Municipal", "Drainage", "Pollution", "Electricity", "Water",
        "Drainage", "Sanitation", "Sanitation", "Animal Control", "Pollution",
        "Traffic", "Traffic", "Municipal",
        "Parks", "Municipal", "Municipal", "Parks", "Municipal",
        "Roads", "Traffic", "Parks", "Municipal", "Municipal"
    ],
    "Priority": [
        "High", "High", "Medium", "Medium", "High", "High",
        "High", "Medium", "High", "Medium", "High", "High",
        "Medium", "Low", "Medium", "High", "High", "Medium", "Medium", "High",
        "Low", "Low", "Low", "Low", "Low",
        "Medium", "Medium", "Medium", "Medium", "Medium"
    ]
}

df = pd.DataFrame(data)

# Split data for validation
X_train, X_test, y_train, y_test = train_test_split(df['Complaint'], df['Priority'], test_size=0.2, random_state=42, stratify=df['Priority'])

model = Pipeline([
    ('tfidf', TfidfVectorizer()),
    ('clf', RandomForestClassifier(n_estimators=200, random_state=42))
])

model.fit(X_train, y_train)

# Validate on test set
y_pred = model.predict(X_test)
print("Classification Report on Test Set:")
print(classification_report(y_test, y_pred))

joblib.dump(model, "priority_model.pkl")

print(" New priority_model.pkl created successfully! (Compatible with sklearn 1.4.2)")
