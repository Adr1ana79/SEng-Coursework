from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from app.auth import SECRET_KEY, ALGORITHM
from app.database import get_db
from app import models

security = HTTPBearer()


def get_current_user(
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token"
    )

    token = credentials.credentials

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        role = payload.get("role")

        if user_id is None or role is None:
            raise credentials_exception

    except JWTError:
        raise credentials_exception

    if role == "doctor":
        user = db.query(models.Doctor).filter(models.Doctor.id == int(user_id)).first()
    elif role == "patient":
        user = db.query(models.Patient).filter(models.Patient.id == int(user_id)).first()
    else:
        raise credentials_exception

    if user is None:
        raise credentials_exception

    return {"user": user, "role": role}


def require_doctor(current=Depends(get_current_user)):
    if current["role"] != "doctor":
        raise HTTPException(status_code=403, detail="Doctor access required")
    return current["user"]


def require_patient(current=Depends(get_current_user)):
    if current["role"] != "patient":
        raise HTTPException(status_code=403, detail="Patient access required")
    return current["user"]