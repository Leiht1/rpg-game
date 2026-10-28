FROM python:3.11-slim-bookworm
RUN sed -i "s|http://deb.debian.org/debian-security|https://mirrors.aliyun.com/debian-security|g; s|http://deb.debian.org/debian|https://mirrors.aliyun.com/debian|g" /etc/apt/sources.list.d/debian.sources
RUN apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=20 update && apt-get install -y --no-install-recommends libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libgl1 libfontconfig1 ca-certificates && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir -i https://mirrors.aliyun.com/pypi/simple cryptography==50.0.2 Pillow==12.3.0
WORKDIR /srv/app
ENV HOME=/srv/home PYTHONUNBUFFERED=1
CMD ["python", "tools/network/server.py", "--config", "/srv/Config/network-server.json"]
