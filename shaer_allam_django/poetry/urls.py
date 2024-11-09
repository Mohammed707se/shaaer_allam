from django.urls import path
from .views import generate_poetry, generate_poetry_audio

urlpatterns = [
    path('generate_poetry/', generate_poetry, name='generate_poetry'),
    path('generate_poetry_audio/', generate_poetry_audio, name='generate_poetry_audio'),
]
