# Stage 1: Builder
FROM python:3.9-slim-buster as builder

WORKDIR /app

COPY requirements.txt .
# Install python dependencies to user's local directory
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Final image
FROM python:3.9-slim-buster

# Create a non-privileged user
RUN useradd --create-home appuser
WORKDIR /home/appuser

# Copy installed packages and application code
COPY --from=builder /root/.local /home/appuser/.local
COPY app.py .

# Ensure the new user owns the files
RUN chown -R appuser:appuser /home/appuser

# Switch to the non-privileged user
USER appuser

# Adjust the PATH to include the user's local bin
ENV PATH="/home/appuser/.local/bin:${PATH}"

CMD ["python", "app.py"]