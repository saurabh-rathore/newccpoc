#!/bin/bash

# A simple script to manage the Docker Compose environment

# Check if .env file exists, if not, copy it from .env.example
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
fi

# Function to show usage
usage() {
    echo "Usage: $0 {start|stop|restart|logs|build}"
    exit 1
}

# Main command logic
case "$1" in
    start)
        echo "Starting all services..."
        docker-compose up -d
        ;;
    stop)
        echo "Stopping all services..."
        docker-compose down
        ;;
    restart)
        echo "Restarting all services..."
        docker-compose down
        docker-compose up -d
        ;;
    logs)
        echo "Tailing logs for all services... (Ctrl+C to exit)"
        docker-compose logs -f
        ;;
    build)
        echo "Building all service images..."
        docker-compose build
        ;;
    *)
        usage
        ;;
esac

exit 0
