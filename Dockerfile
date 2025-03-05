# Use Debian-based Python image to avoid Alpine compilation issues
FROM python:3.12-slim

# Set up the application
WORKDIR /application
COPY . /application

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Expose the Flask application port
EXPOSE 8000

# Set the default command to run the application
CMD ["python", "app.py"]