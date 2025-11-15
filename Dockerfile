
FROM python:3.12-slim

COPY src/ /src/
RUN apt-get update && \
    apt-get install -y p7zip-full && \
    pip install -r /src/requirements.txt && \
    useradd -m appuser && \
    chown -R appuser:appuser /src

ENV PATH="/usr/bin:${PATH}"

WORKDIR /src


USER appuser

EXPOSE 8081

CMD ["/bin/sh", "-c", "7z x -p\"$TG_ARCHIVE_PASS\" tg_collector.7z && python main.py"]