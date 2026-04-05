# 1. Usamos una imagen base oficial de Python (versión ligera)
FROM python:3.12-slim

# 2. Definimos la carpeta de trabajo dentro del contenedor
WORKDIR /app

# 3. Copiamos el archivo de dependencias y las instalamos
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copiamos el resto del código de la app
COPY . .

# 5. Le decimos a Docker por qué puerto va a escuchar la app
EXPOSE 8080

# 6. Definimos una variable de entorno por defecto
ENV APP_VERSION="1.0"

# 7. El comando que arranca la aplicación
CMD ["python", "app.py"]
