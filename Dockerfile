FROM docker.m.daocloud.io/library/alpine:3.19

# Install dependencies
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk add --no-cache g++ python3 py3-pip

# Set working directory
WORKDIR /app

# Copy source files
COPY main.cpp main.py ./

# Compile C++ program
RUN g++ -std=c++11 -O2 -o cpp_app main.cpp

# Create virtual environment and install Python dependencies
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"
RUN pip install --no-cache-dir fastapi uvicorn pydantic

# Expose port
EXPOSE 4002

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "4002"]
