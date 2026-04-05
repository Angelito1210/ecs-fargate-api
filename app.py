from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    # Lee la versión de las variables de entorno (por defecto 1.0)
    version = os.environ.get('APP_VERSION', '1.0')
    return f"<h1>Hola, soy la API de Ángel</h1><p>Desplegada con Docker y Terraform. Version: {version}</p>"

@app.route('/health')
def health():
    # Un endpoint de salud. AWS lo usará para saber si el contenedor está vivo
    return "OK", 200

if __name__ == '__main__':
    # El host 0.0.0.0 es OBLIGATORIO en Docker para que acepte conexiones desde fuera del contenedor
    app.run(host='0.0.0.0', port=8080)
