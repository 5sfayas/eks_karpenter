# Use the latest Ubuntu base image
FROM ubuntu:latest

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    python3 \
    python3-pip

# Set the working directory
WORKDIR /app

# Copy the application files
COPY app.py wsgi.py /app/
COPY requirements.txt /app/

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/sites-available/default


EXPOSE 80

COPY --chmod=+x app.sh /app/
# Start Gunicorn with the Flask app
# CMD ["gunicorn", "--workers=4", "-b" ,"0.0.0.0:5000", "wsgi:app"] &

# Start Nginx in the foreground
# CMD ["nginx", "-g", "daemon off;"]
ENTRYPOINT [ "sh", "/app/app.sh" ]
