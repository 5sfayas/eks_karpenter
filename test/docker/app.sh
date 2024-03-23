#!/bin/bash

# Start Gunicorn with the Flask app
gunicorn --workers=4 -b 0.0.0.0:5000 wsgi:app &

# Start Nginx in the foreground
nginx -g 'daemon off;'