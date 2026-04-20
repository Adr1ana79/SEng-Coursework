from fastapi import FastAPI
from app.database import Base, engine
from app.routers import auth, doctors, appointments

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Medical Booking API")

app.include_router(auth.router)
app.include_router(doctors.router)
app.include_router(appointments.router)

@app.get("/")
def root():
    return {"message": "Medical booking API is running"}

