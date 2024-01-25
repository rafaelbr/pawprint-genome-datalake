FROM python:3.9

COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=UTF-8

ADD files.tar.gz /app/
EXPOSE 80
ENTRYPOINT ["streamlit", "run" ,"/app/files/Home.py", "--server.port", "80"]