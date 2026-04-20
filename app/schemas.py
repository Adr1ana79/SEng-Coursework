from datetime import datetime, time, date
from pydantic import BaseModel, EmailStr, Field
from typing import Literal


class DoctorRegister(BaseModel):
    name: str
    email: EmailStr
    address: str
    password: str = Field(min_length=6, max_length=128)


class PatientRegister(BaseModel):
    name: str
    email: EmailStr
    phone: str
    password: str = Field(min_length=6, max_length=128)
    doctor_id: int


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    role: Literal["doctor", "patient"]


class TokenResponse(BaseModel):
    access_token: str
    token_type: str


class WorkingHoursCreate(BaseModel):
    day_of_week: int
    start_time: time | None = None
    end_time: time | None = None
    break_start: time | None = None
    break_end: time | None = None


class WeeklyWorkingHoursUpdate(BaseModel):
    days: list[WorkingHoursCreate]


class TemporaryChangeCreate(BaseModel):
    start_datetime: datetime
    end_datetime: datetime
    new_start_time: time | None = None
    new_end_time: time | None = None
    break_start: time | None = None
    break_end: time | None = None


class PermanentChangeCreate(BaseModel):
    valid_from: date
    day_of_week: int
    start_time: time | None = None
    end_time: time | None = None
    break_start: time | None = None
    break_end: time | None = None


class AppointmentCreate(BaseModel):
    patient_id: int
    start_time: datetime
    end_time: datetime